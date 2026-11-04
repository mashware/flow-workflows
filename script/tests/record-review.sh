#!/usr/bin/env bash
# Exercise `flow record-review`, the one writer of a review round's rows.
#     bash script/tests/record-review.sh
# Cases: a valid round is written whole (rows with every source and their outcome, one
# `cost[]` entry with what it launched) · rounds keep counting · each kind of value outside
# its list is refused, named with the valid ones, and nothing is written · no --file ·
# unreadable JSON · a branch with no work.
set -u
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-record-review-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

cd "$BASE/repo" || exit 1
git init -q -b main .
git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
git checkout -q -b feature
mkdir -p .claude/work/T-1
printf '{"ticket":"T-1","branch":"feature"}\n' > .claude/work/T-1/meta.json
META=.claude/work/T-1/meta.json

run() {  # <json> → rc in $rc, output in $out
  printf '%s\n' "$1" > "$BASE/round.json"
  out=$(node "$CLI" record-review --file "$BASE/round.json" 2>&1); rc=$?
}
expect() {  # <label> <want-rc> <fixed string in output>
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -qF -- "$3"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       rc=%s (want %s), no %q in:\n%s\n' "$1" "$rc" "$2" "$3" "$out"; fails=$((fails+1)); fi
}
in_meta() {  # <label> <fixed string>
  if grep -qF -- "$2" <(node -e "console.log(JSON.stringify(require('$BASE/repo/$META')))"); then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — no %q in meta.json:\n%s\n' "$1" "$2" "$(cat "$META")"; fails=$((fails+1)); fi
}

run '{"round":{"mr":2,"tier":"proportional","effective_size":"S","agents":{"built-in":1,"panel:security":2}},
      "findings":[{"sources":["built-in","panel:security"],"severity":"major","file":"a.ts","outcome":"fixed"},
                  {"sources":["panel:security"],"severity":"minor","file":"b.ts","outcome":"rejected"}]}'
expect "a valid round is recorded"                0 'recorded 2 finding(s)'
in_meta "one row per finding, every source on it" '{"round":1,"mr":2,"sources":["built-in","panel:security"],"severity":"major","file":"a.ts","outcome":"fixed"}'
in_meta "the round says what it launched"         '"round":1,"mr":2,"tier":"proportional","effective_size":"S","agents":{"built-in":1,"panel:security":2},"reviewers":3,"usd":null,"source":"not reported"'

run '{"round":{"agents":{"built-in":1}},"findings":[]}'
expect "a round with no findings is still a round" 0 'recorded 0 finding(s)'
in_meta "and the count goes on"                   '"round":2,"agents":{"built-in":1}'

cp "$META" "$BASE/before.json"
refused() {  # <label> <json> <fixed string naming the bad value>
  run "$2"
  expect "$1" 1 "$3"
  if cmp -s "$META" "$BASE/before.json"; then printf '  ok   … and nothing was written\n'
  else printf '  FAIL %s wrote to meta.json\n' "$1"; fails=$((fails+1)); cp "$BASE/before.json" "$META"; fi
}
refused "a hand-written origin is refused"   '{"round":{"agents":{"built-in":1,"idiom":1,"panel:x":1}},"findings":[{"sources":["builtin"],"severity":"minor","file":"a","outcome":"fixed"}]}' 'sources `builtin`: one of built-in · sweep'
refused "a section number is refused"        '{"round":{"agents":{"built-in":1,"idiom":1,"panel:x":1}},"findings":[{"sources":["§5.5"],"severity":"minor","file":"a","outcome":"fixed"}]}' 'sources `§5.5`'
refused "an outcome as a severity is refused" '{"round":{"agents":{"built-in":1,"idiom":1,"panel:x":1}},"findings":[{"sources":["idiom"],"severity":"declined","file":"a","outcome":"rejected"}]}' 'severity `declined`: one of blocker · major · minor · nit · unrated'
refused "an unknown outcome is refused"      '{"round":{"agents":{"built-in":1,"idiom":1,"panel:x":1}},"findings":[{"sources":["idiom"],"severity":"nit","file":"a","outcome":"accepted"}]}' 'outcome `accepted`: one of fixed · open · rejected · discarded · deferred'
refused "an agents origin is checked too"    '{"round":{"agents":{"Security":1}},"findings":[]}' 'round.agents origin `Security`'
refused "a size outside the four is refused" '{"round":{"effective_size":"XL","agents":{"built-in":1}},"findings":[]}' 'round.effective_size `XL`: one of XS · S · M · L'
refused "every bad value is named at once"   '{"round":{"agents":{"built-in":1,"idiom":1,"panel:x":1}},"findings":[{"sources":["x y"],"severity":"high","file":"","outcome":"done"}]}' '4 value(s) outside the lists'
refused "a round is required"                '{"findings":[]}' '`round` is required'
refused "a round names what it launched"     '{"round":{},"findings":[]}' 'round.agents: every pass this round launched'
refused "a source is a pass that ran"        '{"round":{"agents":{"built-in":1}},"findings":[{"sources":["idiom"],"severity":"nit","file":"a","outcome":"fixed"}]}' 'not in round.agents'

out=$(node "$CLI" record-review 2>&1); rc=$?
expect "no --file is refused"                 1 '--file <rows.json> is required'
printf 'not json' > "$BASE/round.json"
out=$(node "$CLI" record-review --file "$BASE/round.json" 2>&1); rc=$?
expect "unreadable JSON is refused"           1 'is not readable JSON'
git checkout -q -b other
run '{"round":{"agents":{"built-in":1}},"findings":[]}'
expect "a branch with no work is named"       1 'no work on `other`'

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "record-review: all cases pass"; else echo "record-review: $fails failure(s)"; exit 1; fi
