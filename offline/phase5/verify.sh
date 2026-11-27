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
winex11_sha256=$(awk '$2 == "x86_64-unix/winex11.so" { print $1 }' "$offline/../wine-src/out/SHA256SUMS")
media_manifest_sha256=$(sha256sum < "$offline/phase3/media-player-files.sha256")
if ! [[ "$winex11_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo 'The Wine build manifest is missing the patched winex11.so checksum.' >&2
  exit 1
fi
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

docker exec -e "INSTALLER_SHA256=$installer_sha256" -e "WINEX11_SHA256=$winex11_sha256" \
  -e "MEDIA_MANIFEST_SHA256=${media_manifest_sha256%% *}" \
  -i "$container" /bin/sh -s <<'INSTALL'
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
unix=$release/wine/lib/wine/x86_64-unix
printf '%s  %s\n' "$WINEX11_SHA256" "$unix/winex11.so" | sha256sum -c -
if ! LD_LIBRARY_PATH="$unix" ldd -r "$unix/winex11.so" > /tmp/winex11-deps.log 2>&1 ||
    grep -qE 'not found|undefined symbol' /tmp/winex11-deps.log; then
  cat /tmp/winex11-deps.log >&2
  exit 1
fi
echo 'The packaged X11 driver resolves all relocations on clean Debian.'
codecs=$release/media-codecs
for module in "$unix/winegstreamer.so" "$codecs/plugins/libgstvideoparsersbad.so" \
    "$codecs/plugins/libgstaudioparsers.so"; do
  if ! LD_LIBRARY_PATH="$unix:$codecs/lib" ldd -r "$module" > /tmp/media-deps.log 2>&1 ||
      grep -qE 'not found|undefined symbol' /tmp/media-deps.log; then
    cat /tmp/media-deps.log >&2
    exit 1
  fi
done
echo 'The bundled WineGStreamer and H.264/AAC parser libraries resolve on clean Debian.'
media_bundle=line-media-player/1.2.0.662
awk -v root="$media_bundle/" 'index($2, root) == 1 { print $1 "  " substr($2, length(root) + 1) }' \
  "$release/payload/SHA256SUMS" > /tmp/line-media-player.sha256
printf '%s  /tmp/line-media-player.sha256\n' "$MEDIA_MANIFEST_SHA256" | sha256sum --quiet -c -
(cd "$release/payload/$media_bundle" && sha256sum --quiet -c /tmp/line-media-player.sha256)
echo 'Verified all pinned media player files in the system installation.'
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
start_display() {
  Xvfb "$DISPLAY" -screen 0 1024x768x24 -nolisten tcp -ac -noreset "$1" GLX \
    -fbdir /tmp/frames > /tmp/xvfb.log 2>&1 &
  xvfb_pid=$!
  attempt=0
  until xwininfo -root >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if ! kill -0 "$xvfb_pid" || [ "$attempt" -ge 10 ]; then
      cat /tmp/xvfb.log >&2
      exit 1
    fi
    sleep 1
  done
}
start_display -extension
trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT

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

close_line() {
  as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -k
  wait "$launcher_pid" || true
  as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -w
}

check_cjk_fallback() {
  cmp "$release/payload/fonts/cjk/NotoSansCJK-Regular.ttc" \
    "$prefix/drive_c/windows/Fonts/NotoSansCJK-Regular.ttc"
  as_user env WINEPREFIX="$prefix" WINEDEBUG=-all "$release/wine/bin/wine" reg query \
    'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
    /v 'Noto Sans CJK JP (OpenType)' | tr -d '\r' | \
    grep -E 'Noto Sans CJK JP \(OpenType\)[[:space:]]+REG_SZ[[:space:]]+NotoSansCJK-Regular\.ttc[[:space:]]*$'
  as_user env WINEPREFIX="$prefix" WINEDEBUG=-all "$release/wine/bin/wine" reg query \
    'HKCU\Software\Wine\Fonts\Replacements' /v 'MS UI Gothic' | tr -d '\r' | \
    grep -E 'MS UI Gothic[[:space:]]+REG_SZ[[:space:]]+Noto Sans CJK JP[[:space:]]*$'
}

paste_email_text() {
  printf '%s' "$1" | xclip -in -selection clipboard
  xdotool windowfocus --sync "$window" mousemove --window "$window" 144 149 click 1 \
    key --clearmodifiers ctrl+a ctrl+v Tab mousemove --window "$window" 14 15
  sleep 1
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

  text='ภาษาไทย ｊｕｎｅ 🔮🔥🙏'
  paste_email_text "$text"
  cp /tmp/frames/Xvfb_screen0 "/results/$capture-text.xwd"
  printf '%s' 'clipboard sentinel' | xclip -in -selection clipboard
  xdotool mousemove --window "$window" 144 149 click 1 key --clearmodifiers ctrl+a ctrl+c
  sleep 1
  test "$(xclip -out -selection clipboard)" = "$text"
  printf '%s launch: confirmed the email field contains %s\n' "$capture" "$text"

  # Single-character captures let the host reject both blanks and identical tofu.
  # Tab moves the caret outside the email crop before each capture.
  glyph_index=0
  for glyph in ｊ ｕ ｎ ｅ; do
    glyph_index=$((glyph_index + 1))
    paste_email_text "$glyph"
    cp /tmp/frames/Xvfb_screen0 "/results/$capture-fullwidth-$glyph_index.xwd"
  done
}

open_line
state=$prefix/.line-offline-installed
test -s "$state"
state_inode=$(stat -c %i "$state")
line_data=$(dirname -- "$(dirname -- "$(sed -n '2p' "$state")")")/Data
media_parent=$line_data/plugin/LineMediaPlayer
media_dir=$media_parent/1.2.0.662
(cd "$media_dir" && sha256sum --quiet -c /tmp/line-media-player.sha256)
echo 'First launch installed the pinned media player into the new Wine prefix.'
as_user /bin/sh -c 'printf "%s\n" persistent > "$1/.verification-profile"' _ "$line_data"
cmp "$release/payload/fonts/emoji/seguiemj.ttf" "$prefix/drive_c/windows/Fonts/seguiemj.ttf"
for style in Regular Bold; do
  font=NotoSansThai-$style.ttf
  cmp "$release/payload/fonts/thai/$font" "$prefix/drive_c/windows/Fonts/$font"
done
check_cjk_fallback
grep -iE 'Loaded L".*dwrite\.dll|Loaded L".*qwindows\.dll' /tmp/line.log | tail -3
check_email_field first

close_line
open_line
test "$(stat -c %i "$state")" = "$state_inode"
test "$(cat "$line_data/.verification-profile")" = persistent
echo 'Reopened LINE using its existing Wine prefix and profile files.'
check_cjk_fallback
check_email_field restart

# Exercise changed-bundle provisioning on a prefix from a player-free build.
close_line
as_user mv "$media_dir" "$prefix/.verification-old-media"
as_user mkdir "$media_parent/other-version"
as_user touch "$media_parent/other-version/.verification-keep"
as_user mv "$prefix/drive_c/windows/Fonts/NotoSansCJK-Regular.ttc" "$prefix/.verification-old-cjk-font"
as_user env WINEPREFIX="$prefix" WINEDEBUG=-all "$release/wine/bin/wine" reg delete \
  'HKCU\Software\Wine\Fonts\Replacements' /v 'MS UI Gothic' /f >/dev/null
as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -w
as_user /bin/sh -c 'printf "previous-build\n%s\n" "$2" > "$1"' _ "$state" "$(sed -n '2p' "$state")"
open_line
test "$(sed -n '1p' "$state")" = "$(cat "$release/bundle.sha256")"
(cd "$media_dir" && sha256sum --quiet -c /tmp/line-media-player.sha256)
test "$(cat "$line_data/.verification-profile")" = persistent
test -f "$media_parent/other-version/.verification-keep"
check_cjk_fallback
echo 'Updated an existing Wine prefix with the media player and preserved its profile and other plugin directory.'
check_email_field update
close_line

# The login checks use basic X11. The player requires Direct3D via GLX.
kill "$xvfb_pid"
wait "$xvfb_pid" || true
start_display +extension
(
  cd "$media_dir"
  as_user env WINEPREFIX="$prefix" WINEDEBUG=-all QSG_INFO=1 LIBGL_ALWAYS_SOFTWARE=1 \
    GST_PLUGIN_PATH_1_0="$release/media-codecs/plugins" LD_LIBRARY_PATH="$release/media-codecs/lib" \
    "$release/wine/bin/wine" ./LineMediaPlayer.exe standalone=1
) > /tmp/line-media-player.log 2>&1 &
media_pid=$!
attempt=0
while :; do
  media_window=$(xwininfo -root -tree | awk '/"LineMediaPlayer":/ { print $1; exit }')
  if [ -n "$media_window" ] && xwininfo -id "$media_window" > /tmp/media-window.txt &&
      grep -q 'Map State: IsViewable' /tmp/media-window.txt &&
      grep -q 'using this adapter' /tmp/line-media-player.log; then
    break
  fi
  attempt=$((attempt + 1))
  if ! kill -0 "$media_pid" || [ "$attempt" -ge 30 ]; then
    tail -35 /tmp/line-media-player.log >&2
    exit 1
  fi
  sleep 1
done
as_user env WINEPREFIX="$prefix" "$release/wine/bin/wineserver" -k
wait "$media_pid" || true
echo 'The bundled LineMediaPlayer.exe opened and initialized Direct3D 11 with networking disabled.'
CONTAINER

docker cp "$container:/results/." "$scratch"
for capture in first restart update; do
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
  magick "xwd:$scratch/$capture-text.xwd" -crop "$geometry" +repage -strip "$scratch/$capture-text.png"
  for glyph_index in 1 2 3 4; do
    magick "xwd:$scratch/$capture-fullwidth-$glyph_index.xwd" -crop "$geometry" +repage \
      -crop '24x24+65+137' +repage -colorspace gray -threshold 60% -negate \
      "$scratch/$capture-fullwidth-$glyph_index.png"
    pixels=$(magick "$scratch/$capture-fullwidth-$glyph_index.png" \
      -format '%[fx:round(mean*w*h)]' info:)
    test "$pixels" -ge 4
    printf '%s launch, fullwidth glyph %s ink pixels: %s\n' "$capture" "$glyph_index" "$pixels"
    other=1
    while [ "$other" -lt "$glyph_index" ]; do
      difference=$(magick "$scratch/$capture-fullwidth-$glyph_index.png" \
        "$scratch/$capture-fullwidth-$other.png" -compose difference -composite \
        -format '%[fx:round(mean*w*h)]' info:)
      printf '%s launch, fullwidth glyphs %s/%s differing pixels: %s\n' \
        "$capture" "$glyph_index" "$other" "$difference"
      test "$difference" -ge 3
      other=$((other + 1))
    done
  done
done
mkdir -p -- "$results"
install -m 644 "$scratch/restart.png" "$results/line-login-emoji.png"
install -m 644 "$scratch/restart-text.png" "$results/line-login-text.png"
echo 'PASS: single-file offline installation, bundled media player launch, prefix reuse and migration, Thai/fullwidth text, and three colored emoji.'
