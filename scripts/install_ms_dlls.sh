#!/usr/bin/env bash
# Install Microsoft-signed 32-bit DLLs + their catalogs into a Bottles bottle so
# LineInst.exe's DLL signature check passes on Wine (needs runner soda-11.0-10-line: Wine with patches/ applied).
#
#   ms-dlls/x86/*.dll          -> drive_c/windows/syswow64/   (override native,builtin)
#   ms-dlls/x86/catroot/*.cat  -> drive_c/windows/system32/catroot/{127d0a1d-...} and {F750E6C3-...}
#
# To add a DLL (e.g. dwmapi.dll, msimg32.dll): put it in ms-dlls/x86/ and the .cat that holds
# its Authenticode hash in ms-dlls/x86/catroot/ (find it with scripts/find_catalog.py), then rerun.
# Do NOT add msftedit.dll: the native one needs real msls31 and crashes; LineInst does not verify it.
set -euo pipefail
BOTTLE=${1:-LINE}
RUNNER=${RUNNER:-soda-11.0-10-line}
HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC=$HERE/ms-dlls/x86
D=$HOME/.var/app/com.usebottles.bottles/data/bottles
B=$D/bottles/$BOTTLE
[ -d "$B" ] || { echo "bottle not found: $B" >&2; exit 1; }

names=()
for f in "$SRC"/*.dll; do
  install -m644 "$f" "$B/drive_c/windows/syswow64/$(basename "$f")"
  names+=("$(basename "${f%.dll}" | tr 'A-Z' 'a-z')")
  echo "dll  $(basename "$f")"
done

for g in "{127d0a1d-4ef2-11d1-8608-00c04fc295ee}" "{F750E6C3-38EE-11D1-85E5-00C04FC295EE}"; do
  mkdir -p "$B/drive_c/windows/system32/catroot/$g"
  for c in "$SRC"/catroot/*.cat; do
    install -m644 "$c" "$B/drive_c/windows/system32/catroot/$g/$(basename "$c")"
  done
done
echo "cat  $(ls "$SRC"/catroot/*.cat | wc -l) file(s)"

flatpak run --command=bash com.usebottles.bottles -c "
  export WINEPREFIX='$B' WINEDEBUG=-all
  for d in ${names[*]}; do
    '$D/runners/$RUNNER/bin/wine' reg add 'HKCU\\Software\\Wine\\DllOverrides' /v \$d /d native,builtin /f
  done
  # KB3140245 winhttp: allow TLS 1.0/1.1/1.2 by default (LINE's CDN rejects TLS 1.0-only)
  for k in 'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\WinHttp' \
           'HKLM\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\WinHttp'; do
    '$D/runners/$RUNNER/bin/wine' reg add \"\$k\" /v DefaultSecureProtocols /t REG_DWORD /d 0xA80 /f
  done
  '$D/runners/$RUNNER/bin/wineserver' -w"
echo done
