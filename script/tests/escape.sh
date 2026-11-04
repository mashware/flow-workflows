#!/usr/bin/env bash
# Exercise `flow escape` and the escapes line of `flow yield`.
#     bash script/tests/escape.sh
# Cases: a commit inside one work's reviewed range (merge history) is charged to it · a commit
# older than that range is not, though it is an ancestor of the reviewed sha · a squash commit
# whose subject carries one reviewed MR/PR's number is charged to that work · a number that two
# works carry is charged to neither · a commit no review read · the bug's own work is never a
# candidate · no work on the branch · not a commit · `yield` counts the escape per size.
set -u
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-escape-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0
commit() { git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "$1"; git rev-parse HEAD; }

cd "$BASE/repo" || exit 1
git init -q -b main .
printf '## git\n- default_base: main\n' > FLOW.md
old=$(commit "old history")
# A reviewed feature branch, merged with a merge commit.
git checkout -q -b feat-1
bad=$(commit "feature change")
reviewed=$(commit "feature polish")
git checkout -q main
git -c user.email=t@t -c user.name=t merge -q --no-ff feat-1 -m "Merge feat-1"
# A squash-merged PR #41, whose branch commits are gone.
sq=$(commit "41 Something users see (v1.0.0) [minor] (#41)")
both=$(commit "Two works claim this (#50)")
unread=$(commit "Nobody reviewed this")

mkdir -p .claude/work
w() { mkdir -p ".claude/work/$1" && printf '%s\n' "$2" > ".claude/work/$1/meta.json"; }
w feat-1   "{\"ticket\":\"11\",\"size\":\"M\",\"mrs\":[{\"n\":1,\"size\":\"S\",\"branch\":\"feat-1\",\"reviewed_sha\":\"$reviewed\"}]}"
mkdir -p .claude/work/_archive
w _archive/sq "{\"ticket\":\"40\",\"size\":\"L\",\"reviewed_sha\":\"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\",\"mrs\":[{\"n\":1,\"url\":\"https://github.com/o/r/pull/41\",\"reviewed_sha\":\"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\"}]}"
w twin-a   '{"ticket":"50","size":"M","mrs":[{"n":1,"url":"https://github.com/o/r/pull/50","reviewed_sha":"aaaa"}]}'
w twin-b   '{"ticket":"51","size":"M","mrs":[{"n":1,"url":"https://github.com/o/fork/pull/50","reviewed_sha":"bbbb"}]}'
git checkout -q -b bug-1
w bug-1 "{\"ticket\":\"99\",\"type\":\"bug\",\"branch\":\"bug-1\",\"reviewed_sha\":\"$unread\"}"

run() { out=$(node "$CLI" escape "$@" 2>&1); rc=$?; }
expect() {  # <label> <rc> <fixed string>
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -qF -- "$3"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       rc=%s (want %s), no %q in:\n%s\n' "$1" "$rc" "$2" "$3" "$out"; fails=$((fails+1)); fi
}
escape_field() { node -e "const m=require('$BASE/repo/.claude/work/bug-1/meta.json'); console.log(JSON.stringify(m.escape ?? null))"; }

run "$old"
expect "older history is not charged"          0 'is not inside any reviewed range'
[ "$(escape_field)" = null ] && printf '  ok   … and nothing was recorded\n' || { printf '  FAIL recorded %s\n' "$(escape_field)"; fails=$((fails+1)); }
run "$both"
expect "a number two works carry: neither"     0 'matches 2 reviewed works'
run "$unread"
expect "the bug's own work is not a candidate" 0 'is not inside any reviewed range'
run "$sq" --file src/a.ts
expect "a squash PR number charges its work"   0 'went through the review of sq (the commit names its MR/PR'
[ "$(escape_field)" = "{\"work\":\"sq\",\"ticket\":\"40\",\"commit\":\"$sq\",\"file\":\"src/a.ts\",\"size\":\"L\"}" ] \
  && printf '  ok   … recorded with the reviewed size\n' || { printf '  FAIL recorded %s\n' "$(escape_field)"; fails=$((fails+1)); }
run "$bad"
expect "a commit in the reviewed range"        0 'went through the review of feat-1 (one of the'
[ "$(escape_field)" = "{\"work\":\"feat-1\",\"ticket\":\"11\",\"commit\":\"$bad\",\"file\":null,\"size\":\"S\"}" ] \
  && printf '  ok   … recorded at its MR/PR size\n' || { printf '  FAIL recorded %s\n' "$(escape_field)"; fails=$((fails+1)); }

node "$CLI" yield > "$BASE/out.txt" 2>&1
awk '$0=="## XS+S"{p=1;next} /^## /{p=0} p' "$BASE/out.txt" | grep -qF 'escapes: 1 (feat-1)' \
  && printf '  ok   yield counts the escape at its size\n' || { printf '  FAIL yield escapes line:\n%s\n' "$(cat "$BASE/out.txt")"; fails=$((fails+1)); }

# Re-run with a blame no review holds: the earlier escape goes, so yield stops counting it.
run "$unread"
expect "a changed blame drops the old escape"  0 'was removed'
[ "$(escape_field)" = null ] && printf '  ok   … and it is gone from meta.json\n' || { printf '  FAIL still %s\n' "$(escape_field)"; fails=$((fails+1)); }
run "$sq" --file=src/b.ts
expect "--file=<path> is read"                 0 'went through the review of sq'
node -e "process.exit(require('$BASE/repo/.claude/work/bug-1/meta.json').escape.file === 'src/b.ts' ? 0 : 1)" \
  && printf '  ok   … with its file\n' || { printf '  FAIL file not recorded: %s\n' "$(escape_field)"; fails=$((fails+1)); }
run "$sq" --files x
expect "an unknown option is refused"          1 'unknown option `--files`'

# A revert quotes another PR's subject: only the trailing (#N) is the MR/PR it came from.
rev=$(commit 'Revert "41 Something users see (#41)" (#77)')
run "$rev"
expect "a quoted (#N) charges nobody"          0 'No escape recorded'
# GitLab squash: the MR number is in the body, not the subject.
glc=$(git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "Something" -m "See merge request group/repo!88" && git rev-parse HEAD)
w _archive/gl '{"ticket":"87","size":"M","mrs":[{"n":1,"url":"https://gitlab.com/group/repo/-/merge_requests/88","reviewed_sha":"cccc"}]}'
run "$glc"
expect "a GitLab body names its MR"            0 'went through the review of gl (the commit names its MR/PR'
other=$(git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "Elsewhere" -m "See merge request other/proj!88" && git rev-parse HEAD)
run "$other"
expect "another project's MR !88 is not this one" 0 'No escape recorded'
# The bug's own work is never a candidate, even when its own MR/PR number matches.
own=$(commit "Its own fix (#90)")
node -e "const f='$BASE/repo/.claude/work/bug-1/meta.json';const m=require(f);m.mrs=[{n:1,url:'https://github.com/o/r/pull/90',reviewed_sha:'dddd'}];require('fs').writeFileSync(f,JSON.stringify(m))"
run "$own"
expect "its own MR/PR number does not count"   0 'No escape recorded'

# A branch merged into another branch before reaching main: main commits made in between
# are not the inner branch's, and are not charged to its review.
git checkout -q main
git checkout -q -b outer
outer_c=$(commit "outer work")
git checkout -q -b inner
inner_bad=$(commit "inner change")
inner_rev=$(commit "inner reviewed")
git checkout -q main
main_mid=$(commit "someone else on main")
git checkout -q outer
git -c user.email=t@t -c user.name=t merge -q --no-ff inner -m "Merge inner into outer"
git checkout -q main
git -c user.email=t@t -c user.name=t merge -q --no-ff outer -m "Merge outer"
w inner "{\"ticket\":\"60\",\"size\":\"M\",\"mrs\":[{\"n\":1,\"size\":\"M\",\"branch\":\"inner\",\"reviewed_sha\":\"$inner_rev\"}]}"
git checkout -q bug-1
run "$main_mid"
expect "a nested merge does not take main's commits" 0 'No escape recorded'
run "$outer_c"
expect "the parent branch's commit is not the inner's" 0 'No escape recorded'
run "$inner_bad"
expect "but the inner branch's own commit counts"    0 'went through the review of inner (one of the'
# Same commit, evidence gone (the reviewed sha no longer resolves): the escape stays.
node -e "const f='$BASE/repo/.claude/work/inner/meta.json';const m=require(f);m.mrs[0].reviewed_sha='eeee';require('fs').writeFileSync(f,JSON.stringify(m))"
run "$inner_bad"
expect "lost evidence keeps the same commit's escape" 0 'is kept: its evidence did not resolve'
# A bucket with escapes and no review rows prints its escapes without an empty table.
node "$CLI" yield > "$BASE/out.txt" 2>&1
awk '$0=="## M"{p=1;next} /^## /{p=0} p' "$BASE/out.txt" > "$BASE/m.txt"
if grep -qF 'escapes: 1 (inner)' "$BASE/m.txt" && ! grep -qF '| origin |' "$BASE/m.txt"; then printf '  ok   an escapes-only size has no empty table\n'
else printf '  FAIL escapes-only size:\n%s\n' "$(cat "$BASE/m.txt")"; fails=$((fails+1)); fi

# On GitLab `#N` is an issue: a `(#N)` subject never names a GitLab MR of the same number.
w _archive/glnum '{"ticket":"70","size":"M","mrs":[{"n":1,"url":"https://gitlab.com/group/repo/-/merge_requests/123","reviewed_sha":"ffff"}]}'
issue_c=$(commit "Fix login (#123)")
run "$issue_c"
expect "(#N) is not a GitLab MR"               0 'No escape recorded'

# A criss-cross: main merges the branch's early commit, the branch back-merges main, and the
# branch is merged again after review. Main's own commit sits inside the reviewed history and
# is still not the branch's.
git checkout -q main
git checkout -q -b cc
cc1=$(commit "cc early")
git checkout -q main
m1=$(commit "direct to main")
git -c user.email=t@t -c user.name=t merge -q --no-ff cc -m "Merge cc early"
git checkout -q cc
git -c user.email=t@t -c user.name=t merge -q --no-ff main -m "Back-merge main into cc"
cc_bad=$(commit "cc late change")
cc_rev=$(commit "cc reviewed")
git checkout -q main
git -c user.email=t@t -c user.name=t merge -q --no-ff cc -m "Merge cc"
w cc "{\"ticket\":\"80\",\"size\":\"M\",\"mrs\":[{\"n\":1,\"branch\":\"cc\",\"reviewed_sha\":\"$cc_rev\"}]}"
git checkout -q bug-1
run "$m1"
expect "a back-merged main commit is not the branch's" 0 'No escape recorded'
run "$cc_bad"
expect "the branch's commit after the back-merge is" 0 'went through the review of cc (one of the'

# The same commit now matched by two works is ambiguous: the earlier escape does not survive it.
seven=$(commit "Seven (#7)")
w one7 '{"ticket":"7","size":"M","mrs":[{"n":1,"url":"https://github.com/o/r/pull/7","reviewed_sha":"1111"}]}'
run "$seven"
expect "one work names it"                     0 'went through the review of one7'
w two7 '{"ticket":"8","size":"M","mrs":[{"n":1,"url":"https://github.com/o/r/pull/7","reviewed_sha":"2222"}]}'
run "$seven"
expect "two works now: the escape is removed"  0 'removed'
[ "$(escape_field)" = null ] && printf '  ok   … and gone\n' || { printf '  FAIL still %s\n' "$(escape_field)"; fails=$((fails+1)); }

run deadbeef
expect "not a commit is refused"               1 'is not a commit'
git checkout -q main
run "$bad"
expect "no work on the branch is refused"      1 'no work on `main`'

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "escape: all cases pass"; else echo "escape: $fails failure(s)"; exit 1; fi
