#!/usr/bin/env bash
# Exercise `flow tier` — the arithmetic §2.0 of feat/review.md used to address to a model.
#     bash script/tests/tier.sh
# What this pins is not the table; it is that the table is now *checkable*. The old section
# recorded "Review tier: … per §2.0" in 06-review.md, which is the tier the agent said it
# derived: a round that eyeballed the diff and a round that measured it wrote a byte-identical
# artifact, on the one number the section itself says carries an incentive.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-tier-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

g() { git -c user.email=t@t -c user.name=t "$@"; }
lines() { python3 -c "import sys; print('l\n' * int(sys.argv[1]), end='')" "$1"; }

check() {  # <label> <file> <expected: hit|miss> <pattern>
  local out; out=$(cat "$2")
  if printf '%s' "$out" | grep -q -- "$4"; then found=hit; else found=miss; fi
  if [ "$found" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — wanted %s for %q\n' "$1" "$3" "$4"; fails=$((fails+1)); fi
}

cd "$BASE/repo" || exit 1
g init -q -b main .
printf 'seed\n' > seed.txt
g add -A && g commit -qm base >/dev/null

cat > FLOW.md <<'EOF'
## git
- default_base: main
## quality
- sensitive_paths:
  - 'src/**/Payment/**'
  - '*.sql'
## agents
- budget_max: 9
- fanout_max: 3
EOF
g add -A && g commit -qm config >/dev/null

# Each case is a branch with a known line count, so the boundary rows of the table are the
# cases and not an average of them. 150/151 and 600/601 are where the tier actually turns.
case_at() {  # <branch> <lines>
  g checkout -q main
  g checkout -q -b "$1"
  lines "$2" > churn.txt
  g add -A && g commit -qm "$1" >/dev/null
  node "$CLI" tier > "$BASE/$1.txt" 2>&1
}

case_at xs-edge 150
check "150 lines is XS"                    "$BASE/xs-edge.txt" hit 'Diff size: XS'
check "and XS runs the built-in at medium" "$BASE/xs-edge.txt" hit 'built-in at .medium., panel: no'
check "150 is within 10% under 150"        "$BASE/xs-edge.txt" hit 'Within 10% under 150: yes'

case_at s-edge 151
check "151 lines is S"                     "$BASE/s-edge.txt" hit 'Diff size: S'
check "and S is high, panel only if sensitive" "$BASE/s-edge.txt" hit 'built-in at .high., panel: only on a sensitive surface'
check "151 is not within 10% under"        "$BASE/s-edge.txt" hit 'Within 10% under a threshold: no'

case_at m-edge 601
check "601 lines is M"                     "$BASE/m-edge.txt" hit 'Diff size: M'
check "and M always runs the panel"        "$BASE/m-edge.txt" hit 'built-in at .high., panel: yes'

case_at l-edge 1501
check "1501 lines is L"                    "$BASE/l-edge.txt" hit 'Diff size: L'
check "and L is xhigh"                     "$BASE/l-edge.txt" hit 'built-in at .xhigh., panel: yes'
check "the bump takes L to max"            "$BASE/l-edge.txt" hit 'bump: built-in at .max.'

# The effective size is the LOWER of the recorded size and the diff — the failure §2.0 names
# as the single largest source of wasted review: a 41-line MR/PR in an L feature inherits the
# L and is reviewed as one.
g checkout -q main && g checkout -q -b small-in-big
mkdir -p .claude/work/TICKET-1
printf '{"ticket":"TICKET-1","size":"L","branch":"small-in-big"}\n' > .claude/work/TICKET-1/meta.json
lines 40 > churn.txt
g add -A && g commit -qm small >/dev/null
node "$CLI" tier > "$BASE/small-in-big.txt" 2>&1
check "a small diff in an L work reads L"   "$BASE/small-in-big.txt" hit 'meta.json.size: L'
check "and is reviewed as the lower of two" "$BASE/small-in-big.txt" hit 'Effective size: XS'

# The other direction is a note, never a heavier review.
g checkout -q main && g checkout -q -b big-in-small
mkdir -p .claude/work/TICKET-2
printf '{"ticket":"TICKET-2","size":"XS","branch":"big-in-small"}\n' > .claude/work/TICKET-2/meta.json
lines 900 > churn.txt
g add -A && g commit -qm big >/dev/null
node "$CLI" tier > "$BASE/big-in-small.txt" 2>&1
check "a diff pointing higher stays at XS"  "$BASE/big-in-small.txt" hit 'Effective size: XS'
check "and says the work may be misclassified" "$BASE/big-in-small.txt" hit 'may be misclassified'

# The sensitive list is the repo's, and the CLI reads it rather than carrying its own idea of
# what is sensitive. What it must NOT do is decide the bump: control flow versus a log level is
# the judgement the section keeps.
g checkout -q main && g checkout -q -b sensitive
mkdir -p src/Billing/Payment
printf 'charge\n' > src/Billing/Payment/Charge.php
printf 'ALTER TABLE t ADD c INT;\n' > migrate.sql
g add -A && g commit -qm sensitive >/dev/null
node "$CLI" tier > "$BASE/sensitive.txt" 2>&1
check "a configured glob is matched"        "$BASE/sensitive.txt" hit 'src/Billing/Payment/Charge.php (src/\*\*/Payment/\*\*)'
check "a second glob matches too"           "$BASE/sensitive.txt" hit 'migrate.sql (\*.sql)'
check "the bump is offered, not applied"    "$BASE/sensitive.txt" hit 'Left to you'

# The budget is read from the same config as everything else, so the round and the tier cannot
# disagree about what the ceiling is.
check "budget_max comes from FLOW.md"       "$BASE/sensitive.txt" hit 'budget_max 9'
check "and so does fanout_max"              "$BASE/sensitive.txt" hit 'fanout_max 3'

# review_depth short-circuits the ladder in both directions, and the sensitive surface is the
# one thing `light` cannot scale away.
printf '## quality\n- review_depth: full\n' > FLOW.claude.md
node "$CLI" tier --harness claude > "$BASE/full.txt" 2>&1
check "full ignores the size ladder"        "$BASE/full.txt" hit 'Tier: full'
printf '## quality\n- review_depth: light\n' > FLOW.claude.md
node "$CLI" tier --harness claude > "$BASE/light.txt" 2>&1
check "light says what it drops"            "$BASE/light.txt" hit 'no panel, no §3, no §6'
check "and that a sensitive surface lifts it" "$BASE/light.txt" hit 'raises it to proportional'
rm -f FLOW.claude.md

# --rev is what makes the tier belong to the same revision the reviewers read. Measuring the
# live tree while the pack was frozen is two numbers about two trees.
g checkout -q main && g checkout -q -b frozen
lines 40 > churn.txt
g add -A && g commit -qm frozen >/dev/null
FROZEN=$(g rev-parse HEAD)
lines 900 > churn.txt                                   # the round's own fixes, uncommitted
node "$CLI" tier > "$BASE/tier-live.txt" 2>&1
node "$CLI" tier --rev "$FROZEN" > "$BASE/tier-frozen.txt" 2>&1
check "without --rev the tier reads the tree" "$BASE/tier-live.txt"   hit 'Diff size: M'
check "with --rev it reads the candidate"     "$BASE/tier-frozen.txt" hit 'Diff size: XS'
g checkout -q -- churn.txt

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "tier: all cases pass"; else echo "tier: $fails failure(s)"; exit 1; fi
