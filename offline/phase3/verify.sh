#!/usr/bin/env bash
set -euo pipefail

phase3=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
archive=$phase3/line-26.6.0.4004.payload.tar.gz
results=${1:-"$phase3"}

bash "$phase3/../phase2/verify.sh" "$phase3/launch-check.sh" "$results" \
  "$phase3/install-line.sh" "$archive" "$archive.sha256"
