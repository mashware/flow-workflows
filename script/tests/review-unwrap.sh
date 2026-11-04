#!/usr/bin/env bash
# Exercise `flow review` against the answer shapes a harness actually returns.
#     bash script/tests/review-unwrap.sh
# The bug this pins: a harness with a structured-output flag wraps the answer in an
# envelope, `findings` is not at the root, and every role resolved to "nothing usable"
# while the command exited 0 — a full panel reporting a clean diff. Cases: findings at the
# root · in `structured_output` · as a JSON string in `result` · cost carried by the
# envelope · a command that reads no stdin · unparseable output · `{SCHEMA}` in single
# quotes · an empty `exec_cmd`.
set -u
# The context layer is chosen by the environment; a caller that exports FLOW_CONTEXT must not
# change what these cases read.
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-review-unwrap-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

cd "$BASE/repo" || exit 1
git init -q -b main .
printf 'one\n' > a.txt
git add -A && git -c user.email=t@t -c user.name=t commit -qm base >/dev/null
git checkout -q -b feature
printf 'two\n' >> a.txt
git add -A && git -c user.email=t@t -c user.name=t commit -qm change >/dev/null

flow_md() {  # <exec_cmd line>
  cat > FLOW.md <<EOF
## git
- default_base: main

## quality
- reviewers:
  - correctness: logic that does not do what the change claims

## agents
- exec_cmd: $1
EOF
}

answer() { printf '%s' "$1" > "$BASE/answer.json"; }
FINDING='{"file":"a.txt","line":2,"severity":"blocker","what":"the thing","fix":"do the other thing"}'

check() {  # <label> <expected-rc> <grep-pattern>
  local out rc
  out=$(node "$CLI" review 2>&1); rc=$?
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -q "$3"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       rc=%s (want %s), no match for %q in:\n%s\n' "$1" "$rc" "$2" "$3" "$out"; fails=$((fails+1)); fi
}

# The command reads the brief and answers from a file: one shape per case, same command.
flow_md "cat >/dev/null; cat $BASE/answer.json"

answer "{\"findings\":[$FINDING],\"total_cost_usd\":0.5}"
check "findings at the root"                     0 '1 finding(s) from 1 reviewer(s)'
check "cost at the root"                         0 'Reported by the harness: \$0.5000'

answer "{\"type\":\"result\",\"total_cost_usd\":0.25,\"structured_output\":{\"findings\":[$FINDING]}}"
check "findings under structured_output"         0 '1 finding(s) from 1 reviewer(s)'
check "cost from the envelope, not the inner"    0 'Reported by the harness: \$0.2500'

# The envelope this bug was found in: the answer is a JSON *string* under `result`.
answer '{"type":"result","total_cost_usd":0.125,"result":"{\"findings\":[{\"file\":\"a.txt\",\"line\":2,\"severity\":\"blocker\",\"what\":\"the thing\",\"fix\":\"do the other thing\"}]}"}'
check "findings as a JSON string in result"      0 '1 finding(s) from 1 reviewer(s)'
check "cost alongside the result string"         0 'Reported by the harness: \$0.1250'

# A command that never reads the brief closes the pipe: judged on its output, not a crash.
answer "{\"findings\":[$FINDING]}"
flow_md "cat $BASE/answer.json"
check "a command that reads no stdin"            0 '1 finding(s) from 1 reviewer(s)'

flow_md "cat >/dev/null; printf 'I had a think about it and found nothing.'"
check "no JSON at all is reported, not silent"   0 'Reviewers that returned nothing usable'

flow_md "cat >/dev/null; printf '{\"findings\":[]}' # '{SCHEMA}'"
check "{SCHEMA} in single quotes stops the run"  1 'single quotes'

flow_md ""
check "empty exec_cmd sends the round back"      1 'is empty in FLOW.md'

# Where a finding came from. Two reviewers raising the same one and one reviewer raising it
# alone say opposite things about that reviewer, and both used to be written identically:
# `raised by 2 reviewers`, with no way to ask which two.
cat > FLOW.md <<EOF
## git
- default_base: main

## quality
- reviewers:
  - security: auth and secrets
  - performance: queries and loops

## agents
- exec_cmd: cat >/dev/null; cat $BASE/answer.json
EOF
mkdir -p .claude/work/T-9
printf '{"ticket":"T-9","branch":"feature"}\n' > .claude/work/T-9/meta.json
answer "{\"findings\":[$FINDING]}"                    # both roles return the same finding
node "$CLI" review --record > "$BASE/out.txt" 2>&1
check "every source is named, not counted"       0 'raised by: security, performance'
meta=$(node -e "console.log(JSON.stringify(require('$BASE/repo/.claude/work/T-9/meta.json')))")
# One finding both roles raised is one row naming both, never two rows that look unique.
want_row='"review_findings":[{"round":1,"sources":["panel:security","panel:performance"],"severity":"blocker","file":"a.txt","outcome":"open"}]'
if printf '%s' "$meta" | grep -qF "$want_row"; then
  printf '  ok   --record writes one row per finding, every source on it\n'
else
  printf '  FAIL --record writes one row per finding — got %s\n' "$meta"; fails=$((fails+1))
fi
if printf '%s' "$meta" | grep -qF '"agents":{"panel:security":1,"panel:performance":1},"reviewers":2'; then
  printf '  ok   --record writes what the round launched\n'
else
  printf '  FAIL --record writes what the round launched — got %s\n' "$meta"; fails=$((fails+1))
fi

# And `flow yield` has to be able to answer the question the rows exist for: what did each
# pass contribute that nothing else did. A finding both roles raised is unique to neither.
in_yield() {  # <label> <grep-pattern>
  if grep -qF -- "$2" "$BASE/yield.txt"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — no match for %q in flow yield\n' "$1" "$2"; fails=$((fails+1)); fi
}
node "$CLI" yield > "$BASE/yield.txt" 2>&1
in_yield "yield reads the rows --record wrote"       '| panel:security | 1 | 1 | 0 | 0 |'
in_yield "and a shared finding is unique to neither" '| panel:performance | 1 | 1 | 0 | 0 |'
if node "$CLI" cost 2>&1 | grep -q 'Findings by origin'; then
  printf '  FAIL cost no longer breaks findings down by origin\n'; fails=$((fails+1))
else printf '  ok   cost is about spend only\n'; fi
# A harness answer the writer would refuse — a severity outside the four, a role whose name
# slugs to nothing — is normalised, and the review itself is printed whatever --record does.
cat > FLOW.md <<'EOF'
## git
- default_base: main

## quality
- reviewers:
  - —: a role whose name has no letters

## agents
- exec_cmd: cat answer.json
EOF
printf '{"findings":[{"file":"a.txt","line":1,"severity":"high","what":"odd","fix":"even"}]}' > answer.json
rm -f .claude/work/T-9/meta.json; printf '{"ticket":"T-9","branch":"feature"}\n' > .claude/work/T-9/meta.json
node "$CLI" review --record > "$BASE/out.txt" 2>&1
check "the review is printed before recording"   0 '1 finding(s) from 1 reviewer(s)'
if grep -qF '"sources":["panel:role-1"],"severity":"unrated"' <(node -e "console.log(JSON.stringify(require('$BASE/repo/.claude/work/T-9/meta.json')))"); then
  printf '  ok   an unknown severity and an empty slug are normalised\n'
else printf '  FAIL an unknown severity and an empty slug are normalised — got %s\n' "$(cat .claude/work/T-9/meta.json)"; fails=$((fails+1)); fi

# A finding with no file becomes `?`; two roles that slug alike are one origin with two
# agents; a work whose meta.json is gone is said, and the review is still printed.
cat > FLOW.md <<'EOF'
## git
- default_base: main

## quality
- reviewers:
  - Data access: one
  - data-access: two

## agents
- exec_cmd: cat answer.json
EOF
printf '{"findings":[{"what":"no file","fix":"x"}]}' > answer.json
printf '{"ticket":"T-9","branch":"feature"}\n' > .claude/work/T-9/meta.json
node "$CLI" review --record > "$BASE/out.txt" 2>&1
meta=$(node -e "console.log(JSON.stringify(require('$BASE/repo/.claude/work/T-9/meta.json')))")
if printf '%s' "$meta" | grep -qF '"sources":["panel:data-access"],"severity":"unrated","file":"?"' && printf '%s' "$meta" | grep -qF '"agents":{"panel:data-access":2},"reviewers":2'; then
  printf '  ok   no file becomes ?, alike slugs sum their agents\n'
else printf '  FAIL no file becomes ?, alike slugs sum their agents — got %s\n' "$meta"; fails=$((fails+1)); fi
rm .claude/work/T-9/meta.json
out=$(node "$CLI" review --record 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF 'missing or not JSON — the review above stands' && printf '%s' "$out" | grep -qF '1 finding(s) from 2 reviewer(s)'; then
  printf '  ok   a missing meta.json is said, and the review is still printed\n'
else printf '  FAIL a missing meta.json is said, and the review is still printed — rc=%s:\n%s\n' "$rc" "$out"; fails=$((fails+1)); fi

rm -rf .claude

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "review-unwrap: all cases pass"; else echo "review-unwrap: $fails failure(s)"; exit 1; fi
