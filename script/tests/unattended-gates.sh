#!/usr/bin/env bash
# Check that every question an unattended run can stop on has a way back.
#     bash script/tests/unattended-gates.sh
# A gate a command asks with no row in the re-entry table of flow-core §2.1 — or a row that does
# not name that command in "Asked in" — is a question a runner can answer and the run cannot
# apply. Nothing fails loudly then: the answer is rejected on every relaunch.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../plugins/flow"
CORE="$ROOT/skills/flow-core/SKILL.md"
fails=0
ok()   { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }

# Gates a text asks, whatever the line breaks: question `a`, question `a` / `b`, or a known gate
# written as (`a`).
gates_asked() {  # <file> [known gates, |-separated]
  local known="${2:-migration}"
  tr '\n' ' ' < "$1" | tr -s ' ' \
    | grep -oE "question \`[a-z_]+\`( / \`[a-z_]+\`)?|\(\`($known)\`\)" \
    | grep -oE '`[a-z_]+`' | tr -d '`' | sort -u
}
# The stop-site table of flow-core §2.1 (header "| Where | In `unattended` |"), as a file.
site_table() {
  awk '/^\| Where \| In `unattended` \|/{t=1; next} t && /^\|/{print; next} t{exit}' "$CORE"
}
# Rows of the re-entry table (the one whose header names `resume_at`): "<gate>|<asked in>".
rows() {
  awk '/^\| Gate \| Asked in \| `resume` \| `resume_at`/{t=1; next} t && /^\|---/{next} t && /^\|/{print; next} t{exit}' "$CORE" \
    | awk -F'|' '{g=$2; gsub(/[ `]/,"",g); print g "|" $3}'
}

table=$(rows)
[ -n "$table" ] || { fail "no re-entry table in flow-core §2.1"; exit 1; }
SITES="${TMPDIR:-/tmp}/flow-unattended-sites.$$"; site_table > "$SITES"; trap 'rm -f "$SITES"' EXIT
[ -s "$SITES" ] || { fail "no stop-site table in flow-core §2.1"; exit 1; }
core_gates=$(gates_asked "$SITES")
known=$(printf '%s\n' $core_gates | paste -sd'|')

# Each command's gates: a row for that gate must name the command's phase, or "any phase".
while IFS= read -r f; do
  phase=$(basename "$f" .md)
  for g in $(gates_asked "$f" "$known"); do
    if printf '%s\n' "$table" | awk -F'|' -v g="$g" -v p="$phase" \
         '$1==g && ($2 ~ "`" p "`" || $2 ~ /any phase/) {hit=1} END{exit !hit}'; then
      ok "$phase asks $g — re-entry row names it"
    else
      fail "$phase asks $g — no re-entry row names \`$phase\` in Asked in"
    fi
  done
done < <(find "$ROOT/commands" -name '*.md' | sort)

# The stop-site table and the re-entry table name the same gates.
row_gates=$(printf '%s\n' "$table" | cut -d'|' -f1 | sort -u)
for g in $core_gates; do printf '%s\n' "$row_gates" | grep -qx "$g" && ok "flow-core gate $g has a row" || fail "flow-core gate $g has no re-entry row"; done
for g in $row_gates; do printf '%s\n' "$core_gates" | grep -qx "$g" || fail "re-entry row $g is not a gate of the stop-site table"; done

[ "$fails" -eq 0 ] && echo "unattended gates: ok" || { echo "unattended gates: $fails failure(s)"; exit 1; }
