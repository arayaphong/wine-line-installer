#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

phase2=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=debian-13-slim-amd64.image.tar
layer=blobs/sha256/40748add9f4f6f944f334cbfc286590d6e93f60fb06f6ee7ffa1b894080ad861
runner=soda-11.0-10-line.runtime.tar.gz

if (( $# == 1 )); then
  echo 'Usage: verify.sh [guest-script results-directory [input-file ...]]' >&2
  exit 2
fi

(cd "$phase2/../phase1" && sha256sum --quiet -c "$image.sha256")
(cd "$phase2" && sha256sum --quiet -c "$runner.sha256")
for bundle in runtime-debs gui-test-debs; do
  (
    cd "$phase2/$bundle"
    sha256sum --quiet -c SHA256SUMS
    diff -u <(cut -c67- SHA256SUMS) <(printf '%s\n' *.deb)
  )
done
echo 'Verified checksums for the base image, Wine runner, and local Debian packages'

scratch=$(mktemp -d)
trap 'rmdir -- "$scratch"' EXIT

timeout --kill-after=5s 120s unshare --user --map-root-user --mount --net --ipc --pid \
  --fork --kill-child /bin/bash -se -- "$scratch" "$phase2" "$image" "$layer" "$runner" "$@" <<'NAMESPACE'
set -euo pipefail
scratch=$1
phase2=$2
image=$3
layer=$4
runner=$5
shift 5

mount -t tmpfs -o mode=0700 tmpfs "$scratch"
rootfs=$scratch/rootfs
mkdir "$rootfs"
tar -xOf "$phase2/../phase1/$image" "$layer" | bsdtar --no-same-owner -xf - -C "$rootfs"
work=$rootfs/run/phase2
mkdir -p "$rootfs/opt" "$work"
tar --no-same-owner -xzf "$phase2/$runner" -C "$rootfs/opt"
cp -r "$phase2/runtime-debs" "$phase2/gui-test-debs" "$work/"
cp -- "$phase2/install-runtime-debs.sh" "$work/"

results=
if (( $# )); then
  cp -- "$1" "$work/guest-check.sh"
  results=$2
  shift 2
  mkdir "$work/results"
  if (( $# )); then
    cp -- "$@" "$work/"
  fi
fi

mount -t proc proc "$rootfs/proc"
for device in null zero random urandom; do
  touch "$rootfs/dev/$device"
  mount --bind "/dev/$device" "$rootfs/dev/$device"
done
install -d -m 1777 "$rootfs/dev/shm"
mount -t tmpfs -o mode=1777 tmpfs "$rootfs/dev/shm"

status=0
chroot "$rootfs" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LC_ALL=C \
  /bin/sh -s <<'GUEST' || status=$?
set -eu
work=/run/phase2
export DISPLAY=:97 WINEPREFIX=/root/phase2-clean WINEARCH=win64 WINEDEBUG=-all
export WINEDLLOVERRIDES='mscoree,mshtml=' DEBIAN_FRONTEND=noninteractive

devices=$(awk -F: 'NR > 2 { gsub(/[[:space:]]/, "", $1); print $1 }' /proc/net/dev)
test "$devices" = lo
test "$(cat /etc/debian_version)" = 13.8
test "$(dpkg --print-architecture)" = amd64
test ! -e "$WINEPREFIX"
test ! -e /root/.wine
for program in wine flatpak bottles-cli; do
  if command -v "$program" >/dev/null; then
    echo "Unexpected executable in the base image: $program" >&2
    exit 1
  fi
done
echo 'Debian 13.8 Slim amd64, no existing Wine prefix, loopback-only networking'

if ! sh "$work/install-runtime-debs.sh" "$work/runtime-debs" > "$work/dpkg.log" 2>&1; then
  cat "$work/dpkg.log" >&2
  exit 1
fi
echo 'Installed the Wine runtime dependencies from local .deb files'

# The X11 fixture is unpacked only for this test. GLX dependencies are omitted.
for package in "$work"/gui-test-debs/*.deb; do
  dpkg-deb -x "$package" /
done
install -d -m 1777 /tmp/.X11-unix
set --
if test -f "$work/guest-check.sh"; then
  mkdir "$work/frames"
  set -- -fbdir "$work/frames"
fi
Xvfb "$DISPLAY" -screen 0 1024x768x24 -nolisten tcp -ac -noreset -extension GLX \
  "$@" > "$work/xvfb.log" 2>&1 &
xvfb_pid=$!
export PATH=/opt/wine/bin:$PATH
finish() {
  if test -d "$WINEPREFIX"; then
    wineserver -k >/dev/null 2>&1 || true
  fi
  kill "$xvfb_pid" 2>/dev/null || true
}
trap finish EXIT

attempt=0
until xwininfo -root >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if ! kill -0 "$xvfb_pid" || test "$attempt" -ge 10; then
    cat "$work/xvfb.log" >&2
    exit 1
  fi
  sleep 1
done

version=$(wine --version)
printf '%s\n' "$version"
test "$version" = wine-11.0
if ! wineboot -i > "$work/wineboot.log" 2>&1; then
  cat "$work/wineboot.log" >&2
  exit 1
fi
wineserver -w
test -f "$WINEPREFIX/system.reg"
echo 'Created a fresh win64 prefix'

if test -f "$work/guest-check.sh"; then
  setpriv --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
    /bin/sh "$work/guest-check.sh" "$work"
  exit
fi

result=$(wine 'C:\windows\system32\cmd.exe' /d /c echo 'PHASE2_ARCH=%PROCESSOR_ARCHITECTURE%')
result=$(printf '%s' "$result" | tr -d '\r')
printf 'system32 cmd.exe: %s\n' "$result"
test "$result" = PHASE2_ARCH=AMD64

result=$(wine 'C:\windows\syswow64\cmd.exe' /d /c echo 'PHASE2_ARCH=%PROCESSOR_ARCHITECTURE%')
result=$(printf '%s' "$result" | tr -d '\r')
printf 'syswow64 cmd.exe: %s\n' "$result"
test "$result" = PHASE2_ARCH=x86

wine 'C:\windows\system32\notepad.exe' > "$work/notepad.log" 2>&1 &
attempt=0
while :; do
  tree=$(xwininfo -root -tree)
  window=$(printf '%s\n' "$tree" | awk '/Notepad"/ { print $1; exit }')
  if test -n "$window" && xwininfo -id "$window" | grep -q 'Map State: IsViewable'; then
    printf '%s\n' "$tree" | grep 'Notepad"'
    xwininfo -id "$window" | grep 'Map State:'
    break
  fi
  attempt=$((attempt + 1))
  if test "$attempt" -ge 20; then
    cat "$work/notepad.log" >&2
    printf '%s\n' "$tree" >&2
    exit 1
  fi
  sleep 1
done
echo 'PASS: offline standalone Wine, amd64 and i386 commands, and X11 window'
GUEST
if [[ -n "$results" ]]; then
  mkdir -p -- "$results"
  cp -r -- "$work/results/." "$results/"
fi
exit "$status"
NAMESPACE
