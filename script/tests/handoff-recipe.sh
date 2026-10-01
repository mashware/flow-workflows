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
  [ -n "$(block "$tag")" ] || { bad "the command has a \`$tag\` block"; }
done

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

state() { git rev-parse HEAD; git branch --show-current; git diff; git diff --cached; git status --porcelain; }
before="$(state)"

export WORK="$W" BRANCH="study/18" TICKET="18"
eval "$(block handoff-check)"
same "an absent branch reads as absent (rc 2)" "$rc" "2"

eval "$(block handoff-build)"
same "the listed files are this work's folder, panel.json excluded" "$files" \
  "$(printf '%s\n' "$W/03-design.md" "$W/approaches/minimum.md" "$W/meta.json")"
same "the commit has no parent" "$(git rev-list --parents -n1 "$commit" | wc -w | tr -d ' ')" "1"
same "the commit message names the ticket" "$(git log -1 --format=%s "$commit")" "study 18"
same "HEAD, branch, index and working tree are untouched" "$(state)" "$before"
same "the throwaway index is gone with its directory" "${GIT_INDEX_FILE:-unset}" "unset"

eval "$(block handoff-push)" 2>/dev/null
same "the branch on origin holds exactly that tree" \
  "$(git --git-dir="$BASE/origin.git" ls-tree -r --name-only "refs/heads/$BRANCH")" \
  "$(printf '%s\n' "$W/03-design.md" "$W/approaches/minimum.md" "$W/meta.json")"

eval "$(block handoff-check)"
same "a branch that now exists reads as existing (rc 0)" "$rc" "0"

[ "$fails" -eq 0 ] && echo "handoff-recipe: all cases pass" || { echo "handoff-recipe: $fails failure(s)"; exit 1; }
