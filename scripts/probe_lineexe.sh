#!/usr/bin/env bash
# Run LINE.exe in a bottle for N seconds with signature-check tracing, then kill the bottle.
# Prints every file LINE checked (with WinVerifyTrust result) and the failure dialog, if any.
#   bash scripts/probe_lineexe.sh BOTTLE [seconds] [logname]
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
BOTTLE=${1:?bottle}; SECS=${2:-90}; NAME=${3:-probe-$BOTTLE-$(date +%H%M%S)}
RUNNER=${RUNNER:-soda-11.0-10-line}
D=$HOME/.var/app/com.usebottles.bottles/data/bottles; R=$D/runners/$RUNNER
LOG=$HERE/analysis/$NAME.log
USERDIR=$(ls "$D/bottles/$BOTTLE/drive_c/users" | grep -vE '^(Public|steamuser)$' | head -1)
EXE="C:\\users\\$USERDIR\\AppData\\Local\\LINE\\bin\\LineLauncher.exe"
timeout $((SECS + 30)) flatpak run --command=bash com.usebottles.bottles -c \
  "export WINEPREFIX='$D/bottles/$BOTTLE' WINEDEBUG=+wintrust,+msgbox,+process,+loaddll,err,fixme-all; '$R/bin/wine' '$EXE' & sleep $SECS; '$R/bin/wineserver' -k" > "$LOG" 2>&1 || true
echo "log: $LOG"
grep -E 'wintrust:(dump_file_info pcwszFilePath|WinVerifyTrust returning)' "$LOG" \
  | sed -E 's/.*pcwszFilePath: L"(.*)"/\1/; s/.*WinVerifyTrust returning /    -> /' | paste - - | sort | uniq -c
grep -E 'msgbox:MSGBOX_OnInit' "$LOG" | sed -E 's/.*MSGBOX_OnInit L"//' | cut -c1-260 || true
grep -E 'Unhandled|unimplemented function' "$LOG" | cut -c1-200 | sort -u | head -5 || true
