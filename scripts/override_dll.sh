#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: ./scripts/override_dll.sh <dll-name>' \
    'Example: ./scripts/override_dll.sh WINMM.dll' \
    'Default bottle: LINE-repro. Set BOTTLE to select another one.' \
    'Close LINE in the target bottle before running, then open it again.'
}

if [[ $# == 1 && ( $1 == -h || $1 == --help ) ]]; then
  usage
  exit 0
fi
if [[ $# != 1 ]]; then
  usage >&2
  exit 2
fi

dll=${1,,}
dll=${dll%.dll}
if [[ ! $dll =~ ^[a-z0-9_][a-z0-9_-]*$ ]]; then
  printf 'Expected a DLL name without a directory, got %s\n' "$1" >&2
  exit 2
fi

bottle=${BOTTLE:-LINE-repro}
if [[ ! $bottle =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]]; then
  printf 'Invalid bottle name: %s\n' "$bottle" >&2
  exit 2
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
printf 'Installing %s.dll in %s\n' "$dll" "$bottle"
bash "$here/install_ondisk_ms_dlls.sh" "$bottle" "$dll"
printf 'Open LINE in %s again and retry the action that showed the error.\n' "$bottle"
