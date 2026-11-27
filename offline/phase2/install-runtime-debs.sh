#!/bin/sh
set -eu
export LC_ALL=C

cd -- "${1:?Usage: install-runtime-debs.sh DEB-DIRECTORY}"
sha256sum --quiet -c SHA256SUMS
if test "$(printf '%s\n' ./*.deb | cut -c3-)" != "$(cut -c67- SHA256SUMS)"; then
  echo 'The directory contains a different set of packages than SHA256SUMS.' >&2
  exit 1
fi

# libexpat1:i386 needs libc6:i386 to be configured before unpacking it.
dpkg --add-architecture i386
dpkg --refuse-downgrade --skip-same-version -i ./gcc-14-base_*_i386.deb ./libgcc-s1_*_i386.deb ./libc6_*_i386.deb
dpkg --refuse-downgrade --skip-same-version -i ./*.deb

audit=$(dpkg --audit)
if test -n "$audit"; then
  printf '%s\n' "$audit" >&2
  exit 1
fi
