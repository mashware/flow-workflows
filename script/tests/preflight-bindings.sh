#!/usr/bin/env bash
# Exercise the guards in script/check.py that bind to something outside themselves.
#     bash script/tests/preflight-bindings.sh
# A check that recognises what it guards by literal text — a marker, an anchor line, the
# directory it was started from — does not fail when that text goes away: it finds nothing to
# complain about, and "found nothing" prints exactly like a clean tree. Three of them did it at
# once: six flow-core markers matching no line of the skill, the pre-commit hook checking zero
# files whenever the commit came from a worktree, and two prose lists of the panel words that no
# check read. Every case below is one of those, rebuilt in a throwaway tree.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CHECK="$REPO/script/check.py"
# A fresh directory per run, resolved to its physical path: two sessions run this at once in
# this repo, and on macOS the temporary directory is a symlink the scripts see resolved.
BASE="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/flow-preflight-bindings.XXXXXX")" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT
fails=0

check() {  # <label> <file> <expected: hit|miss> <pattern>
  if grep -q -- "$4" "$2"; then found=hit; else found=miss; fi
  if [ "$found" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — wanted %s for %q\n' "$1" "$3" "$4"; fails=$((fails+1)); fi
}

# The literal-text cases import check.py with `ROOT` pointed at a fixture tree, so the tracked
# tree is only ever read. The fixtures are written from the module's own constants, never from a
# copy pasted here, so a reworded marker cannot leave this test asserting last year's text.
drive() {  # <case> → writes $BASE/<case>.txt with one line per problem, or "clean"
  python3 - "$1" "$BASE" "$CHECK" > "$BASE/$1.txt" 2>&1 <<'PY'
import importlib.util, os, sys

case, base, path = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("flow_check", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
real = mod.ROOT
tree = os.path.join(base, case)

def put(rel, body):
    os.makedirs(os.path.dirname(os.path.join(tree, rel)), exist_ok=True)
    with open(os.path.join(tree, rel), "w", encoding="utf-8") as fh:
        fh.write(body)

def real_text(rel):
    with open(os.path.join(real, rel), encoding="utf-8") as fh:
        return fh.read()

def report():
    print("\n".join(mod.problems) if mod.problems else "clean — the check found no problem")

if case == "markers-in-the-real-skill":
    # Every marker a command must not carry has to be text the skill actually has.
    mod.check_core_skill(mod.tracked_files())
    report()

elif case == "marker-left-behind":
    # The skill is rewritten and one of its blocks reworded: the marker for it now matches
    # nothing, which is how a guard retires without anybody noticing.
    gone = mod.CORE_ONLY_BLOCKS[0]
    put(mod.CORE_SKILL, real_text(mod.CORE_SKILL).replace(gone, "**A reworded heading**"))
    mod.ROOT = tree
    mod.check_core_skill([mod.CORE_SKILL])
    report()

elif case == "vocabulary-in-the-real-prose":
    mod.check_panel_vocabulary_lists(mod.tracked_files())
    report()

elif case == "vocabulary-drifted":
    # One list gains a word the reader drops, the other loses one it knows.
    for rel, anchor, _ in mod.PROSE_VOCABULARY:
        put(rel, real_text(rel))
    skill_rel, skill_anchor, _ = mod.PROSE_VOCABULARY[0]
    src = real_text(skill_rel).replace(skill_anchor + "; the reader draws it. `done` ·",
                                       skill_anchor + "; the reader draws it. `done` · `doing` ·", 1)
    assert "`doing`" in src, "the flow-core list is not where this test thinks it is"
    put(skill_rel, src)
    readme = [r for r, _, words in mod.PROSE_VOCABULARY if words is mod.STYLES][0]
    src = real_text(readme).replace("`normal` · `dim` · ", "`normal` · ", 1)
    assert src != real_text(readme), "the style list is not where this test thinks it is"
    put(readme, src)
    mod.ROOT = tree
    mod.check_panel_vocabulary_lists([r for r, _, _ in mod.PROSE_VOCABULARY])
    report()

elif case == "vocabulary-anchor-gone":
    # Every anchor gone, the two in one file included — each edit on top of the last.
    edited = {}
    for rel, anchor, _ in mod.PROSE_VOCABULARY:
        edited[rel] = edited.get(rel, real_text(rel)).replace(anchor, "- a list somebody rewrote")
    for rel, body in edited.items():
        put(rel, body)
    mod.ROOT = tree
    mod.check_panel_vocabulary_lists([r for r, _, _ in mod.PROSE_VOCABULARY])
    report()
PY
}

# The hook cases run check.py the way git runs a pre-commit hook from a linked worktree: the
# script reached through the shared `.git/hooks`, the working directory at the worktree's top,
# and `GIT_DIR`/`GIT_INDEX_FILE` exported to the worktree's own git dir.
hook() {  # <label> <tree> <gitdir> → $BASE/<label>.txt with the output and the exit code
  ( cd "$2" && GIT_DIR="$3" GIT_INDEX_FILE="$3/index" python3 "$CHECK" ) > "$BASE/$1.txt" 2>&1
  echo "exit=$?" >> "$BASE/$1.txt"
}

drive markers-in-the-real-skill
check "every marker binds to the real skill"      "$BASE/markers-in-the-real-skill.txt" hit 'clean — the check found no problem'

drive marker-left-behind
check "a marker matching nothing is a failure"    "$BASE/marker-left-behind.txt" hit 'CORE_ONLY_BLOCKS marker matches nothing in the skill'
check "and names the check it disarms"            "$BASE/marker-left-behind.txt" hit 'guarding nothing'

drive vocabulary-in-the-real-prose
check "the prose lists match the reader's words"  "$BASE/vocabulary-in-the-real-prose.txt" hit 'clean — the check found no problem'

drive vocabulary-drifted
check "a word the reader drops is named"          "$BASE/vocabulary-drifted.txt" hit 'unknown to the reader: doing'
check "a word the reader knows, missing, too"     "$BASE/vocabulary-drifted.txt" hit 'missing: dim'

drive vocabulary-anchor-gone
check "a list that moved is not a clean list"     "$BASE/vocabulary-anchor-gone.txt" hit 'no line opens with'
check "every anchor is reported, not the first"   "$BASE/vocabulary-anchor-gone.txt" hit "no line opens with '- \*\*\`style\`\*\* —'"
check "including the second one in the same file" "$BASE/vocabulary-anchor-gone.txt" hit "no line opens with '- \*\*\`mark\`\*\* —'"

# A linked worktree of a throwaway clone — never of this repo, which a run killed halfway would
# leave carrying a registration nobody removes. It is checked out at the tree under test,
# uncommitted edits included (`stash create` makes them a commit without touching anything), so
# the check.py and the files it judges are ones that exist together. Untracked files are in no
# commit and stay out.
SNAP="$(git -C "$REPO" stash create)"; SNAP="${SNAP:-$(git -C "$REPO" rev-parse HEAD)}"
git clone -q --shared --no-checkout "$REPO" "$BASE/clone"
WT="$BASE/worktree"
git -C "$BASE/clone" worktree add -q --detach "$WT" "$SNAP"
GD="$(git -C "$WT" rev-parse --absolute-git-dir)"
hook from-a-worktree "$WT" "$GD"
check "a worktree commit checks the worktree"     "$BASE/from-a-worktree.txt" miss 'no tracked files'
check "and finds it in order, sub-scripts included" "$BASE/from-a-worktree.txt" hit  "preflight ok — "

# The same tree as this repo passes wherever it is read from, so the run above cannot tell the
# worktree from the main checkout. Break the worktree alone: only a hook that reads it fails.
: > "$WT/package.json"
hook worktree-broken "$WT" "$GD"
check "what it reads is the worktree, not the main checkout" "$BASE/worktree-broken.txt" hit 'package.json: tracked file is empty'
check "and the commit is refused"                 "$BASE/worktree-broken.txt" hit 'exit=1'
git -C "$WT" checkout -q -- package.json

# The same hook, where the worktree's check.py differs from the one git reached: the tree's own
# copy is the one that runs, so a branch that changes the checks is judged by them.
printf 'import os\nprint("ran the tree copy in", os.getcwd())\n' > "$WT/script/check.py"
hook hands-over "$WT" "$GD"
check "the tree's own check.py is the one that runs" "$BASE/hands-over.txt" hit "ran the tree copy in $WT"

# A checkout with nothing tracked at all: an empty list is the loudest thing this script can
# find, not the quietest.
EMPTY="$BASE/empty"
git init -q "$EMPTY"
hook zero-files "$EMPTY" "$EMPTY/.git"
check "zero tracked files is a failure"           "$BASE/zero-files.txt" hit 'exit=1'
check "and says it checked nothing"               "$BASE/zero-files.txt" hit 'no tracked files'

if [ "$fails" = 0 ]; then echo "preflight-bindings: all cases pass"
else echo "preflight-bindings: $fails failure(s)"; exit 1; fi
