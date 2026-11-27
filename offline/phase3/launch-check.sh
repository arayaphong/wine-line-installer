#!/bin/sh
set -eu

work=$1
version=26.6.0.4004
archive=line-$version.payload.tar.gz
mkdir "$work/payload"
(
  cd "$work"
  sha256sum --quiet -c "$archive.sha256"
  tar -xzf "$archive" -C payload
)
launcher=$(sh "$work/install-line.sh" "$work/payload")
app_dir=$(dirname -- "$launcher")
line="$app_dir/$version/LINE.exe"
test ! -r "$app_dir/$version/LineUpdater.exe"
printf 'Installed LINE %s in the new profile\n' "$version"
sha256sum "$line"

font_key='HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
for style in Regular Bold; do
  font=NotoSansThai-$style.ttf
  cmp "$work/payload/fonts/thai/$font" "$WINEPREFIX/drive_c/windows/Fonts/$font"
  registry_name='Noto Sans Thai (TrueType)'
  if test "$style" = Bold; then
    registry_name='Noto Sans Thai Bold (TrueType)'
  fi
  wine reg query "$font_key" /v "$registry_name" | tr -d '\r' | grep -F "$font"
done
echo 'Verified the Thai fonts installed by the offline payload'

cd "$app_dir"
WINEDEBUG=+msgbox,+process,+loaddll,err+all,fixme-all wine "$launcher" > "$work/line.log" 2>&1 &

attempt=0
status=1
while test "$attempt" -lt 35; do
  xwininfo -root -tree > "$work/windows.txt"
  if grep -q 'Security verification failed' "$work/line.log"; then
    break
  fi
  window=$(awk '/"LINE":/ { print $1; exit }' "$work/windows.txt")
  if test -n "$window" && grep -iq 'qwindows\.dll.*: native' "$work/line.log" &&
    xwininfo -id "$window" > "$work/window.txt" && grep -q 'Map State: IsViewable' "$work/window.txt"; then
    status=0
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done

if test "$status" -eq 0; then
  # Wine maps the Qt window before the application finishes drawing it.
  sleep 6
  if grep -q 'Security verification failed' "$work/line.log" ||
    ! xwininfo -id "$window" > "$work/window.txt" ||
    ! grep -q 'Map State: IsViewable' "$work/window.txt"; then
    status=1
  fi
fi
if test "$status" -eq 0; then
  grep -E 'Window id:|Width:|Height:|Map State:' "$work/window.txt"
else
  xwininfo -root -tree
fi
grep -iE 'MSGBOX_OnInit|err:module:|Unhandled exception|unimplemented function|Loaded L".*\\LINE\.exe"|Loaded L".*\\qwindows\.dll"' \
  "$work/line.log" | grep -v 'lsteamclient disabled' | tail -40 > "$work/results/line-launch-trace.log"
cat "$work/results/line-launch-trace.log"
cp "$work/frames/Xvfb_screen0" "$work/results/line-startup.xwd"

if test "$status" -eq 0; then
  echo 'PASS: the LINE launcher opened a visible Qt window in the isolated prefix'
else
  echo 'FAIL: no visible LINE Qt window passed the startup check' >&2
fi
exit "$status"
