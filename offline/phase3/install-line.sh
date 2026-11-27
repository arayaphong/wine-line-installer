#!/bin/sh
# Install the prepared LINE payload into an initialized win64 Wine prefix.
set -eu

version=26.6.0.4004
payload=$(cd -- "${1:?Usage: install-line.sh PAYLOAD-DIRECTORY}" && pwd -P)
prefix=$(cd -- "${WINEPREFIX:?Set WINEPREFIX to the target Wine prefix}" && pwd -P)
export WINEPREFIX=$prefix
test -f "$prefix/system.reg" && test -d "$prefix/drive_c/windows/syswow64" || {
  echo 'An initialized win64 Wine prefix is required.' >&2
  exit 1
}
(cd "$payload" && sha256sum --quiet -c SHA256SUMS)

thai_fonts=$payload/fonts/thai
if test ! -d "$thai_fonts"; then
  # A phase 3 archive can still use the pinned fonts shipped with the project.
  thai_fonts=$(dirname -- "$0")/../phase4/thai-fonts
  if test ! -f "$thai_fonts/SHA256SUMS"; then
    echo 'The offline Thai fonts are missing. Use the current LINE payload.' >&2
    exit 1
  fi
  (cd "$thai_fonts" && sha256sum --quiet -c SHA256SUMS)
fi

# Resolve the user path in Wine instead of copying the snapshot user's path.
local_appdata_win=$(wine cmd /d /c 'echo %LOCALAPPDATA%')
local_appdata_win=$(printf '%s' "$local_appdata_win" | tr -d '\r')
local_appdata=$(winepath -u "$local_appdata_win")
case $local_appdata in
  "$prefix"/drive_c/users/*/AppData/Local) ;;
  *) echo 'Could not resolve LOCALAPPDATA inside the target prefix.' >&2; exit 1 ;;
esac
line_dir=$local_appdata/LINE
line_bin_win=$local_appdata_win'\LINE\bin'

# Set the final override values before replacing any system DLL files.
override_key='HKCU\Software\Wine\DllOverrides'
for dll in crypt32 dwmapi dxgi mfplat msimg32 userenv version winhttp wininet winmm; do
  wine reg add "$override_key" /v "$dll" /d builtin /f >/dev/null
done
for dll in gdiplus webio; do
  wine reg add "$override_key" /v "$dll" /d native,builtin /f >/dev/null
done
wineserver -w

windows=$prefix/drive_c/windows
install -m 644 "$payload"/ms-dlls/x86/*.dll "$windows/syswow64/"
install -m 644 "$payload"/ms-dlls/x64-ondisk/*.dll "$windows/system32/"
for group in '{127d0a1d-4ef2-11d1-8608-00c04fc295ee}' '{F750E6C3-38EE-11D1-85E5-00C04FC295EE}'; do
  catalog_dir=$windows/system32/catroot/$group
  mkdir -p "$catalog_dir"
  install -m 644 "$payload"/ms-dlls/x86/catroot/*.cat \
    "$payload"/ms-dlls/x64-ondisk/catroot/*.cat "$catalog_dir/"
done

mkdir -p "$line_dir/bin" "$line_dir/Data"
cp -a --remove-destination "$payload/line/bin/." "$line_dir/bin/"
if test ! -e "$line_dir/Data/installLang.ini"; then
  install -m 644 "$payload/line/Data/installLang.ini" "$line_dir/Data/installLang.ini"
fi
chmod 000 "$line_dir/bin/$version/LineUpdater.exe"

install -d "$windows/Fonts"
install -m 644 "$thai_fonts/NotoSansThai-Regular.ttf" "$thai_fonts/NotoSansThai-Bold.ttf" "$windows/Fonts/"
font_key='HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
wine reg add "$font_key" /v 'Noto Sans Thai (TrueType)' /d NotoSansThai-Regular.ttf /f >/dev/null
wine reg add "$font_key" /v 'Noto Sans Thai Bold (TrueType)' /d NotoSansThai-Bold.ttf /f >/dev/null

if test -f "$payload/fonts/emoji/seguiemj.ttf"; then
  install -m 644 "$payload/fonts/emoji/seguiemj.ttf" "$windows/Fonts/"
  wine reg add "$font_key" /v 'Segoe UI Emoji (TrueType)' /d seguiemj.ttf /f >/dev/null
  wine reg add 'HKCU\Software\Wine\AppDefaults\LINE.exe\DirectWrite' \
    /v PrimeColorGlyphRun /t REG_DWORD /d 1 /f >/dev/null
  printf '%s\n' '[Platforms]' 'WindowsArguments = fontengine=native' > "$line_dir/bin/$version/qt.conf"
fi

line_key='HKCU\Software\LINE Corporation\LINE'
for property in InstallDir InstallDirCandidate; do
  wine reg add "$line_key" /v "$property" /d "$line_bin_win\\$version" /f >/dev/null
done
wine reg add "$line_key" /v LauncherPath /d "$line_bin_win\LineLauncher.exe" /f >/dev/null
wine reg add "$line_key" /v CheckDeploy /d 1 /f >/dev/null
wine reg add "$line_key" /v InstallSystemVersion /d 1 /f >/dev/null
wine reg add "$line_key" /v 'Inatall Language' /d 1054 /f >/dev/null
wine reg add "$line_key" /v locale /d th /f >/dev/null
wine reg add "$line_key" /v localeMig /d Y /f >/dev/null
wineserver -w

printf '%s\n' "$line_dir/bin/LineLauncher.exe"
