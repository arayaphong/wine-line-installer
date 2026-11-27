#!/usr/bin/env bash
set -euo pipefail

offline=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=line-offline-test:debian-13-slim-amd64

if [[ ! ${DISPLAY:-} =~ ^:([0-9]+)(\.[0-9]+)?$ ]]; then
  echo 'Run this from a local desktop terminal with an X11 or XWayland display.' >&2
  exit 1
fi
socket=/tmp/.X11-unix/X${BASH_REMATCH[1]}
authority=${XAUTHORITY:-"$HOME/.Xauthority"}
if [[ ! -S "$socket" || ! -f "$authority" || ! -r "$authority" ]]; then
  echo 'Could not find the current X11 socket and a readable Xauthority file.' >&2
  exit 1
fi
authority=$(realpath -- "$authority")

# XWayland runs in the host IPC namespace. A container-local SysV allocation
# limit makes Wine use ordinary X11 drawing across the socket.
exec docker run --rm --init --interactive --pull never --network none \
  --ipc private --sysctl kernel.shmmax=1 \
  --hostname "$(hostname)" --env DISPLAY --env XAUTHORITY=/run/line-xauthority \
  --env "LINE_PREVIEW_UID=$(id -u)" --env "LINE_PREVIEW_GID=$(id -g)" \
  --mount "type=bind,src=$socket,dst=$socket,readonly" \
  --mount "type=bind,src=$authority,dst=/run/line-xauthority,readonly" \
  --mount "type=bind,src=$offline/phase2,dst=/input/phase2,readonly" \
  --mount "type=bind,src=$offline/phase3,dst=/input/phase3,readonly" \
  "$image" /bin/sh -s <<'CONTAINER'
set -eu
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
test "$(cat /etc/debian_version)" = 13.8

echo 'Preparing LINE from the local offline archives...'
if ! sh /input/phase2/install-runtime-debs.sh /input/phase2/runtime-debs > /tmp/line-dpkg.log 2>&1; then
  cat /tmp/line-dpkg.log >&2
  exit 1
fi
runner=soda-11.0-10-line.runtime.tar.gz
archive=line-26.6.0.4004.payload.tar.gz
mkdir -p /opt /tmp/line-payload
(
  cd /input/phase2
  sha256sum --quiet -c "$runner.sha256"
  tar -xzf "$runner" -C /opt
)
(
  cd /input/phase3
  sha256sum --quiet -c "$archive.sha256"
  tar -xzf "$archive" -C /tmp/line-payload
)

if ! getent group "$LINE_PREVIEW_GID" >/dev/null; then
  groupadd --gid "$LINE_PREVIEW_GID" line-preview
fi
if ! getent passwd "$LINE_PREVIEW_UID" >/dev/null; then
  useradd --no-create-home --uid "$LINE_PREVIEW_UID" --gid "$LINE_PREVIEW_GID" \
    --home-dir /home/line-preview line-preview
fi
install -d -m 700 -o "$LINE_PREVIEW_UID" -g "$LINE_PREVIEW_GID" /home/line-preview

exec setpriv --reuid "$LINE_PREVIEW_UID" --regid "$LINE_PREVIEW_GID" --clear-groups \
  --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
  env HOME=/home/line-preview PATH=/opt/wine/bin:/usr/bin:/bin \
    WINEPREFIX=/home/line-preview/wine WINEARCH=win64 WINEDEBUG=-all \
    WINEDLLOVERRIDES='mscoree,mshtml=' /bin/sh -ec '
  trap "wineserver -k >/dev/null 2>&1 || true" EXIT
  trap "exit 130" INT
  trap "exit 143" TERM

  wineboot -i
  wineserver -w
  launcher=$(sh /input/phase3/install-line.sh /tmp/line-payload)
  cd -- "$(dirname -- "$launcher")"
  printf "Opening LINE on the host display %s\n" "$DISPLAY"
  wine "$launcher" &
  wait "$!"
  wineserver -w &
  wait "$!"
'
CONTAINER
