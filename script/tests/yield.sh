#!/usr/bin/env bash
# Exercise `flow yield` over the shapes the works actually hold.
#     bash script/tests/yield.sh
# Cases: works in the main checkout found from a linked worktree · live and `_archive/` ·
# two repos in one call · legacy rows (one per source) and new rows (`sources[]`, `outcome`)
# · old spellings mapped and listed · a composite `a+b` origin · a count-only row · a
# legacy severity that is really an outcome · agents and effective size from `cost[]` · the
# retire verdict after twenty rounds and the too-few one under it · no works at all.
set -u
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-yield-test"
rm -rf "$BASE"; mkdir -p "$BASE"
fails=0

repo() {  # <dir>
  mkdir -p "$1" && git -C "$1" init -q -b main . \
    && git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
}
work() {  # <dir> <json>
  mkdir -p "$1" && printf '%s\n' "$2" > "$1/meta.json"
}

# Repo A: the works live in the main checkout; yield runs from a linked worktree of it.
repo "$BASE/a"
git -C "$BASE/a" worktree add -q "$BASE/a-wt" -b feature 2>/dev/null
W="$BASE/a/.claude/work"
work "$W/legacy" '{"size":"M","review_findings":[
  {"round":1,"origin":"builtin","severity":"high","file":"x.php","discarded_by_skeptic":false},
  {"round":1,"origin":"cli:tests","severity":"blocker","file":"x.php","discarded_by_skeptic":false},
  {"round":1,"origin":"§5.5","severity":"low","file":"y.php","discarded_by_skeptic":false},
  {"round":1,"origin":"built-in+frontend","severity":"medium","file":"z.php","discarded_by_skeptic":false},
  {"round":1,"origin":"code-review","severity":"declined","file":"w.php","discarded_by_skeptic":false},
  {"round":2,"origin":"built-in","count":3,"discarded_by_skeptic":0}]}'
work "$W/_archive/new" '{"size":"L","mrs":[{"n":1,"size":"S"}],
  "cost":[{"phase":"review","round":1,"mr":1,"effective_size":"S","agents":{"built-in":1,"panel:security":2}}],
  "review_findings":[
  {"round":1,"mr":1,"sources":["built-in","panel:security"],"severity":"major","file":"a.ts","outcome":"fixed"},
  {"round":1,"mr":1,"sources":["panel:security"],"severity":"minor","file":"b.ts","outcome":"rejected"},
  {"round":1,"mr":1,"sources":["built-in"],"severity":"minor","file":"c.ts","outcome":"open"}]}'

# Repo B: twenty rounds at M in which `panel:simplify` ran and never found anything only it
# saw, and `built-in` always did.
repo "$BASE/b"
rows=''; costs=''
for i in $(seq 1 20); do
  rows="$rows{\"round\":$i,\"sources\":[\"built-in\"],\"severity\":\"minor\",\"file\":\"f$i\",\"outcome\":\"fixed\"},"
  rows="$rows{\"round\":$i,\"sources\":[\"built-in\",\"panel:simplify\"],\"severity\":\"nit\",\"file\":\"g$i\",\"outcome\":\"fixed\"},"
  costs="$costs{\"phase\":\"review\",\"round\":$i,\"effective_size\":\"M\",\"agents\":{\"built-in\":1,\"panel:simplify\":1}},"
done
work "$BASE/b/.claude/work/many" "{\"size\":\"M\",\"cost\":[${costs%,}],\"review_findings\":[${rows%,}]}"

check() {  # <label> <fixed string>
  if grep -qF -- "$2" "$BASE/out.txt"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — no match for %q in:\n%s\n' "$1" "$2" "$(cat "$BASE/out.txt")"; fails=$((fails+1)); fi
}
section() {  # <heading> — print only that section of the output
  awk -v h="## $1" '$0==h{p=1;next} /^## /{p=0} p' "$BASE/out.txt"
}
in_section() {  # <label> <heading> <fixed string>
  if section "$2" | grep -qF -- "$3"; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s — no match for %q under %s\n' "$1" "$3" "$2"; fails=$((fails+1)); fi
}

(cd "$BASE/a-wt" && node "$CLI" yield . "$BASE/b") > "$BASE/out.txt" 2>&1
check "both repos, live and archive, read once"   '3 work(s), 23 review round(s), 49 finding row(s).'
# Legacy M: builtin+cli:tests share x.php at a mapped `blocker`, so neither is unique there;
# the count row adds findings and no unique; `declined` is not accepted.
# The count-only row of round 2 adds three findings and no round: it cannot be judged.
in_section "aliases fold into built-in"           'M' '| built-in | 21 | 46 | 21 | 20 | 20 | keep |'
in_section "a prefixed panel role is its role"   'M' '| panel:tests | 1 | 1 | 0 | 0 |'
in_section "a section number is its pass"        'M' '| idiom | 1 | 1 | 1 | 1 |'
in_section "a composite origin credits both"     'M' '| panel:frontend | 1 | 1 | 0 | 0 |'
# New rows at S (effective size from cost[], not the work's L): a rejected unique finding
# counts as unique and not accepted; an open one counts as accepted; agents come from cost[].
in_section "new rows bucket by effective size"   'XS+S' '| built-in | 1 | 2 | 1 | 1 | 1 |'
in_section "a rejected finding is not accepted"  'XS+S' '| panel:security | 1 | 2 | 1 | 0 | 2 |'
in_section "twenty rounds, nothing unique: retire" 'M' '| panel:simplify | 20 | 20 | 0 | 0 | 20 | retire at M |'
in_section "under twenty: too few rounds"        'XS+S' 'too few rounds (1/20)'
in_section "old spellings are listed"            'Spellings read as' '- built-in ← builtin, code-review'
in_section "a prefix spelling is listed"         'Spellings read as' '- panel:tests ← cli:tests'

# The same works named twice — the worktree and its main checkout — are still read once.
(cd "$BASE/a-wt" && node "$CLI" yield . "$BASE/a" "$BASE/b") > "$BASE/out.txt" 2>&1
check "a worktree and its main checkout: once"   '3 work(s), 23 review round(s), 49 finding row(s).'

# A composite whose parts fold into one origin credits it once.
mkdir -p "$BASE/c" && git -C "$BASE/c" init -q -b main .
work "$BASE/c/.claude/work/one" '{"size":"L","review_findings":[
  {"round":1,"origin":"builtin+code-review","severity":"minor","file":"q","discarded_by_skeptic":false}]}'
(cd "$BASE/c" && node "$CLI" yield) > "$BASE/out.txt" 2>&1
in_section "a composite of one origin counts once" 'L' '| built-in | 1 | 1 | 1 | 1 |'

repo "$BASE/empty"
(cd "$BASE/empty" && node "$CLI" yield) > "$BASE/out.txt" 2>&1
check "no works: says what it read, exits 0"      'No review rounds recorded'

if node "$CLI" yield "$BASE/not-a-repo" >/dev/null 2>&1; then
  printf '  FAIL a path that is not a checkout is refused\n'; fails=$((fails+1))
else printf '  ok   a path that is not a checkout is refused\n'; fi

cd /
rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "yield: all cases pass"; else echo "yield: $fails failure(s)"; exit 1; fi
