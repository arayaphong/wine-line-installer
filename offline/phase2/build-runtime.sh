#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

phase2=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project=$(cd -- "$phase2/../.." && pwd)
base=soda-11.0-10
runner=$base-line
runtime=$runner.runtime.tar.gz

if [ "$#" -ne 1 ]; then
  echo 'Usage: build-runtime.sh PATH/TO/soda-11.0-10-x86_64.tar.xz' >&2
  exit 2
fi
base_archive=$1
base_digest=$(cut -d ' ' -f 1 "$phase2/$base-x86_64.tar.xz.sha256")
actual=$(sha256sum < "$base_archive")
if [ "${actual%% *}" != "$base_digest" ]; then
  echo 'The Soda base archive checksum differs from the pinned x86_64 release.' >&2
  exit 1
fi

work=$(mktemp -d "$phase2/.build.XXXXXXXX")
trap 'rm -r -- "$work"' EXIT
mkdir "$work/$base"
tar -xJf "$base_archive" --strip-components=1 -C "$work/$base"
test -x "$work/$base/bin/wine"

bash "$project/scripts/build_wine_dlls.sh"
bash "$project/scripts/build_wine_x11_driver.sh" "$work/$base" "$work/x11-build"
LINE_RUNNERS_DIR="$work" LINE_WITH_WINEX11=1 bash "$project/scripts/build_line_runner.sh"

mv -T -- "$work/$runner" "$work/wine"
tar --format=gnu --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  -cf - -C "$work" wine | gzip -n > "$work/$runtime"
(cd "$work" && sha256sum "$runtime" > "$runtime.sha256")
mv -T -- "$work/$runtime" "$phase2/$runtime"
mv -T -- "$work/$runtime.sha256" "$phase2/$runtime.sha256"
printf '%s\n' "$phase2/$runtime"
