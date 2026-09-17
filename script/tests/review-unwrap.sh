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

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "review-unwrap: all cases pass"; else echo "review-unwrap: $fails failure(s)"; exit 1; fi
