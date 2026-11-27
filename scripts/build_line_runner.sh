#!/usr/bin/env bash
# Build the Bottles runner "soda-11.0-10-line" = soda-11.0-10 + fixes needed by LINE's installer.
#
#   wintrust.dll, secur32.dll (i386 + x86_64): rebuilt from Valve Wine source (the soda-11.0-10 base) with
#       patches/0001-wintrust-catalog-v2-members.patch, patches/0003-secur32-endpoint-bindings-cng-hash.patch
#       -> wine-src/out/<arch>/{wintrust,secur32}.dll
#   dwrite.dll (x86_64): opt-in compatibility for Qt 6.6's color glyph enumeration (patches/0004)
#   ntdll.dll / user32.dll / dnsapi.dll (i386): soda's own DLLs + stub exports added by add_pe_export_stub.py
#       (source-level equivalent for SbSelectProcedure: patches/0002-ntdll-SbSelectProcedure-stub.patch)
#
# Base runner files are hard-linked; every replaced file is unlinked first so the base runner
# is never modified.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
RUNNERS=$HOME/.var/app/com.usebottles.bottles/data/bottles/runners
BASE=$RUNNERS/soda-11.0-10
NEW=$RUNNERS/soda-11.0-10-line
OUT=$HERE/wine-src/out
[ -d "$BASE" ] || { echo "base runner missing: $BASE" >&2; exit 1; }
rebuilt_dlls=(i386-windows/wintrust.dll x86_64-windows/wintrust.dll
              i386-windows/secur32.dll x86_64-windows/secur32.dll x86_64-windows/dwrite.dll)
for f in "${rebuilt_dlls[@]}"; do
  [ -f "$OUT/$f" ] || { echo "missing $OUT/$f (run scripts/build_wine_dlls.sh first)" >&2; exit 1; }
done

# STATUS_NOT_IMPLEMENTED for the ALPC calls dwmapi uses to talk to DWM (no DWM in Wine)
NTDLL_STUBS=(
  SbSelectProcedure:16
  NtAlpcConnectPort:44:0xC0000002
  NtAlpcCreatePortSection:24:0xC0000002
  NtAlpcCreateSectionView:12:0xC0000002
  NtAlpcDeletePortSection:12:0xC0000002
  NtAlpcDeleteSectionView:12:0xC0000002
  NtAlpcSendWaitReceivePort:32:0xC0000002
)
# private user32 APIs imported by Windows 11 dwmapi; FALSE / 0 = "no composition"
USER32_STUBS=(
  IsThreadDesktopComposited:0
  IsTopLevelWindow:4
  GetWindowCompositionAttribute:8
  DwmGetDxSharedSurface:24
)

# used by native (Win7 SP1) winhttp; error = "no DNS proxy info" (ERROR_CALL_NOT_IMPLEMENTED)
DNSAPI_STUBS=(
  DnsGetProxyInformation:20:0x78
  DnsFreeProxyName:4
)

mkdir -p "$OUT/i386-windows"
python3 -I "$HERE/scripts/add_pe_export_stub.py" "$BASE/lib/wine/i386-windows/ntdll.dll" "$OUT/i386-windows/ntdll.dll" "${NTDLL_STUBS[@]}"
python3 -I "$HERE/scripts/add_pe_export_stub.py" "$BASE/lib/wine/i386-windows/user32.dll" "$OUT/i386-windows/user32.dll" "${USER32_STUBS[@]}"
python3 -I "$HERE/scripts/add_pe_export_stub.py" "$BASE/lib/wine/i386-windows/dnsapi.dll" "$OUT/i386-windows/dnsapi.dll" "${DNSAPI_STUBS[@]}"

if [ ! -d "$NEW" ]; then
  cp -al "$BASE" "$NEW"
fi
for f in i386-windows/ntdll.dll i386-windows/user32.dll i386-windows/dnsapi.dll \
         "${rebuilt_dlls[@]}"; do
  rm -f "${NEW:?}/lib/wine/${f:?}"
  cp "$OUT/$f" "$NEW/lib/wine/$f"
done
(cd "$OUT" && sha256sum */*.dll > SHA256SUMS)
echo "runner ready: $NEW"
