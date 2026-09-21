#!/usr/bin/env bash
# Exercise how `bin/cli.mjs` reads a FLOW file — the half of the config contract that is code.
#     bash script/tests/flow-config.sh
# The case that matters here is the fenced example. These files are prose with keys in them, and
# the rule that decides what a key is knows nothing about triple backticks, so a block written to
# be pasted ("add this to try it once") was live configuration for as long as it sat there. One
# real repo had `agents.exec_cmd` set from the example of a file whose prose argued, at length,
# that it was deliberately unset. `flow tier` is the observer: it prints the resolved ceilings and
# the review depth, so what the parser took is visible without inventing a debug flag for it.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-config-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

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
check "and not the example's"                       "$BASE/fenced.txt" miss '99'
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
check "neither leaks its values"      "$BASE/tildes.txt" miss '77'

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

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "flow-config: all cases pass"; else echo "flow-config: $fails failure(s)"; exit 1; fi
