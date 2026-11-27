#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

phase5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
offline=$(dirname -- "$phase5")
installer=LINE-offline-26.6.0.4004-linux-x86_64.run
image=line-offline-test:debian-13-slim-amd64
results=${1:-"$phase5"}

(cd "$phase5" && sha256sum --quiet -c "$installer.sha256")
(cd "$offline/phase2/gui-test-debs" && sha256sum --quiet -c SHA256SUMS)
(cd "$offline/phase4/emoji-test-debs" && sha256sum --quiet -c SHA256SUMS)
installer_sha256=$(cut -d ' ' -f 1 "$phase5/$installer.sha256")
# Docker's image ID is the manifest or the config digest, depending on the image store.
image_id=$(docker image inspect --format '{{.Id}}' "$image")
case "$image_id" in
  sha256:ab3b3c8c5159eebfca4376430132d53c4d425f869c765ecbe47177a030da575d|\
  sha256:cf7c9dcedc058a74762f2e1f01f6254e2376f3752452ddb347c1bb2a17618fd7) ;;
  *) printf 'The local tag points to an unexpected Debian image: %s\n' "$image_id" >&2; exit 1 ;;
esac

scratch=$(mktemp -d)
container=
cleanup() {
  if [[ -n "$container" ]]; then
    docker rm -f "$container" >/dev/null 2>&1 || true
  fi
  rm -r -- "$scratch"
}
trap cleanup EXIT
container=$(docker create --init --pull never --network none "$image_id" /bin/sleep infinity)
docker start "$container" >/dev/null
test "$(docker inspect --format '{{.HostConfig.NetworkMode}} {{len .Mounts}}' "$container")" = 'none 0'
docker cp "$phase5/$installer" "$container:/installer.run"
printf 'Pinned Debian image %s. Copied only the .run file into a container without host mounts.\n' "$image_id"

docker exec -e "INSTALLER_SHA256=$installer_sha256" -i "$container" /bin/sh -s <<'INSTALL'
set -eu
export LC_ALL=C
test "$(cat /etc/debian_version)" = 13.8
test "$(awk -F: 'NR > 2 {gsub(/[[:space:]]/, "", $1); print $1}' /proc/net/dev)" = lo
test -z "$(dpkg --print-foreign-architectures)"
test ! -e /opt/line-offline
test ! -e /usr/local/bin/line-offline
test ! -e /fixture-x11
test ! -e /fixture-input
test -z "${DISPLAY:-}"
printf '%s  /installer.run\n' "$INSTALLER_SHA256" | sha256sum -c -
echo 'Clean Debian 13.8 Slim container, loopback-only networking, no display during installation.'

header_lines=$(awk '$0 == "__LINE_OFFLINE_PAYLOAD__" {print NR; exit}' /installer.run)
head -n "$header_lines" /installer.run > /tmp/truncated.run
if sh /tmp/truncated.run > /tmp/truncated.log 2>&1; then
  echo 'The truncated installer unexpectedly succeeded.' >&2
  exit 1
fi
grep 'The embedded archive failed verification.' /tmp/truncated.log
test -z "$(dpkg --print-foreign-architectures)"
test ! -e /usr/local/bin/line-offline

/installer.run
test -z "$(dpkg --audit)"
release=$(dirname -- "$(readlink -f /usr/local/bin/line-offline)")
first_inode=$(stat -c %i "$release/bundle.sha256")
/installer.run
test "$(dirname -- "$(readlink -f /usr/local/bin/line-offline)")" = "$release"
test "$(stat -c %i "$release/bundle.sha256")" = "$first_inode"
echo 'The second installation reused the same release directory.'
INSTALL

# Copy the display and input tools only after the standalone installation passes.
docker cp "$offline/phase2/gui-test-debs" "$container:/fixture-x11"
docker cp "$offline/phase4/emoji-test-debs" "$container:/fixture-input"
docker exec -i "$container" /bin/sh -s <<'CONTAINER'
set -eu
export LC_ALL=C
test "$(awk -F: 'NR > 2 {gsub(/[[:space:]]/, "", $1); print $1}' /proc/net/dev)" = lo
release=$(dirname -- "$(readlink -f /usr/local/bin/line-offline)")
echo 'Added the display and input fixtures after installation.'

for package in /fixture-x11/*.deb /fixture-input/*.deb; do
  dpkg-deb -x "$package" /
done
mkdir /tmp/frames /results
install -d -m 1777 /tmp/.X11-unix
export DISPLAY=:97
Xvfb "$DISPLAY" -screen 0 1024x768x24 -nolisten tcp -ac -noreset -extension GLX \
  -fbdir /tmp/frames > /tmp/xvfb.log 2>&1 &
xvfb_pid=$!
trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT
attempt=0
until xwininfo -root >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if ! kill -0 "$xvfb_pid" || [ "$attempt" -ge 10 ]; then
    cat /tmp/xvfb.log >&2
    exit 1
  fi
  sleep 1
done

useradd -m line-test
prefix=/home/line-test/.local/share/line-offline/wine
test ! -e "$prefix"
as_user() {
  setpriv --reuid line-test --regid line-test --clear-groups \
    --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
    env HOME=/home/line-test "$@"
}

open_line() {
  as_user env WINEDEBUG=+loaddll,+msgbox /usr/local/bin/line-offline > /tmp/line.log 2>&1 &
  launcher_pid=$!
  attempt=0
  while :; do
    window=$(xwininfo -root -tree | awk '/"LINE":/ {print $1; exit}')
    if [ -n "$window" ] && xwininfo -id "$window" > /tmp/window.txt &&
        grep -q 'Map State: IsViewable' /tmp/window.txt; then
      break
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 45 ] || grep -q 'Security verification failed' /tmp/line.log; then
      tail -40 /tmp/line.log >&2
      exit 1
    fi
    sleep 1
  done
  sleep 6
  if grep -q 'Security verification failed' /tmp/line.log; then
    echo 'LINE reported a security verification error.' >&2
    exit 1
  fi
}

check_email_field() {
  capture=$1
  emoji='🔮🔥🙏'
  printf '%s' "$emoji" | xclip -in -selection clipboard
  xdotool windowfocus --sync "$window" mousemove --window "$window" 144 149 click 1 \
    key --clearmodifiers ctrl+v
  sleep 3
  cp /tmp/frames/Xvfb_screen0 "/results/$capture.xwd"
  xwininfo -id "$window" | awk '
    /Absolute upper-left X:/ { x = $NF }
    /Absolute upper-left Y:/ { y = $NF }
    /Width:/ { w = $NF }
    /Height:/ { h = $NF }
    END { print x, y, w, h }' > "/results/$capture-geometry.txt"

  # Require a new clipboard write from LINE when copying back the pasted text.
  printf '%s' 'clipboard sentinel' | xclip -in -selection clipboard
  xdotool key --clearmodifiers ctrl+a ctrl+c
  sleep 1
  test "$(xclip -out -selection clipboard)" = "$emoji"
  printf '%s launch: confirmed the email field contains %s\n' "$capture" "$emoji"
}

open_line
state=$prefix/.line-offline-installed
test -s "$state"
state_inode=$(stat -c %i "$state")
line_data=$(dirname -- "$(dirname -- "$(sed -n '2p' "$state")")")/Data
as_user /bin/sh -c 'printf "%s\n" persistent > "$1/.verification-profile"' _ "$line_data"
cmp "$release/payload/fonts/emoji/seguiemj.ttf" "$prefix/drive_c/windows/Fonts/seguiemj.ttf"
for style in Regular Bold; do
  font=NotoSansThai-$style.ttf
  cmp "$release/payload/fonts/thai/$font" "$prefix/drive_c/windows/Fonts/$font"
done
grep -iE 'Loaded L".*dwrite\.dll|Loaded L".*qwindows\.dll' /tmp/line.log | tail -3
check_email_field first

as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -k
wait "$launcher_pid" || true
as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -w
open_line
test "$(stat -c %i "$state")" = "$state_inode"
test "$(cat "$line_data/.verification-profile")" = persistent
echo 'Reopened LINE using its existing Wine prefix and profile files.'
check_email_field restart
CONTAINER

docker cp "$container:/results/." "$scratch"
for capture in first restart; do
  read -r window_x window_y window_w window_h < "$scratch/$capture-geometry.txt"
  geometry=$(printf '%sx%s%+d%+d' "$window_w" "$window_h" "$window_x" "$window_y")
  magick "xwd:$scratch/$capture.xwd" -crop "$geometry" +repage -strip "$scratch/$capture.png"
  # The fixed login layout puts the three glyphs in these columns of the email box.
  for offset in 67 82 96; do
    pixels=$(magick "$scratch/$capture.png" -crop "14x24+$offset+137" +repage \
      -fx '(max(r,max(g,b)) - min(r,min(g,b))) > 0.20 ? 1 : 0' \
      -format '%[fx:round(mean*w*h)]' info:)
    test "$pixels" -ge 12
    printf '%s launch, colored pixels at email field offset %s: %s\n' "$capture" "$offset" "$pixels"
  done
done
mkdir -p -- "$results"
install -m 644 "$scratch/restart.png" "$results/line-login-emoji.png"
echo 'PASS: single-file offline installation, prefix reuse, and three colored emoji before and after restart.'
