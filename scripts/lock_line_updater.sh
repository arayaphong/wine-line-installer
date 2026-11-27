#!/usr/bin/env bash
# chmod 000 every LineUpdater.exe of LINE in a bottle, so LINE's "Restore binary" / auto-update
# can't re-download and overwrite LINE's files. "unlock" restores 755.
#   bash scripts/lock_line_updater.sh BOTTLE [unlock]
set -euo pipefail
BOTTLE=${1:?bottle}; MODE=${2:-lock}
B=$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$BOTTLE/drive_c/users
perm=000; [ "$MODE" = unlock ] && perm=755
found=0
while IFS= read -r -d '' f; do chmod "$perm" "$f"; ls -l "$f"; found=1; done \
  < <(find "$B" -path '*AppData/Local/LINE/bin*' -iname 'LineUpdater*.exe' -print0 2>/dev/null)
[ "$found" = 1 ] || echo "no LineUpdater.exe found (LINE not installed yet?)"
