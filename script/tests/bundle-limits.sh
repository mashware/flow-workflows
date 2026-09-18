#!/usr/bin/env bash
# Exercise `flow bundle` against the two things a pack has to get right about size.
#     bash script/tests/bundle-limits.sh
# The bugs this pins, both found by a real review round on a real repo:
#   1. One size rule governed the contents AND the diff, so a large file with a small
#      change lost its diff — 430 of 541 insertions gone from a pack that exited 0, and
#      the worklist agreed with the reduced view.
#   2. `FLOW.md` was read from the directory the command ran in. Every phase after `start`
#      runs in a worktree, a git-ignored config exists only in the main checkout, and the
#      pack came back with every key resolved to its fallback and nothing saying so.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-bundle-limits-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

g() { git -c user.email=t@t -c user.name=t "$@"; }

cd "$BASE/repo" || exit 1
g init -q -b main .
# A file far over --max-file-bytes whose change is two lines: the case the old rule dropped.
python3 -c "print('x = 1\n' * 40000, end='')" > big.py
printf 'one\n' > small.txt
printf 'lock\n' > deps.lock
g add -A && g commit -qm base >/dev/null

cat > FLOW.md <<'EOF'
## git
- default_base: main
- diff_exclude:
  - 'deps.lock'
EOF
g add FLOW.md && g commit -qm config >/dev/null

g checkout -q -b feature
printf 'x = 2\n' >> big.py
printf 'two\n' >> small.txt
printf 'changed\n' >> deps.lock
python3 -c "print('y = 1\n' * 3000, end='')" > churn.py    # diff over --max-diff-lines
g add -A && g commit -qm change >/dev/null

check() {  # <label> <file> <expected: hit|miss> <pattern>
  local out; out=$(cat "$2")
  if printf '%s' "$out" | grep -q -- "$4"; then found=hit; else found=miss; fi
  if [ "$found" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — wanted %s for %q\n' "$1" "$3" "$4"; fails=$((fails+1)); fi
}

node "$CLI" bundle > "$BASE/pack.txt" 2>&1
check "a large file keeps its diff"            "$BASE/pack.txt" hit  '^diff --git a/big.py'
check "and is still out of the contents"       "$BASE/pack.txt" hit  'big.py — .* over --max-file-bytes'
check "the small file is carried in full"      "$BASE/pack.txt" hit  '^### small.txt'
check "git.diff_exclude still applies"         "$BASE/pack.txt" miss '^diff --git a/deps.lock'
check "a huge diff is held back"               "$BASE/pack.txt" miss '^diff --git a/churn.py'
check "and named in the worklist, not the end" "$BASE/pack.txt" hit  'Not in the diff below'
# The worklist counts the whole change: 3 files (deps.lock is excluded by config, not by size).
check "the worklist shows every changed file"  "$BASE/pack.txt" hit  '3 files changed'

# The config lives in the main checkout only; the phase runs in a worktree.
g update-index --skip-worktree FLOW.md 2>/dev/null
g worktree add -q --detach "$BASE/wt" feature 2>/dev/null
rm -f "$BASE/wt/FLOW.md"                      # a git-ignored config never reaches a worktree
(cd "$BASE/wt" && node "$CLI" bundle > "$BASE/pack-wt.txt" 2>&1)
check "FLOW.md is found from a worktree"       "$BASE/pack-wt.txt" hit  "Left out by .git.diff_exclude"
check "so the base resolves there too"         "$BASE/pack-wt.txt" miss 'does not resolve'

# The pack says which config files it read: the overlay failure is silent otherwise.
node "$CLI" bundle --harness claude > "$BASE/pack-noovl.txt" 2>&1
check "names the config it read"               "$BASE/pack-noovl.txt" hit  'Config read: FLOW.md\.'
printf '## models\n- agents: from-the-overlay\n' > FLOW.claude.md
node "$CLI" bundle --harness claude > "$BASE/pack-ovl.txt" 2>&1
check "and names the overlay when there is one" "$BASE/pack-ovl.txt" hit 'FLOW.md + FLOW.claude.md'

# ...and the overlay only arrives when a harness is named. A run without `--harness` reads
# the base alone and used to print the same header as a repo that has no overlay, which is
# the silence the line exists to break: `agents.exec_cmd` set only there reads as unset, and
# the review round takes a path nobody chose.
node "$CLI" bundle > "$BASE/pack-noharness.txt" 2>&1
check "an unread overlay is named, not hidden"  "$BASE/pack-noharness.txt" hit 'no .--harness. was given, so FLOW.claude.md went unread'
check "and its keys do not reach the config"    "$BASE/pack-noharness.txt" miss 'from-the-overlay'

printf '## agents\n- exec_cmd: echo\n' >> FLOW.claude.md
node "$CLI" review > "$BASE/review-noharness.txt" 2>&1
check "review names the files it really read"   "$BASE/review-noharness.txt" hit 'is empty in FLOW.md — no .--harness. was given'
rm -f FLOW.claude.md

# A misspelled harness reads no overlay at all, which is indistinguishable from a repo that
# has none. It stops instead.
node "$CLI" bundle --harness cluade > "$BASE/pack-typo.txt" 2>&1
check "a misspelled harness stops the run"      "$BASE/pack-typo.txt" hit 'unknown harness .cluade.'

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "bundle-limits: all cases pass"; else echo "bundle-limits: $fails failure(s)"; exit 1; fi
