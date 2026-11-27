#!/usr/bin/env bash
# "On-disk" Microsoft DLLs for LINE.exe (x64): put genuine signed 64-bit DLLs into
# drive_c/windows/system32 but force Wine to keep using its *builtin* implementation
# (DllOverrides <name>=builtin). LINE.exe's check hashes the file on disk (WinVerifyTrust +
# catalog), while the code that runs stays Wine's. See analysis/NOTES.md.
#
#   bash scripts/install_ondisk_ms_dlls.sh BOTTLE [name ...]
#   - names default to every ms-dlls/x64-ondisk/*.dll
#   - a missing DLL is extracted from the Windows image $WIM (default: Bottles temp install.wim)
#     into ms-dlls/x64-ondisk/, with the catalog that holds its hash
# The Wine placeholder that was there is saved to analysis/ondisk-backup/<bottle>/.
set -euo pipefail
shopt -s nullglob
HERE=$(cd "$(dirname "$0")/.." && pwd)
BOTTLE=${1:?bottle name}; shift || true
RUNNER=${RUNNER:-soda-11.0-10-line}
APP=com.usebottles.bottles
D=$HOME/.var/app/$APP/data/bottles
B=$D/bottles/$BOTTLE
SRC=$HERE/ms-dlls/x64-ondisk
WIM=${WIM:-$D/temp/win11-iso/install.wim}
CATDIR='Windows/System32/CatRoot/{F750E6C3-38EE-11D1-85E5-00C04FC295EE}'
mkdir -p "$SRC/catroot"
[ -d "$B" ] || { echo "no bottle $B" >&2; exit 1; }

names=()
for n in "$@"; do
  n=${n,,}; n=${n%.dll}
  [[ $n =~ ^[a-z0-9_][a-z0-9_-]*$ ]] || { printf 'invalid DLL name: %s\n' "$n" >&2; exit 2; }
  names+=("$n")
done
if [ ${#names[@]} -eq 0 ]; then
  for f in "$SRC"/*.dll; do names+=("$(basename "${f%.dll}")"); done
fi
[ ${#names[@]} -gt 0 ] || { echo "no DLLs in $SRC" >&2; exit 1; }

tmp=$D/temp/ondisk-tmp
mkdir -p "$tmp"
# Check the source files before changing the bottle.
for n in "${names[@]}"; do
  dll=$SRC/$n.dll
  if [ ! -f "$dll" ]; then
    [ -f "$WIM" ] || { echo "need $WIM to extract $n.dll" >&2; exit 1; }
    flatpak run --command=7z "$APP" e -y -o"$tmp" "$WIM" "1/Windows/System32/$n.dll" >/dev/null
    dll=$tmp/$n.dll
    [ -f "$dll" ] || { echo "$n.dll not in image" >&2; exit 1; }
  fi
  # catalog needed only when the file has no embedded signature (find it in the image's CatRoot)
  trust=$(python3 -I "$HERE/scripts/find_catalog.py" "$SRC/catroot" "$dll")
  if [[ $trust != *embedded_sig=True* && $trust != *".cat'"* ]]; then
    [ -d "$tmp/cat/1/$CATDIR" ] || flatpak run --command=7z "$APP" x -y -o"$tmp/cat" "$WIM" "1/$CATDIR/*" >/dev/null
    trust=$(python3 -I "$HERE/scripts/find_catalog.py" "$tmp/cat/1/$CATDIR" "$dll")
    cat=$(awk -F"'" '/sha1/ && NF>2 {print $2; exit}' <<< "$trust")
    [ -n "$cat" ] || { echo "no catalog for $n.dll" >&2; exit 1; }
    cp "$tmp/cat/1/$CATDIR/$cat" "$SRC/catroot/"
  fi
  [[ $dll == "$SRC/$n.dll" ]] || mv -- "$dll" "$SRC/$n.dll"
done

# Set the overrides before copying native files into system32, so Wine keeps loading builtin.
flatpak run --command=bash "$APP" -ec '
  export WINEPREFIX=$1 WINEDEBUG=-all
  runner=$2
  shift 2
  for dll in "$@"; do
    "$runner/bin/wine" reg add "HKCU\Software\Wine\DllOverrides" /v "$dll" /d builtin /f >/dev/null
  done
  "$runner/bin/wineserver" -w
' bash "$B" "$D/runners/$RUNNER" "${names[@]}"

bk=$HERE/analysis/ondisk-backup/$BOTTLE
mkdir -p "$bk"
for n in "${names[@]}"; do
  target=$B/drive_c/windows/system32/$n.dll
  if [[ ! -e $bk/$n.dll && -f $target ]]; then
    cp -- "$target" "$bk/$n.dll"
  fi
  install -m644 "$SRC/$n.dll" "$target"
  echo "on-disk $n.dll"
done
for g in "{127d0a1d-4ef2-11d1-8608-00c04fc295ee}" "{F750E6C3-38EE-11D1-85E5-00C04FC295EE}"; do
  mkdir -p "$B/drive_c/windows/system32/catroot/$g"
  for c in "$SRC"/catroot/*.cat; do [ -f "$c" ] && install -m644 "$c" "$B/drive_c/windows/system32/catroot/$g/"; done
done
(cd "$SRC" && sha256sum -- *.dll catroot/*.cat > SHA256SUMS)
echo done
