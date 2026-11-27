#!/usr/bin/env bash
# Build the x86_64 Unix X11 driver against the extracted, verified Soda runner.
# Run build_wine_dlls.sh first to apply the patches and generate Wine sources.
set -euo pipefail
export LC_ALL=C

if [ "$#" -ne 2 ]; then
  echo 'Usage: build_wine_x11_driver.sh EXTRACTED_SODA_DIR NEW_BUILD_DIR' >&2
  exit 2
fi

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source=$project/wine-src/valve-wine
base=$(cd -- "$1" && pwd)/lib/wine/x86_64-unix
mkdir -- "$2"
cd -- "$2"

if ! git -C "$source" apply --reverse --check "$project/patches/0005-winex11-line-shadow-stacking.patch"; then
  echo 'Apply the pinned Wine patches with scripts/build_wine_dlls.sh first.' >&2
  exit 1
fi
# Keep the temporary directory out of the driver's debug records.
if ! CFLAGS="${CFLAGS:--g -O2} -fdebug-prefix-map=$PWD=/build/wine-x11" \
    "$source/configure" --enable-archs=x86_64 --disable-tests --with-x --with-opengl \
    --without-gstreamer --without-wayland --without-vulkan --without-alsa --without-pulse \
    --without-oss --without-cups --without-sane --without-gphoto --without-v4l2 --without-pcap \
    --without-krb5 --without-netapi --without-usb --without-udev --without-dbus --without-capi \
    --without-sdl --without-unwind --without-inotify --without-gssapi --without-ffmpeg > configure.log 2>&1; then
  tail -n 40 configure.log >&2
  exit 1
fi

# Use the two libraries that will load beside the rebuilt driver. The final
# runner keeps these Soda files, so do not build replacements for them here.
for lib in ntdll win32u; do
  install -D "$base/$lib.so" "dlls/$lib/$lib.so"
done
driver=dlls/winex11.drv/winex11.so
if ! make -j"${JOBS:-$(nproc)}" -o dlls/ntdll/ntdll.so -o dlls/win32u/win32u.so "$driver" > build.log 2>&1; then
  tail -n 60 build.log >&2
  exit 1
fi

required_glibc=$(readelf --version-info "$driver" | sed -n 's/.*Name: GLIBC_\([0-9.]*\) .*/\1/p' | sort -V | tail -n 1)
if [ -z "$required_glibc" ] || [ "$(printf '2.41\n%s\n' "$required_glibc" | sort -V | tail -n 1)" != 2.41 ]; then
  printf 'The X11 driver requires GLIBC_%s. Use a toolchain compatible with Debian 13 (glibc 2.41).\n' "$required_glibc" >&2
  exit 1
fi

install -D -m 755 "$driver" "$project/wine-src/out/x86_64-unix/winex11.so"
printf 'Built winex11.so for x86_64 Unix (GLIBC_%s).\n' "$required_glibc"
