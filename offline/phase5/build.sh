#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

phase5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
offline=$(dirname -- "$phase5")
version=26.6.0.4004
runner=soda-11.0-10-line.runtime.tar.gz
app=line-$version.payload.tar.gz
filename=LINE-offline-$version-linux-x86_64.run

(cd "$offline/phase2" && sha256sum --quiet -c "$runner.sha256")
(cd "$offline/phase3" && sha256sum --quiet -c "$app.sha256")
(
  cd "$offline/phase2/runtime-debs"
  sha256sum --quiet -c SHA256SUMS
  diff -u <(cut -c67- SHA256SUMS) <(printf '%s\n' *.deb)
)

work=$(mktemp -d "$phase5/.build.XXXXXXXX")
trap 'rm -r -- "$work"' EXIT

tar --format=gnu --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
  --mode='u=rwX,go=rX' -cf "$work/payload.tar" \
  -C "$offline/phase2" "$runner" "$runner.sha256" runtime-debs install-runtime-debs.sh \
  -C "$offline/phase3" "$app" "$app.sha256" install-line.sh \
  -C "$phase5" line-offline

payload_digest=$(sha256sum "$work/payload.tar" | cut -d ' ' -f 1)
sed -e "s/@LINE_VERSION@/$version/" -e "s/@PAYLOAD_SHA256@/$payload_digest/" \
  "$phase5/installer.sh.in" > "$work/$filename"
cat "$work/payload.tar" >> "$work/$filename"
chmod 755 "$work/$filename"
(cd "$work" && sha256sum "$filename" > "$filename.sha256")
mv -T -- "$work/$filename" "$phase5/$filename"
mv -T -- "$work/$filename.sha256" "$phase5/$filename.sha256"
printf '%s\n' "$phase5/$filename"
