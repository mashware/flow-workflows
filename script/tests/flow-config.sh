#!/usr/bin/env bash
# Exercise how `bin/cli.mjs` reads a FLOW file — the half of the config contract that is code.
#     bash script/tests/flow-config.sh
# The case that matters here is the fenced example. These files are prose with keys in them, and
# the rule that decides what a key is knows nothing about triple backticks, so a block written to
# be pasted ("add this to try it once") was live configuration for as long as it sat there. One
# real repo had `agents.exec_cmd` set from the example of a file whose prose argued, at length,
# that it was deliberately unset. `flow tier` is the observer: it prints the resolved ceilings and
# the review depth, so what the parser took is visible without inventing a debug flag for it.
#
# Every pattern below carries its key — `budget_max 99`, never a bare `99`. The first line of that
# output is `Changed lines: … \`<sha>\`..working tree`, and a base commit is made fresh on each run,
# so a bare two-digit pattern also matches the roughly one run in twenty whose short sha happens to
# contain those digits. That is how this file failed on a green tree, with the config read exactly
# right and nothing to find in the diff.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-config-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0
# The context layer is chosen by the environment, so the caller's own must not leak in.
unset FLOW_CONTEXT

g() { git -c user.email=t@t -c user.name=t "$@"; }

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
g checkout -q -b work
printf 'change\n' > churn.txt
g add -A && g commit -qm work >/dev/null

# The real keys come first and the fence last, so every case here fails on a reader that takes
# the example literally — with the order reversed, the real key would simply overwrite it and the
# test would pass against the bug it exists for.
cat > FLOW.md <<'FLOW'
## git
- default_base: main

## agents
- budget_max: 9
- fanout_max: 3

## quality
- review_depth: proportional

To try the one-shot panel once, paste this and take it out again afterwards:

```
## agents
- budget_max: 99
- fanout_max: 99
- exec_cmd: claude -p --model sonnet

## quality
- review_depth: light
```
FLOW
node "$CLI" tier > "$BASE/fenced.txt" 2>&1
check "the ceilings are the ones outside the fence" "$BASE/fenced.txt" hit 'budget_max 9 · fanout_max 3'
check "and not the example's"                       "$BASE/fenced.txt" miss 'budget_max 99'
check "nor its fanout"                              "$BASE/fenced.txt" miss 'fanout_max 99'
check "review_depth too"                            "$BASE/fenced.txt" miss 'Tier: light'

# A fence closed with a longer run, and one opened with tildes: both are fences (CommonMark),
# and a `~~~` block used to be read as config even by a renderer that hid it.
cat > FLOW.md <<'FLOW'
## git
- default_base: main
## agents
- budget_max: 9
- fanout_max: 3
~~~
## agents
- budget_max: 77
~~~
````
## agents
- fanout_max: 77
````
FLOW
node "$CLI" tier > "$BASE/tildes.txt" 2>&1
check "a ~~~ block is a fence"        "$BASE/tildes.txt" hit 'budget_max 9'
check "so is a four-backtick block"   "$BASE/tildes.txt" hit 'fanout_max 3'
check "neither leaks its values"      "$BASE/tildes.txt" miss 'budget_max 77'
check "nor the four-backtick one"     "$BASE/tildes.txt" miss 'fanout_max 77'

# What the fence must not do is swallow the rest of the file: an overlay's keys come after it.
cat > FLOW.md <<'FLOW'
## git
- default_base: main
## agents
```
- budget_max: 55
```
- budget_max: 9
- fanout_max: 3

The keys above are after a closed fence, which is the case a reader gets wrong in the other
direction: swallow the rest of the file and a real key reads as an example.
FLOW
printf '## quality\n- review_depth: full\n' > FLOW.claude.md
node "$CLI" tier --harness claude > "$BASE/after.txt" 2>&1
check "keys after a closed fence still count" "$BASE/after.txt" hit 'budget_max 9'
check "and the overlay is still read"         "$BASE/after.txt" hit 'Tier: full'
check "the pack names both files"             "$BASE/after.txt" hit 'FLOW.md + FLOW.claude.md'

# The context layer: `FLOW_CONTEXT=<name>` adds `FLOW.<name>.md` between the base and the
# overlay. Three different values for one key, so each case says which layer won.
cat > FLOW.md <<'FLOW'
## git
- default_base: main
## agents
- budget_max: 10
- fanout_max: 3
FLOW
printf '## agents\n- budget_max: 30\n' > FLOW.claude.md
printf '## agents\n- budget_max: 20\n' > FLOW.ci.md
node "$CLI" tier > "$BASE/ctx-unset.txt" 2>&1
check "no FLOW_CONTEXT: the context file changes nothing" "$BASE/ctx-unset.txt" hit 'budget_max 10'
check "and the line is today's"  "$BASE/ctx-unset.txt" hit 'Config read: FLOW.md — no `--harness` was given, so FLOW.claude.md went unread$'
check "a context file is never listed as unread" "$BASE/ctx-unset.txt" miss 'FLOW.ci.md'
FLOW_CONTEXT=ci node "$CLI" tier > "$BASE/ctx-set.txt" 2>&1
check "the context replaces the base"  "$BASE/ctx-set.txt" hit 'budget_max 20'
check "and the line names the layer"   "$BASE/ctx-set.txt" hit 'FLOW.md + FLOW.ci.md \[FLOW_CONTEXT=ci\] — no `--harness`'
FLOW_CONTEXT=ci node "$CLI" tier --harness claude > "$BASE/ctx-harness.txt" 2>&1
check "the overlay replaces the context" "$BASE/ctx-harness.txt" hit 'budget_max 30'
check "three layers, in merge order"     "$BASE/ctx-harness.txt" hit 'Config read: FLOW.md + FLOW.ci.md \[FLOW_CONTEXT=ci\] + FLOW.claude.md$'
printf '## agents\n- budget_max:\n' > FLOW.ci.md
FLOW_CONTEXT=ci node "$CLI" tier > "$BASE/ctx-mask.txt" 2>&1
check "an empty context key masks the base" "$BASE/ctx-mask.txt" hit 'budget_max 12'
FLOW_CONTEXT=staging node "$CLI" tier > "$BASE/ctx-missing.txt" 2>&1; echo "exit $?" >> "$BASE/ctx-missing.txt"
check "a missing context file is not an error" "$BASE/ctx-missing.txt" hit 'exit 0'
check "but it is named"                        "$BASE/ctx-missing.txt" hit 'FLOW_CONTEXT=staging: FLOW.staging.md not found'
for bad in claude Claude ../x; do
  FLOW_CONTEXT=$bad node "$CLI" tier > "$BASE/ctx-bad.txt" 2>&1; echo "exit $?" >> "$BASE/ctx-bad.txt"
  check "FLOW_CONTEXT=$bad is skipped, not fatal" "$BASE/ctx-bad.txt" hit 'exit 0'
  check "and named"                               "$BASE/ctx-bad.txt" hit "FLOW_CONTEXT=$bad ignored: a context is a name"
  check "and no overlay is read in its place"     "$BASE/ctx-bad.txt" hit 'budget_max 10'
done

# Each layer is found on its own. A committed context file lives in the worktree; the
# git-ignored base exists only in the main checkout. One root for both missed one of them.
g checkout -q -b ctx
printf '## agents\n- budget_max: 20\n' > FLOW.ci.md
g add FLOW.ci.md && g commit -qm ctx >/dev/null
g checkout -q work
g worktree add -q "$BASE/wt-ctx" ctx
(cd "$BASE/wt-ctx" && FLOW_CONTEXT=ci node "$CLI" tier) > "$BASE/wt-ctx.txt" 2>&1
check "worktree: base from main, context from here" "$BASE/wt-ctx.txt" hit 'budget_max 20'
check "and each file names where it came from"      "$BASE/wt-ctx.txt" hit "FLOW.md (from $BASE/repo) + FLOW.ci.md \[FLOW_CONTEXT=ci\] — "

# Today's silent miss, fixed by the same rule: a committed base and a git-ignored overlay
# that only the main checkout has. The overlay used to go unread from the worktree.
g checkout -q -b committed
g add FLOW.md && g commit -qm committed >/dev/null
g checkout -q work
g worktree add -q "$BASE/wt-committed" committed
(cd "$BASE/wt-committed" && node "$CLI" tier --harness claude) > "$BASE/wt-committed.txt" 2>&1
check "worktree: the main checkout's overlay is read" "$BASE/wt-committed.txt" hit 'budget_max 30'
check "and named with its root" "$BASE/wt-committed.txt" hit "FLOW.md + FLOW.claude.md (from $BASE/repo)"

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "flow-config: all cases pass"; else echo "flow-config: $fails failure(s)"; exit 1; fi
