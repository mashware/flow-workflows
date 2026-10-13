#!/usr/bin/env bash
# Check that a study's dependencies on other tickets are detected, recorded and read back.
#     bash script/tests/ticket-deps.sh
# The orchestrator side (the `--depends-on` flag on `done`) is pinned in unattended-gates.sh; this
# file pins the attended half: where the study detects a dependency, where it records it, and how
# handoff writes it into the ticket. Each piece missing is a study whose builder is never told.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../plugins/flow"
fails=0
ok()   { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
line_of() { grep -n -m1 -F -- "$2" "$1" | cut -d: -f1; }

design="$ROOT/commands/feat/design.md"
investigate="$ROOT/commands/bug/investigate.md"

# Detection happens before the challenger, so the challenger reads it.
d_rule=$(line_of "$design" '### 5.1 Tickets this design depends on')
d_chal=$(line_of "$design" '## 6. Design challenge (challenger)')
[ -n "$d_rule" ] && [ -n "$d_chal" ] && [ "$d_rule" -lt "$d_chal" ] \
  && ok "design detects dependencies before its challenger" \
  || fail "design has no dependency step before its challenger"
i_rule=$(line_of "$investigate" '### 4.1 Tickets this fix depends on')
i_chal=$(line_of "$investigate" '## 5. Root cause challenge (challenger)')
[ -n "$i_rule" ] && [ -n "$i_chal" ] && [ "$i_rule" -lt "$i_chal" ] \
  && ok "investigate detects dependencies before its challenger" \
  || fail "investigate has no dependency step before its challenger"

# The artifact section exists in both templates, with the either-order exclusion.
for f in "$design" "$investigate"; do
  grep -q '^## Depends on other tickets$' "$f" \
    && ok "$(basename "$f")'s template has ## Depends on other tickets" \
    || fail "$(basename "$f")'s template has no ## Depends on other tickets"
done
d=$(flat "$design")
printf '%s' "$d" | grep -q 'Not dependencies (either order works)' \
  && printf '%s' "$d" | grep -q 'not on the base this work builds from' \
  && printf '%s' "$d" | grep -q '`meta.json.ticket_deps`' \
  && ok "the rule names the base, the either-order exclusion and ticket_deps" \
  || fail "the dependency rule lost the base, the either-order exclusion or ticket_deps"

# plan never writes another ticket into its own MR/PR ordering.
flat "$ROOT/commands/feat/plan.md" | grep -q 'Another ticket is not a `depends_on`.* append it to `meta.json.ticket_deps`' \
  && ok "plan sends another ticket to ticket_deps, not mrs[].depends_on" \
  || fail "plan does not keep other tickets out of mrs[].depends_on"

# handoff writes the line outside the markers, skips one already there, and never removes one.
h=$(flat "$ROOT/commands/work/handoff.md")
printf '%s' "$h" | grep -q 'whose line is not already a line of that body' \
  && printf '%s' "$h" | grep -q 'one line after the end marker, in `ticket_deps` order' \
  && printf '%s' "$h" | grep -qF 'Depends on #253' \
  && printf '%s' "$h" | grep -q 'never removed' \
  && ok "handoff appends missing Depends on lines after the block and never removes one" \
  || fail "handoff's Depends on rule is incomplete"

# The study's reasons reach the person approving it.
printf '%s' "$h" | grep -q '`## Design in brief` ends with each `meta.json.ticket_deps`' \
  && ok "the flow-study block lists each dependency with its why" \
  || fail "the flow-study block does not list the dependencies"

# Ticket text never reaches the orchestrator's command line unchecked: the pattern is stated where
# the order is built, and a leading '-' cannot pass it.
core="$ROOT/skills/flow-core/SKILL.md"
for f in "$core" "$ROOT/commands/feat/build.md" "$ROOT/commands/bug/fix.md"; do
  grep -qF '[A-Za-z0-9][A-Za-z0-9._-]*' "$f" \
    && ok "$(basename "$(dirname "$f")")/$(basename "$f") checks N before it goes on a command line" \
    || fail "$(basename "$(dirname "$f")")/$(basename "$f") does not check N"
done
grep -q "^| An approved study's branch (\`run\`" "$core" \
  && ok "flow-core's stop-site table has a row for the approved study's fast-forward" \
  || fail "flow-core has no stop-site row for the approved study's fast-forward"
flat "$ROOT/commands/work/run.md" | grep -q 'only while no build or fix has begun' \
  && ok "the fast-forward stops once a build or fix has begun" \
  || fail "the fast-forward is not limited to an approved study"

[ "$fails" -eq 0 ] && echo "ticket-deps: all cases pass" || { echo "ticket-deps: $fails failure(s)"; exit 1; }
