#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-$project_dir/tools/ghidra-12.1.2}"
export REA_JAVA_HOME="${REA_JAVA_HOME:-/usr/lib/jvm/java-27-openjdk}"
export JAVA_HOME="$REA_JAVA_HOME"

if [[ ! -x "$GHIDRA_INSTALL_DIR/support/analyzeHeadless" ]]; then
    echo "Missing Ghidra: $GHIDRA_INSTALL_DIR" >&2
    exit 1
fi

rea_bin=${REA_BIN:-$(command -v rea || true)}
rea_bin=${rea_bin:-$HOME/.local/bin/rea}
if [[ ! -x "$rea_bin" || "$rea_bin" -ef "${BASH_SOURCE[0]}" ]]; then
    echo 'Set REA_BIN to the path to the REA executable.' >&2
    exit 1
fi
exec "$rea_bin" "$@"
