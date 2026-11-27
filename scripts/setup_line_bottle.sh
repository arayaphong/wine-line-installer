#!/usr/bin/env bash
# One-shot setup of a Bottles bottle that installs and runs LINE (LineInst.exe -> LINE.exe) on Wine.
#
#   bash scripts/setup_line_bottle.sh [BOTTLE_NAME] [--run]
#
# Steps (each skipped when already done):
#   1. Bottles flatpak present
#   2. base runner soda-11.0-10 installed (downloaded by Bottles, ~174 MB)
#   3. patched Wine DLLs in wine-src/out (else run scripts/build_wine_dlls.sh)
#   4. runner soda-11.0-10-line built (scripts/build_line_runner.sh)
#   5. bottle created: win64, Custom environment, runner soda-11.0-10-line
#   6. Microsoft DLLs + catalogs + overrides + TLS registry (scripts/install_ms_dlls.sh)
#   7. "on-disk" Microsoft x64 DLLs for LINE.exe's check, Wine keeps running builtin
#      (scripts/install_ondisk_ms_dlls.sh, files from ms-dlls/x64-ondisk/)
#   8. LineInst.exe copied to Bottles' temp dir (the flatpak can't see ~/Projects)
#   9. with --run: run LineInst.exe with a log in analysis/; it installs LINE and starts it (login window)
#  10. LineUpdater.exe chmod 000 (LOCK_UPDATER=0 to skip) so restore/auto-update can't overwrite files
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
BOTTLE=${1:-LINE}
RUN=${2:-}
APP=com.usebottles.bottles
D=$HOME/.var/app/$APP/data/bottles
RUNNER=soda-11.0-10-line

say() { printf '\n== %s\n' "$*"; }

say "1. Bottles flatpak"
flatpak info "$APP" >/dev/null 2>&1 || { echo "install it first: flatpak install flathub $APP" >&2; exit 1; }
mkdir -p "$D/temp"
cp "$HERE/scripts/bottles_deps.py" "$D/temp/bottles_deps.py"

say "2. base runner soda-11.0-10"
if [ ! -x "$D/runners/soda-11.0-10/bin/wine" ]; then
  flatpak run --command=python3 "$APP" "$D/temp/bottles_deps.py" install-runner soda-11.0-10
fi
[ -x "$D/runners/soda-11.0-10/bin/wine" ] || { echo "runner soda-11.0-10 missing" >&2; exit 1; }

say "3. patched Wine DLLs"
for f in i386-windows/wintrust.dll x86_64-windows/wintrust.dll i386-windows/secur32.dll x86_64-windows/secur32.dll x86_64-windows/dwrite.dll; do
  if [ ! -f "$HERE/wine-src/out/$f" ]; then bash "$HERE/scripts/build_wine_dlls.sh"; break; fi
done

say "4. runner $RUNNER"
bash "$HERE/scripts/build_line_runner.sh"

say "5. bottle $BOTTLE"
if [ ! -d "$D/bottles/$BOTTLE" ]; then
  flatpak run --command=bottles-cli "$APP" new --bottle-name "$BOTTLE" --environment custom --arch win64 --runner "$RUNNER"
else
  flatpak run --command=bottles-cli "$APP" edit -b "$BOTTLE" --runner "$RUNNER"
fi
grep -q "^Runner: $RUNNER" "$D/bottles/$BOTTLE/bottle.yml" || { echo "bottle runner is not $RUNNER" >&2; exit 1; }
flatpak run --command=bash "$APP" -c "export WINEPREFIX='$D/bottles/$BOTTLE' WINEDEBUG=-all; '$D/runners/$RUNNER/bin/wineboot' -u; '$D/runners/$RUNNER/bin/wineserver' -w"

say "6. Microsoft DLLs"
RUNNER=$RUNNER bash "$HERE/scripts/install_ms_dlls.sh" "$BOTTLE"

say "7. on-disk MS DLLs for LINE.exe"
RUNNER=$RUNNER bash "$HERE/scripts/install_ondisk_ms_dlls.sh" "$BOTTLE"

say "8. LineInst.exe"
cp "$HERE/LineInst.exe" "$D/temp/LineInst.exe"
sha256sum "$D/temp/LineInst.exe"

if [ "$RUN" = "--run" ]; then
  say "9. running LineInst.exe (log: analysis/setup-$BOTTLE-run.log)"
  flatpak run --command=bash "$APP" -c "export WINEPREFIX='$D/bottles/$BOTTLE' WINEDEBUG=+msgbox,+process,+message,err,fixme-all; '$D/runners/$RUNNER/bin/wine' '$D/temp/LineInst.exe'" \
    > "$HERE/analysis/setup-$BOTTLE-run.log" 2>&1 || true
  grep -E 'msgbox:MSGBOX|NtCreateUserProcess L.*(LineInst_|LINE\\\\bin)' "$HERE/analysis/setup-$BOTTLE-run.log" | cut -c1-200 || true
fi
if [ "${LOCK_UPDATER:-1}" = 1 ]; then
  say "10. lock LineUpdater"
  bash "$HERE/scripts/lock_line_updater.sh" "$BOTTLE"
fi
say "done. Run the installer from Bottles (Run Executable -> $D/temp/LineInst.exe) or rerun with --run"
