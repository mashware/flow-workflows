#!/usr/bin/env bash
# Run the git recipe of /flow:work:handoff exactly as the command prints it.
#     bash script/tests/handoff-recipe.sh
# The recipe is prose a model copies into a shell, so the only test worth having runs the very
# blocks the command carries, not a rewrite of them: a fenced block tagged `handoff-check`,
# `handoff-build` or `handoff-push` is extracted from the command file and executed against a
# throwaway repository with a bare origin.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CMD="$REPO/plugins/flow/commands/work/handoff.md"
BASE="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/flow-handoff-recipe.XXXXXX")" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT
fails=0

ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }
same() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 — wanted [$3], got [$2]"; fi; }

block() {  # <tag> → the body of the fenced block opened with ```bash <tag>
  awk -v tag="$1" '$0 == "```bash " tag {on=1; next} on && /^```/ {exit} on {print}' "$CMD"
}
for tag in handoff-check handoff-build handoff-push; do
  [ -n "$(block "$tag")" ] || bad "the command has a \`$tag\` block"
done
# Each block runs in a shell of its own, its @…@ replaced the way the command tells the model to:
# a harness keeps no variables between calls, and a block that leaned on one would fail here.
# The values below hold no `#`, `&` or `'` — the sed delimiter and the block's own quoting.
run() {  # <tag> <work> <branch> <ticket> <commit> → stdout+stderr, exit code in $?
  block "$1" | sed -e "s#@WORK@#${2:-}#g" -e "s#@BRANCH@#${3:-}#g" -e "s#@TICKET@#${4:-}#g" \
                  -e "s#@COMMIT@#${5:-}#g" \
    | bash 2>&1
}

git init -q --bare "$BASE/origin.git"
git clone -q "$BASE/origin.git" "$BASE/repo" 2>/dev/null
cd "$BASE/repo"
git config user.email t@example.com; git config user.name test
printf '.claude/work/\n' > .gitignore
printf 'one\n' > app.txt
git add . && git commit -qm base && git push -q origin HEAD 2>/dev/null
W=.claude/work/18-thing
mkdir -p "$W/approaches" .claude/work/19-other .claude/work/_archive/7-old
printf '{"ticket":"18"}\n' > "$W/meta.json"
printf '# design\n' > "$W/03-design.md"
printf 'lens\n' > "$W/approaches/minimum.md"
printf '{"lines":[]}\n' > "$W/panel.json"
printf 'x\n' > .claude/work/19-other/meta.json
printf 'x\n' > .claude/work/_archive/7-old/meta.json
printf 'two\n' >> app.txt                      # an unstaged change
printf 'staged\n' > staged.txt && git add staged.txt   # a staged one
expected="$(printf '%s\n' "$W/03-design.md" "$W/approaches/minimum.md" "$W/meta.json")"

state() { git rev-parse HEAD; git branch --show-current; git diff; git diff --cached; git status --porcelain; }
before="$(state)"

same "an absent branch reads as absent" "$(run handoff-check "" study/18)" "rc=2"

out="$(run handoff-build "$W" "" 18)"; rc=$?
same "the build succeeds" "$rc" "0"
commit="$(printf '%s\n' "$out" | sed -n 's/^commit=//p')"
same "it lists this work's folder, panel.json excluded" "$(printf '%s\n' "$out" | grep -v '^commit=')" "$expected"
same "the commit has no parent" "$(git rev-list --parents -n1 "$commit" | wc -w | tr -d ' ')" "1"
same "the commit message names the ticket" "$(git log -1 --format=%s "$commit")" "study 18"
same "HEAD, branch, index and working tree are untouched" "$(state)" "$before"

out="$(run handoff-build .claude/work/nope "" 18)"; rc=$?
same "a folder that does not exist builds nothing" "$rc" "1"
git config --unset user.email; git config --unset user.name
out="$(env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
  -u EMAIL HOME="$BASE" XDG_CONFIG_HOME="$BASE/xdg" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.useConfigOnly GIT_CONFIG_VALUE_0=true \
  bash -c "$(declare -f block run); CMD='$CMD'; run handoff-build '$W' '' 18")"; rc=$?
git config user.email t@example.com; git config user.name test
same "no git identity: the build fails instead of printing a commit" "$rc" "1"
same "and leaves the checkout as it was" "$(state)" "$before"

run handoff-push "" study/18 "" "$commit" >/dev/null
same "the branch on origin holds exactly that tree" \
  "$(git --git-dir="$BASE/origin.git" ls-tree -r --name-only refs/heads/study/18)" "$expected"
same "a branch that now exists reads as existing" "$(run handoff-check "" study/18)" "rc=0"
git push -q origin "$commit:refs/heads/team/study/19" 2>/dev/null
same "a branch whose name only ends the same is not this one" "$(run handoff-check "" study/19)" "rc=2"

run handoff-push "" study/18 "" "" >/dev/null; rc=$?
same "an empty sha is refused, not pushed as a delete" "$rc" "1"
same "and the branch is still there" \
  "$(git --git-dir="$BASE/origin.git" rev-parse --verify -q refs/heads/study/18)" "$commit"

[ "$fails" -eq 0 ] && echo "handoff-recipe: all cases pass" || { echo "handoff-recipe: $fails failure(s)"; exit 1; }
