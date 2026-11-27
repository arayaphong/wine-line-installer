#!/usr/bin/env bash
# Export the committed project source. See README.md for the local build inputs.
# Usage: bash scripts/make_handoff_bundle.sh [out.tar.zst]
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
archive_path=${1:-$project_dir/line-installer-source.tar.zst}
temp_archive=$(mktemp -- "$archive_path.XXXXXX")
trap 'rm -f -- "$temp_archive"' EXIT

git -C "$project_dir" archive --format=tar --prefix="$(basename -- "$project_dir")/" HEAD |
  zstd -q -c > "$temp_archive"
mv -T -- "$temp_archive" "$archive_path"
sha256sum -- "$archive_path"
