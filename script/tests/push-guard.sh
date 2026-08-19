#!/usr/bin/env bash
# Exercise the push guard against the cases that used to slip through.
#
# Every BLOCK case below is a form that once reached the remote, or would have. Run it
# after touching plugins/flow/hooks/block-push-to-master.sh:
#     bash script/tests/push-guard.sh
#
# It builds a throwaway repo whose upstream points at the main branch — the situation the
# guard exists for — and asserts the exit code for each command shape. Nothing here
# touches a real remote.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${TMPDIR:-/tmp}/flow-push-guard-test"
HOOK="$HERE/../../plugins/flow/hooks/block-push-to-master.sh"
MAIN=$(printf 'm\x61ster')          # avoid the literal token in this file

rm -rf "$BASE/hooktest" && mkdir -p "$BASE/hooktest" && cd "$BASE/hooktest" || exit 1
git init -q -b "$MAIN" . >/dev/null
git commit -q --allow-empty -m init
git switch -q -c feature-branch
git remote add origin . 2>/dev/null
git update-ref "refs/remotes/origin/$MAIN" HEAD
git branch "--set-upstream-to=origin/$MAIN" feature-branch >/dev/null 2>&1

run() {
  local want=$1 cmd=$2
  local json
  json=$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$cmd")
  printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then printf '  ok   '; else printf '  FAIL '; fi
  printf 'exit=%s (want %s)  %s\n' "$got" "$want" "$cmd"
}

echo "must BLOCK (exit 2) — no refspec, upstream on the main branch:"
run 2 "git push --force"
run 2 "git push -f"
run 2 "git push --force-with-lease"
run 2 "git push -v"
run 2 "git push"
run 2 "git push origin"
run 2 "git push --quiet origin"
run 2 "git push origin HEAD:$MAIN"
run 2 "git push --all origin"
run 2 "git push --mirror origin"

echo "must PASS (exit 0) — explicit refspec to the work branch, or not a push:"
run 0 "git push -u origin HEAD"
run 0 "git push origin feature-branch"
run 0 "git push --force origin feature-branch"
run 0 "git push -o ci.skip origin HEAD"
run 0 "git push --force-with-lease origin feature-branch"
run 0 "git push --repo origin HEAD"
run 0 "git push --recurse-submodules=check origin HEAD"
run 0 "npm test"

echo "must PASS — a push mentioned in data, or an unrelated mention alongside a safe push:"
run 0 "git commit -F - <<'MSG'
we fixed git push --force going to $MAIN
MSG"
run 0 "git commit -m \"sync $MAIN fixes\" && git push -u origin HEAD"
run 2 "git commit -m wip && git push --force"

echo "no jq available — must block any push rather than wave it through:"
nojq=$(mktemp -d)
for b in git python3 bash grep sed awk printf cat; do
  p=$(command -v "$b") && ln -sf "$p" "$nojq/$b" 2>/dev/null
done
json=$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":"git push -u origin HEAD"}}))')
printf '%s' "$json" | PATH="$nojq" bash "$HOOK" >/dev/null 2>&1
got=$?; [ "$got" = 2 ] && printf '  ok   ' || printf '  FAIL '
printf 'exit=%s (want 2)  git push -u origin HEAD  [PATH without jq]\n' "$got"
json=$(python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":"npm test"}}))')
printf '%s' "$json" | PATH="$nojq" bash "$HOOK" >/dev/null 2>&1
got=$?; [ "$got" = 0 ] && printf '  ok   ' || printf '  FAIL '
printf 'exit=%s (want 0)  npm test  [PATH without jq]\n' "$got"
rm -rf "$nojq"

echo "heredoc body dropped, but a push chained AFTER it is still judged:"
run 2 "cat <<EOF > notes.txt
just some text
EOF
git push --force"

rm -rf "$BASE/hooktest"
