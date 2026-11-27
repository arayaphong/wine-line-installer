#!/usr/bin/env bash
# Run from your terminal to apply the tested REA provider settings to Codex.
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_path=${1:-"$HOME/.codex/config.toml"}
ghidra_dir="$project_dir/tools/ghidra-12.1.2"
java_dir=/usr/lib/jvm/java-27-openjdk

[[ -f "$config_path" ]] || { echo "Missing config: $config_path" >&2; exit 1; }
[[ -x "$ghidra_dir/support/analyzeHeadless" && -x "$java_dir/bin/javac" ]] || {
    echo 'Missing Ghidra or JDK.' >&2; exit 1;
}
if ! awk '
    /^[[:space:]]*\[/ { active = ($0 ~ /^[[:space:]]*\[mcp_servers\.rea\.env\][[:space:]]*$/) }
    active && /^[[:space:]]*GHIDRA_INSTALL_DIR[[:space:]]*=/ { ghidra++ }
    active && /^[[:space:]]*JAVA_HOME[[:space:]]*=/ { java++ }
    END { exit !(ghidra == 1 && java == 1) }
' "$config_path"; then
    echo 'Expected exactly one GHIDRA_INSTALL_DIR and JAVA_HOME in [mcp_servers.rea.env]; no changes made.' >&2
    exit 1
fi

temp_path=$(mktemp "${config_path}.rea.XXXXXX")
trap 'rm -f -- "$temp_path"' EXIT
chmod --reference="$config_path" "$temp_path"
awk -v ghidra="$ghidra_dir" -v java="$java_dir" '
    /^[[:space:]]*\[/ { active = ($0 ~ /^[[:space:]]*\[mcp_servers\.rea\.env\][[:space:]]*$/) }
    active && /^[[:space:]]*GHIDRA_INSTALL_DIR[[:space:]]*=/ {
        print "GHIDRA_INSTALL_DIR = \"" ghidra "\""; next
    }
    active && /^[[:space:]]*JAVA_HOME[[:space:]]*=/ {
        print "JAVA_HOME = \"" java "\""; next
    }
    { print }
' "$config_path" > "$temp_path"
if cmp -s -- "$config_path" "$temp_path"; then
    echo 'REA provider settings are already correct.'
    exit 0
fi
backup_path=$(mktemp "${config_path}.before-rea.XXXXXX")
cp -p -- "$config_path" "$backup_path"
mv -- "$temp_path" "$config_path"
echo "Updated: $config_path"
echo "Backup: $backup_path"
echo 'Restart Codex (or reconnect the REA MCP server) to load the new settings.'
