#!/usr/bin/env bash
# Exercise `flow panel`, the renderer of a work's live panel.
#     bash script/tests/panel.sh
# The panel used to be rebuilt by hand from prose at every stop, and the record says how that
# went: the plan's steps almost never reached it, merged MRs/PRs stayed `wait`, and other
# harnesses lost the clock and the links. Each case below is one of those failures, rendered
# from a throwaway work: steps from either tick format, a feature's and a bug's plan, statuses
# the plan's table never listed, a finished work, the agent's input and its labels, sibling
# repos, the Open line, the card, meta.json left byte-identical, and --forge against stub
# gh/glab binaries: a merge done in the forge, and what an open MR/PR waits on.
set -u
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-panel-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0

cd "$BASE/repo" || exit 1
git init -q -b main .
git remote add origin git@gitlab.com:acme/shop.git
git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
git checkout -q -b feature
W=.claude/work/T-1-thing
mkdir -p "$W"

meta() { printf '%s\n' "$1" > "$W/meta.json"; }
input() { printf '%s\n' "$1" > "$W/panel-input.json"; }
run() { out=$(node "$CLI" panel "$@" 2>"$BASE/err"); rc=$?; err=$(cat "$BASE/err"); }
# <label> <js expression over `d` (the printed document)> — true means ok
expect() {
  if [ "$rc" = 0 ] && node -e "const d=JSON.parse(process.argv[1]); const L=d.lines.filter(l=>typeof l==='object'); const k=(x)=>L.find(l=>l.key===x); process.exit(($2)?0:1)" "$out"; then
    printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       rc=%s err=%s\n       %s\n' "$1" "$rc" "$err" "$out"; fails=$((fails+1)); fi
}

# 1 — a feature's plan, ticks in both formats, the MR/PR being built carries its steps
meta '{"ticket":"T-1","type":"feat","title":"T-1 · Ship the thing","branch":"feature","phase":"build",
  "mrs":[{"n":1,"title":"first","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"},
         {"n":2,"title":"second","status":"in_progress"},
         {"n":3,"title":"third","status":"pending"},{"n":4,"title":"fourth","status":"pending"}]}'
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #2
1. [x] column + migration — `db/` — test
- [x] 2. repository query
3. [ ] use case
4. endpoint
5. [ ] docs
## Steps
MD
rm -f "$W/panel-input.json"
run
expect "title drops the ticket id"                  'k("title").text==="Ship the thing"'
expect "merged MR/PR is done, with its link"         'k("mr-1").mark==="done" && k("mr-1").link.endsWith("/7")'
expect "the MR/PR being built is current"            'k("mr-2").mark==="current"'
expect "ticked steps (both formats) are done"        'k("step-1").mark==="done" && k("step-2").mark==="done" && k("step-1").indent===4'
expect "first unticked step is current, rest pending" 'k("step-3").mark==="current" && k("step-4").mark==="pending" && k("step-5").mark==="pending"'
expect "step text stops at the em dash"              'k("step-1").text==="column + migration"'
expect "pending MRs/PRs fold into one line"           'k("mr-3-4").ref==="#3–#4" && k("mr-3-4").mark==="pending"'
expect "the clock is always there"                   'typeof d.updated_at==="string" && d.updated_at.length>=20'
expect "no input → no Now/Next/Decision"              '!k("now") && !k("next") && !k("decision") && !d.attention'
expect "the train opens with a folded header"        'k("mrs").style==="section" && k("mrs").collapsed===true && k("mrs").text==="MRs" && k("mrs").summary==="1/4 merged"'
expect "the plan is a block of its own, left open"   'k("plan").style==="section" && !k("plan").collapsed && k("plan").text==="Plan #2" && k("plan").summary==="2/5"'
expect "the plan block follows the train"            'd.lines.findIndex(l=>l.key==="plan") > d.lines.findIndex(l=>l.key==="mr-3-4") && d.lines[d.lines.findIndex(l=>l.key==="plan")-1]===""'
expect "no plan place in meta → no milestone"        '!("milestone" in d) && !("deliverable" in d)'

# 2 — more than three done fold, a long pending tail folds, five step lines at most
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #2
1. [x] a
2. [x] b
3. [x] c
4. [x] d
5. [ ] e
6. [ ] f
7. [ ] g
8. [ ] h
9. [ ] i
MD
run
expect "four done fold into one"                      'k("steps-done").ref==="1–4"'
expect "pending tail folds, five step lines at most"  'L.filter(l=>l.indent===4).length===5 && k("steps-pending").ref==="8–9" && k("step-6").mark==="pending"'

# 3 — a bug in fix: steps from 04-fix.md, under the single MR/PR line
meta '{"ticket":"T-1","type":"bug","title":"Broken thing","branch":"feature","phase":"fix",
  "mr_url":"https://github.com/acme/shop/pull/12"}'
printf '## Plan\n1. [x] reproduce\n2. [ ] fix\n' > "$W/04-fix.md"
run
expect "a bug in fix shows its plan"                  'k("step-1").mark==="done" && k("step-2").mark==="current"'
expect "single MR/PR from mr_url, named by its number" 'k("mr-1").ref==="#12" && k("mr-1").mark==="wait"'
expect "a GitHub train is PRs; a bug's plan has no number" 'k("mrs").text==="PRs" && k("mrs").summary==="0/1 merged" && k("plan").text==="Plan" && k("plan").summary==="1/2"'
git remote set-url origin git@github.com:acme/shop.git
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"plan","mrs":[{"n":1,"title":"a","status":"pending"}]}'
run
expect "a GitHub remote says PRs before any PR exists" 'k("mrs").text==="PRs" && k("mrs").summary==="0/1 merged"'
git remote set-url origin git@gitlab.com:acme/shop.git
meta '{"ticket":"T-1","type":"bug","title":"Broken thing","branch":"feature","phase":"fix",
  "mr_url":"https://github.com/acme/shop/pull/12"}'

# 4 — statuses nobody listed, and a bare string entry, are drawn, never refused
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged_into_umbrella"},{"n":2,"title":"b","status":"closed_superseded_by_umbrella"},
         {"n":3,"title":"c","status":"skipped"},{"n":4,"title":"d","status":"open","url":"https://gitlab.com/acme/shop/-/merge_requests/9"},
         "just a title"]}'
rm -f "$W/04-fix.md"
run
expect "merged_* is done, closed_* is block, skipped is gone" 'k("mr-1").mark==="done" && k("mr-2").mark==="block" && !k("mr-3")'
expect "an unknown status with a URL waits"           'k("mr-4").mark==="wait"'
expect "a string entry is a pending title"            'k("mr-5").text==="just a title" && k("mr-5").mark==="pending"'

# 4b — where the console works in the project's plan, only as meta.json records it
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"build",
  "roadmap":{"path":"docs/roadmap.md","item":"x","under":"H3","milestone":"H3","deliverable":"T-1"}}'
run
expect "milestone and deliverable from meta.roadmap" 'd.milestone==="H3" && d.deliverable==="T-1" && !("attention_since" in d)'
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"build",
  "roadmap":{"path":"docs/roadmap.md","item":"x","under":"H3","deliverable":"T-1"}}'
run
expect "a deliverable without its milestone is dropped" '!("milestone" in d) && !("deliverable" in d) && !k("mrs")'

# 5 — a finished work closes cleanly
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"done",
  "mrs":[{"n":1,"title":"a","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/9"}],
  "followups":[{"status":"proposed"}]}'
input '{"now":"waiting","decision":"merge it?"}'
run
expect "done: train done, no decision, closing line, attention done" 'k("mr-1").mark==="done" && !k("decision") && !k("now") && k("closed").style==="ok" && d.attention==="done" && !k("open")'

# 6 — the agent's input: verbatim text, labels, attention, blockers
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"build",
  "related_repos":[{"repo":"acme/mcp","scope":"handshake diagnostics. More.","mrs":["https://gitlab.com/acme/mcp/-/merge_requests/71"]}],
  "review_findings":[{"round":1,"outcome":"open"},{"round":2,"outcome":"open"},{"round":2,"outcome":"fixed"}],
  "followups":[{"status":"proposed"},{"status":"logged"},{"status":"accepted"}]}'
input '{"phase":"review","now":"suite over #2","next":"ship #2","decision":"confirm the body",
  "blocks":[{"text":"mcp needs the contract","link":"https://x/1"}],"labels":{"now":"Ahora","open":"Abierto","followups":"seguimientos"},
  "colour":"red","attention":"loud"}'
run
expect "Now/Next/Decision verbatim, labels applied"    'k("now").ref==="Ahora" && k("now").text==="suite over #2" && k("next").ref==="Next" && k("decision").mark==="wait"'
expect "a decision claims the user"                    'd.attention==="wait" && d.phase==="review"'
expect "blockers carry their link"                     'k("block-1").mark==="block" && k("block-1").link==="https://x/1"'
expect "sibling MR/PR with repo, number and link"      'k("sib-1").ref==="mcp !71" && k("sib-1").link.endsWith("/71") && k("sib-1").text==="handshake diagnostics"'
expect "Open: latest round only, open follow-ups"      'k("open").ref==="Abierto" && k("open").text==="review round 2 · 1 open · 2 seguimientos"'
if printf '%s' "$err" | grep -q 'colour' && printf '%s' "$err" | grep -q 'loud'; then printf '  ok   unknown field and bad attention warn, never refuse\n'
else printf '  FAIL warnings missing: %s\n' "$err"; fails=$((fails+1)); fi

# 7 — meta.json is never written; panel.json is; card.json only with the mirror on
before=$(sha1sum "$W/meta.json")
run
after=$(sha1sum "$W/meta.json")
[ "$before" = "$after" ] && printf '  ok   meta.json byte-identical\n' || { printf '  FAIL meta.json changed\n'; fails=$((fails+1)); }
[ -f "$W/panel.json" ] && [ ! -f "$W/card.json" ] && printf '  ok   panel.json written, no card without the mirror\n' || { printf '  FAIL panel.json/card.json\n'; fails=$((fails+1)); }
printf '## panel\n- artifact: https://claude.ai/artifact/x\n' > FLOW.claude.md
run --harness claude
if node -e "const c=require('$BASE/repo/$W/card.json'); process.exit(c.repo==='acme.shop' && c.work==='T-1-thing' && c.harness==='Claude Code' && c.ticket==='T-1' && Array.isArray(c.lines)?0:1)"; then printf '  ok   card.json with repo id, work, harness\n'
else printf '  FAIL card.json: %s\n' "$(cat "$W/card.json" 2>&1)"; fails=$((fails+1)); fi

# 8 — --work from another branch; unreadable input refuses and writes nothing; no work
git checkout -q main
run --work T-1-thing
expect "--work finds the folder from another branch"   'k("title").text==="x"'
printf '{oops' > "$W/panel-input.json"; rm -f "$W/panel.json"
run --work T-1-thing
[ "$rc" = 1 ] && [ ! -f "$W/panel.json" ] && printf '  ok   unreadable input: exit 1, nothing written\n' || { printf '  FAIL unreadable input rc=%s\n' "$rc"; fails=$((fails+1)); }
run
[ "$rc" = 1 ] && printf '%s' "$err" | grep -q 'no work on' && printf '  ok   no work on this branch: exit 1\n' || { printf '  FAIL no-work rc=%s %s\n' "$rc" "$err"; fails=$((fails+1)); }

# 9 — --forge: a merge done in the forge shows as done; an open one says what it waits on
mkdir -p "$BASE/bin"
cat > "$BASE/bin/glab" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"mr view 7 "*)  echo '{"state":"merged","draft":false}'; echo '{"trailing":"noise"}' ;;
  *"mr view 9 "*)  echo '{"state":"opened","draft":true,"head_pipeline":{"status":"running"}}' ;;
  *approvals*)     echo '{"approvals_required":2,"approvals_left":1,"approved_by":[{}]}' ;;
  *discussions*)   echo '[{"notes":[{"resolvable":true,"resolved":false}]},{"notes":[{"resolvable":true,"resolved":true}]},{"notes":[{"resolvable":false}]}]' ;;
  *) exit 1 ;;
esac
SH
cat > "$BASE/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *pull/12*) echo '{"state":"OPEN","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"},{"status":"COMPLETED","conclusion":"FAILURE"}]}' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$BASE/bin/glab" "$BASE/bin/gh"
git checkout -q feature
rm -f "$W/panel-input.json"
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/7"},
         {"n":2,"title":"b","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/9"},
         {"n":3,"title":"c","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/404"}],
  "related_repos":[{"repo":"acme/api","mrs":["https://github.com/acme/api/pull/12"]}]}'
before=$(sha1sum "$W/meta.json")
PATH="$BASE/bin:$PATH" run --forge
expect "merged in the forge, in_progress in meta → done"  'k("mr-1").mark==="done" && !k("mr-1-state")'
expect "open MR/PR: draft, pipeline, approvals, threads"  'k("mr-2").mark==="wait" && k("mr-2-state").text==="draft · pipeline running · 1/2 approvals · 1 open threads" && k("mr-2-state").indent===4'
expect "GitHub: failed check wins, review decision named" 'k("sib-1").text==="pipeline failed · review required" && k("sib-1").mark==="wait"'
expect "forge silent → drawn from meta, no state line"    'k("mr-3").mark==="wait" && !k("mr-3-state")'
printf '%s' "$err" | grep -q 'no state for https://gitlab.com/acme/shop/-/merge_requests/404' && printf '  ok   a silent forge is named on stderr\n' || { printf '  FAIL no warning: %s\n' "$err"; fails=$((fails+1)); }
[ "$before" = "$(sha1sum "$W/meta.json")" ] && printf '  ok   meta.json untouched by --forge\n' || { printf '  FAIL meta.json changed by --forge\n'; fails=$((fails+1)); }

# 10 — panel.publish_cmd gets the document on stdin; a failing one warns and still writes
printf '## panel\n- publish_cmd: cat > "%s/published.json"\n' "$BASE" > FLOW.md
run
node -e "const d=require('$BASE/published.json'); process.exit(d.lines && d.lines[0].key==='title'?0:1)" 2>/dev/null && ok_pub=1 || ok_pub=
[ -n "$ok_pub" ] && printf '  ok   publish_cmd receives the document\n' || { printf '  FAIL publish_cmd got nothing\n'; fails=$((fails+1)); }
printf '## panel\n- publish_cmd: exit 3\n' > FLOW.md
rm -f "$W/panel.json"; run
[ "$rc" = 0 ] && [ -f "$W/panel.json" ] && printf '%s' "$err" | grep -q 'publish_cmd failed' && printf '  ok   a failing publish_cmd warns, panel.json still written\n' || { printf '  FAIL failing publish_cmd rc=%s %s\n' "$rc" "$err"; fails=$((fails+1)); }
printf '## panel\n- publish_cmd: touch "%s/ran"\n' "$BASE" > FLOW.md
git add FLOW.md
rm -f "$BASE/ran"; run
[ ! -f "$BASE/ran" ] && printf '%s' "$err" | grep -q 'tracked by git' && printf '  ok   a committed publish_cmd never runs, and says why\n' || { printf '  FAIL a tracked publish_cmd ran or was silent: %s\n' "$err"; fails=$((fails+1)); }
git rm -q --cached FLOW.md; rm -f FLOW.md

# 11 — an abandoned work: its blocker stays, nothing else talks, nobody is claimed
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"abandoned"}'
input '{"now":"x","decision":"y","blocks":[{"text":"abandoned: not needed"}]}'
run
expect "abandoned: block line, no Now/Decision, no attention" 'k("block-1").text==="abandoned: not needed" && !k("now") && !k("decision") && !d.attention'

# 12 — review round 1: every MR/PR merged in the forge closes the card, whatever the input says
git checkout -q feature; rm -f FLOW.md
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}]}'
input '{"phase":"ship","now":"MR open, waiting for review","decision":"tell me when it merges"}'
PATH="$BASE/bin:$PATH" run --forge
expect "own session: merged, but its live question keeps it waiting" 'k("mr-1").mark==="done" && k("decision") && d.attention==="wait"'
git checkout -q main; PATH="$BASE/bin:$PATH" run --forge --work T-1-thing; git checkout -q feature
expect "daily (--work): all merged closes the card over a stale input" 'k("mr-1").mark==="done" && !k("decision") && !k("now") && k("closed") && d.attention==="done"'
# … and a render without --forge keeps what the forge said; a failed --forge keeps it too
input '{"phase":"ship"}'
run
expect "no --forge: the last forge answer is reused"   'k("mr-1").mark==="done" && d.attention==="done"'
mkdir -p "$BASE/failbin"; printf '#!/bin/sh\nexit 1\n' > "$BASE/failbin/glab"; cp "$BASE/failbin/glab" "$BASE/failbin/gh"; chmod +x "$BASE/failbin/"*
PATH="$BASE/failbin:$PATH" run --forge
expect "a --forge whose calls fail keeps the cached merge" 'k("mr-1").mark==="done" && d.attention==="done"'
# a sibling still open keeps the work open
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}],
  "related_repos":[{"repo":"acme/api","mrs":["https://github.com/acme/api/pull/12"]}]}'
PATH="$BASE/bin:$PATH" run --forge
expect "an open sibling MR/PR keeps the work from closing" '!k("closed") && k("sib-1").mark==="wait"'
# meta.json's merged beats a cached close
printf '{"states":{"https://gitlab.com/acme/shop/-/merge_requests/7":{"state":"closed","at":"2020-01-01T00:00:00Z"}}}' > "$W/forge-state.json"
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}]}'
run
expect "meta.json merged wins over a cached closed"     'k("mr-1").mark==="done"'
# an open MR/PR's cached summary goes stale
printf '{"states":{"https://gitlab.com/acme/shop/-/merge_requests/9":{"state":"open","summary":"pipeline running","at":"2020-01-01T00:00:00Z"}}}' > "$W/forge-state.json"
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/9"}]}'
run
expect "a cached summary older than an hour is dropped" 'k("mr-1").mark==="wait" && !k("mr-1-state")'
rm -f "$W/forge-state.json"

# repair-round steps under ### count; an abandoned work draws nothing current; phases_done object
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"validate","mrs":[{"n":1,"title":"a","status":"in_progress"}]}'
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #1
1. [x] a
2. [x] b
### Red suite at validate (unattended), round 1: 2 red
1. [ ] fix test_x
2. [ ] fix test_y
MD
rm -f "$W/panel-input.json"; run
expect "repair-round steps under ### are on the panel"  'k("step-r1-1").ref==="r1.1" && k("step-r1-1").mark==="current" && k("step-r1-2").mark==="pending" && k("step-1").mark==="done"'
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"abandoned","mrs":[{"n":1,"title":"a","status":"pending"}]}'
run
expect "abandoned: no current MR/PR, no steps"          '!L.some(l=>l.mark==="current") && !k("step-1")'
meta '{"ticket":"T-1","type":"bug","title":"x","branch":"feature","phase":"validate","phases_done":{"context":true}}'
printf '## Plan\n1. [ ] fix\n' > "$W/04-fix.md"
run
expect "a phases_done that is not a list never throws"  'k("step-1")'
meta '{"ticket":"T-1","type":"bug","title":"x","branch":"feature","phase":"validate","phases_done":["fix"]}'
input '{"phase":"fix"}'
run
expect "a bug back in fix shows its new steps"          'k("step-1").mark==="current"'
rm -f "$W/04-fix.md" "$W/panel-input.json"

# 13 — nested lists, ### notes and fences are not steps; a single-MR plan with a pending entry shows them
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"plan",
  "mrs":[{"n":1,"title":"only","status":"pending"}]}'
rm -f "$W/panel-input.json" "$W/forge-state.json"
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #1
- [x] 1. add column
   1. sub-detail
   2. another
2. repository query
```
3. not a step
```
### Notes
1. something
MD
run
expect "one line per top-level step, current on step 2"  'L.filter(l=>l.indent===4).length===2 && k("step-1").mark==="done" && k("step-2").mark==="current" && k("step-2").text==="repository query"'
expect "a pending single entry with a plan is being built" 'k("mr-1").mark==="current"'

# 14 — a bug in fix whose meta.json still says investigate shows its plan
meta '{"ticket":"T-1","type":"bug","title":"x","branch":"feature","phase":"investigate","phases_done":["context","investigate"]}'
printf '## Plan\n1. [x] reproduce\n2. [ ] fix\n' > "$W/04-fix.md"
run
expect "bug: steps shown until fix closes"              'k("step-2").mark==="current"'
meta '{"ticket":"T-1","type":"bug","title":"x","branch":"feature","phase":"fix","phases_done":["context","investigate","fix"]}'
printf '## Plan\n1. [x] reproduce\n2. [x] fix\n' > "$W/04-fix.md"
run
expect "bug: steps gone once fix closed and all ticked"  '!k("step-1")'
rm -f "$W/04-fix.md"

# 15 — done wins the phase; the id is dropped only as a token; pr_url; bad harness; bad label
meta '{"ticket":"244","type":"feat","title":"2440 widgets","branch":"feature","phase":"done","pr_url":"https://github.com/acme/shop/pull/5"}'
input '{"phase":"ship","labels":{"nope":"x"}}'
run
expect "done: phase done even when the input says ship"  'd.phase==="done"'
expect "a title that only starts with the id keeps it"   'k("title").text==="2440 widgets"'
expect "pr_url is the single MR/PR"                      'k("mr-1").ref==="#5" && k("mr-1").mark==="done"'
printf '%s' "$err" | grep -q 'label `nope`' && printf '  ok   an unknown label warns\n' || { printf '  FAIL no label warning: %s\n' "$err"; fails=$((fails+1)); }
run --harness klaude
[ "$rc" = 1 ] && printf '%s' "$err" | grep -q 'unknown --harness' && printf '  ok   an unknown --harness is refused\n' || { printf '  FAIL harness rc=%s\n' "$rc"; fails=$((fails+1)); }

# 16 — a --work render never reaches publish_cmd; --repo works from outside the checkout
printf '## panel\n- publish_cmd: touch "%s/sent"\n' "$BASE" > FLOW.md
rm -f "$BASE/sent"; run --work T-1-thing
[ -f "$BASE/sent" ] && printf '  ok   --work naming this branch'"'"'s own work is published\n' || { printf '  FAIL own --work not published\n'; fails=$((fails+1)); }
git checkout -q main; rm -f "$BASE/sent"; run --work T-1-thing; git checkout -q feature
[ ! -f "$BASE/sent" ] && printf '  ok   another branch'"'"'s work is not sent to publish_cmd\n' || { printf '  FAIL --work render was published\n'; fails=$((fails+1)); }
rm -f "$BASE/sent"; (cd / && node "$CLI" panel --repo "$BASE/repo" >/dev/null 2>&1)
[ -f "$BASE/sent" ] && printf '  ok   --repo from outside the checkout renders and publishes\n' || { printf '  FAIL --repo\n'; fails=$((fails+1)); }
rm -f FLOW.md

# 17 — thirty concurrent renders never collide on a temp file
pids=(); for _ in $(seq 1 30); do node "$CLI" panel >/dev/null 2>"$BASE/err.$_" & pids+=($!); done
bad=0; for p in "${pids[@]}"; do wait "$p" || bad=$((bad+1)); done
[ "$bad" = 0 ] && node -e "JSON.parse(require('fs').readFileSync('$BASE/repo/$W/panel.json','utf8'))" && printf '  ok   30 concurrent renders, none failed, panel.json whole\n' || { printf '  FAIL %s of 30 concurrent renders failed\n' "$bad"; fails=$((fails+1)); }

# round 3: repair steps without a checkbox, a prose list after the plan, abandoned in_progress
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"validate","mrs":[{"n":1,"title":"a","status":"in_progress"}]}'
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #1
- [x] 1. a
2. b

Risks considered:
1. the cache may be cold
2. a migration lock
### Red suite at validate (unattended), round 2: 1 red
1. test_x fails — fix the code
### Notes
1. not a step
MD
rm -f "$W/panel-input.json"; run
expect "a bare number under ### Notes is not a step"     'k("step-2").mark==="current" && !L.some(l=>/not a step/.test(l.text||""))'
expect "repair steps without a checkbox are steps"      'k("step-r2-1").mark==="pending" && k("step-r2-1").ref==="r2.1"'
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"abandoned","mrs":[{"n":1,"title":"a","status":"in_progress"}]}'
run
expect "abandoned with an in_progress entry: nothing current" '!L.some(l=>l.mark==="current")'

# a status-only sibling keeps the work open; empty blocks do not hold it open; a cached close expires
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}],
  "related_repos":[{"repo":"acme/api","scope":"endpoint","status":"pending"}]}'
run
expect "a sibling with no MR/PR does not hold the work open" 'k("closed")'
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}]}'
input '{"blocks":[""]}'
run
expect "an empty blocker does not hold a merged work open" 'k("closed") && d.attention==="done"'
printf '{"states":{"https://gitlab.com/acme/shop/-/merge_requests/9":{"state":"closed","at":"2020-01-01T00:00:00Z"}}}' > "$W/forge-state.json"
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"in_progress","url":"https://gitlab.com/acme/shop/-/merge_requests/9"}]}'
rm -f "$W/panel-input.json"; run
expect "an old cached close is not final"               'k("mr-1").mark==="wait"'
rm -f "$W/forge-state.json"

# a render for another branch writes only the card, never that session's panel.json
printf '## panel\n- artifact: https://claude.ai/artifact/x\n' > FLOW.claude.md
run; before=$(sha1sum "$W/panel.json")
rm -f "$W/card.json"
git checkout -q main; sleep 1; node "$CLI" panel --harness claude --work T-1-thing >/dev/null 2>&1; frc=$?; git checkout -q feature
[ "$frc" = 0 ] && [ "$before" = "$(sha1sum "$W/panel.json")" ] && [ -f "$W/card.json" ] && printf '  ok   another branch'"'"'s render writes the card, not panel.json\n' || { printf '  FAIL foreign render touched panel.json\n'; fails=$((fails+1)); }
rm -f FLOW.claude.md

# a worktree with its own .claude/work finds the work kept in the main checkout (no --work)
git worktree add -q "$BASE/wt2" -b other2 feature 2>/dev/null
mkdir -p "$BASE/wt2/.claude/work/_archive"
sed -i 's/"branch":"feature"/"branch":"other2"/' "$W/meta.json"
(cd "$BASE/wt2" && node "$CLI" panel >/dev/null 2>"$BASE/err.wt"); rc=$?
[ "$rc" = 0 ] && printf '  ok   the work in the main checkout is found from a worktree with its own .claude/work\n' || { printf '  FAIL rc=%s %s\n' "$rc" "$(cat "$BASE/err.wt")"; fails=$((fails+1)); }
sed -i 's/"branch":"other2"/"branch":"feature"/' "$W/meta.json"
# --work as a path: inside this repo's work folders only
run --work "$BASE/repo/$W"
expect "--work takes the folder's path"                 'k("title")'
run --work /tmp
[ "$rc" = 1 ] && printf '  ok   a path outside the work folders is refused\n' || { printf '  FAIL outside path rc=%s\n' "$rc"; fails=$((fails+1)); }

# round 4: review fixes under their own ###, a late lower-numbered step, struck steps, repeated rounds
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"build","mrs":[{"n":1,"title":"a","status":"in_progress"}]}'
cat > "$W/05-implementation.md" <<'MD'
## Plan MR/PR #1
- [x] 1. a
- [x] 3. c
- [x] 2. b, added later
4. ~~widen guard~~ — dropped
### Arreglos de la review 1
- [ ] 5. fix finding A
### Red suite at validate (unattended), round 1: 1 red
1. t1
### Red suite at validate (unattended), round 1: 1 red
1. t1 again
MD
rm -f "$W/panel-input.json"; run
expect "review fixes under their own ### are steps"     'k("step-5").mark==="current"'
expect "a step written out of order is kept"            'L.some(l=>l.key==="steps-done"||l.key==="step-2")'
expect "a struck-through step is not drawn"              '!L.some(l=>/widen guard/.test(l.text||""))'
expect "a repeated round gets unique keys"               'new Set(L.filter(l=>l.indent===4).map(l=>l.key)).size===L.filter(l=>l.indent===4).length'
# a bug past fix hides its plan; back in fix shows it
meta '{"ticket":"T-1","type":"bug","title":"x","branch":"feature","phase":"ship","phases_done":["fix","validate"]}'
printf '## Plan\n1. [x] repro\n2. [ ] guard\n' > "$W/04-fix.md"
run
expect "a bug past fix does not draw its plan"           '!k("step-1")'
rm -f "$W/04-fix.md"
# a sibling whose MR/PR closed unmerged is a block, not done
meta '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"ship",
  "mrs":[{"n":1,"title":"a","status":"merged","url":"https://gitlab.com/acme/shop/-/merge_requests/7"}],
  "related_repos":[{"repo":"acme/api","status":"closed","mrs":["https://github.com/acme/api/pull/3"]}]}'
printf '{"states":{"https://github.com/acme/api/pull/3":{"state":"closed","at":"%s"}}}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$W/forge-state.json"
run
expect "a sibling closed unmerged blocks, the work stays open" 'k("sib-1").mark==="block" && !k("closed")'
rm -f "$W/forge-state.json"

[ "$fails" = 0 ] && echo "panel: all ok" || { echo "panel: $fails failure(s)"; exit 1; }
