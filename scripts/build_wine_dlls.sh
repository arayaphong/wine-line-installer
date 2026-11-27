#!/usr/bin/env bash
# Rebuild the patched Wine PE DLLs into wine-src/out/<arch>/ (wintrust, secur32 and x64 dwrite).
# Only needed when wine-src/out/ is missing or the patches change.
#
# Needs: git, autoconf, flex, bison, python3, make, gcc, clang + lld-link (PE cross compiler).
# Source: ValveSoftware/wine at the tag soda-11.0-10 is based on (see VALVE_WINE_TAG in
#         bottlesdevs/wine .github/workflows/build-soda.yml, commit 75ceacbc for soda-11.0-10).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
TAG=experimental-wine-bleeding-edge-11.0-428201-20260904-pdf1645-w0509a0-dd7ac25-v35bdee
SRC=$HERE/wine-src/valve-wine
BUILD=$HERE/wine-src/build
OUT=$HERE/wine-src/out
JOBS=${JOBS:-$(nproc)}

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch "$TAG" https://github.com/ValveSoftware/wine.git "$SRC"
fi

cd "$SRC"
for p in "$HERE"/patches/0001-*.patch "$HERE"/patches/0002-*.patch "$HERE"/patches/0003-*.patch "$HERE"/patches/0004-*.patch; do
  if git apply --reverse --check "$p" 2>/dev/null; then
    echo "already applied: $(basename "$p")"
  else
    git apply "$p"; echo "applied: $(basename "$p")"
  fi
done

if [ ! -x configure ]; then
  autoreconf -fi
  ./tools/make_requests
  ./tools/make_specfiles
fi
# Valve's tree doesn't ship the generated Vulkan sources; generate them offline from the bundled XML
if [ ! -f dlls/winevulkan/loader_thunks.c ]; then
  (cd dlls/winevulkan && python3 make_vulkan -x vk.xml -X video.xml)
fi

mkdir -p "$BUILD"
cd "$BUILD"
if [ ! -f Makefile ]; then
  "$SRC/configure" --enable-archs=i386,x86_64 --disable-tests --without-x --without-freetype \
    --without-gstreamer --without-wayland --without-vulkan --without-opengl --without-alsa --without-pulse \
    --without-oss --without-cups --without-sane --without-gphoto --without-v4l2 --without-pcap --without-krb5 \
    --without-netapi --without-usb --without-udev --without-dbus --without-capi --without-sdl --without-unwind \
    --without-inotify --without-fontconfig --without-gssapi --without-ffmpeg > configure.log
fi

TARGETS=(dlls/dwrite/x86_64-windows/dwrite.dll)
for a in i386 x86_64; do
  TARGETS+=(dlls/wintrust/$a-windows/wintrust.dll dlls/secur32/$a-windows/secur32.dll)
done
make -j"$JOBS" "${TARGETS[@]}"

for a in i386 x86_64; do
  mkdir -p "$OUT/$a-windows"
  cp dlls/wintrust/$a-windows/wintrust.dll dlls/secur32/$a-windows/secur32.dll "$OUT/$a-windows/"
done
cp dlls/dwrite/x86_64-windows/dwrite.dll "$OUT/x86_64-windows/"
echo "built into $OUT (ntdll/user32/dnsapi stubs are made by build_line_runner.sh)"
