#!/usr/bin/env bash
# Check that every question an unattended run can stop on has a way back.
#     bash script/tests/unattended-gates.sh
# A gate a command names, or the stop-site table lists, with no row in the re-entry table of
# flow-core §2.1 is a question a runner can answer and the run cannot apply. Nothing fails
# loudly then: the run simply stops on the same question again.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../plugins/flow"
CORE="$ROOT/skills/flow-core/SKILL.md"
fails=0

gates_named() {  # every gate written as question `<gate>` (and `a` / `b`) in the given files
  grep -oh 'question `[a-z_]*`\( / `[a-z_]*`\)\?' "$@" | grep -o '`[a-z_]*`' | tr -d '`' | sort -u
}
reentry_gates() {  # first column of the re-entry table (the one whose header names `resume_at`)
  awk '/^\| Gate \| Asked in \| `resume` \| `resume_at`/{t=1; next} t && /^\|---/{next} t && /^\|/{print; next} t{exit}' "$CORE" \
    | cut -d'|' -f2 | grep -o '`[a-z_]*`' | tr -d '`' | sort -u
}

reentry=$(reentry_gates)
if [ -z "$reentry" ]; then echo "  FAIL no re-entry table found in flow-core §2.1"; exit 1; fi

check_subset() {  # <label> <gates>
  local g
  for g in $2; do
    if printf '%s\n' "$reentry" | grep -qx "$g"; then printf '  ok   %s: %s has a re-entry row\n' "$1" "$g"
    else printf '  FAIL %s: %s has no re-entry row\n' "$1" "$g"; fails=$((fails+1)); fi
  done
}

check_subset "flow-core" "$(gates_named "$CORE")"
check_subset "commands" "$(gates_named $(find "$ROOT/commands" -name '*.md'))"

# The other direction: a re-entry row for a gate nothing asks is a row nobody maintains.
core_gates=$(gates_named "$CORE")
for g in $reentry; do
  if printf '%s\n' "$core_gates" | grep -qx "$g"; then :
  else printf '  FAIL re-entry row %s is not a gate of the stop-site table\n' "$g"; fails=$((fails+1)); fi
done

[ "$fails" -eq 0 ] && echo "unattended gates: ok" || { echo "unattended gates: $fails failure(s)"; exit 1; }
