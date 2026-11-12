#!/usr/bin/env bash
# Exercise hooks/panel-refresh.sh, the PostToolUse hook that re-renders a work's panel.
#     bash script/tests/panel-refresh.sh
# It runs after every tool call in every repo the plugin is in, so what matters most is the
# path where it does nothing, and that it does nothing fast: no work, nothing newer than the
# panel. Then that a newer plan, meta.json or panel-input.json does trigger one render, from a
# worktree too, and that a broken CLI or a non-repo never makes it fail.
set -u
unset FLOW_CONTEXT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../../plugins/flow/hooks/panel-refresh.sh"
CLI="$HERE/../../bin/cli.mjs"
BASE="${TMPDIR:-/tmp}/flow-panel-refresh-test"
rm -rf "$BASE"; mkdir -p "$BASE/repo"
fails=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }

cd "$BASE/repo" || exit 1
git init -q -b main .
git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
git checkout -q -b feature
W=.claude/work/T-1-thing
mkdir -p "$W"
printf '{"ticket":"T-1","type":"feat","title":"x","branch":"feature","phase":"build"}\n' > "$W/meta.json"
export FLOW_PANEL_CLI="node $CLI"

fire() { printf '{"cwd":"%s","tool_name":"Edit"}' "$1" | sh "$HOOK"; rc=$?; }
settle() { for _ in $(seq 1 50); do [ -f "$W/panel.json" ] && [ ! "$W/meta.json" -nt "$W/panel.json" ] && return; sleep 0.1; done; }

fire "$BASE/repo"; settle
[ "$rc" = 0 ] && [ -f "$W/panel.json" ] && ok "no panel yet → rendered" || bad "first render (rc=$rc)"

stamp=$(stat -c %Y.%N "$W/panel.json" 2>/dev/null || stat -f %m "$W/panel.json")
start=$(date +%s%N); fire "$BASE/repo"; ms=$(( ($(date +%s%N) - start) / 1000000 ))
sleep 0.3
[ "$stamp" = "$(stat -c %Y.%N "$W/panel.json" 2>/dev/null || stat -f %m "$W/panel.json")" ] && ok "nothing newer → no render" || bad "rendered with nothing newer"
[ "$ms" -lt 300 ] && ok "idle path is fast (${ms} ms)" || bad "idle path took ${ms} ms"

sleep 1; printf '## Plan MR/PR #1\n1. [x] a\n' > "$W/05-implementation.md"
fire "$BASE/repo"; for _ in $(seq 1 50); do [ ! "$W/05-implementation.md" -nt "$W/panel.json" ] && break; sleep 0.1; done
[ ! "$W/05-implementation.md" -nt "$W/panel.json" ] && ok "a newer plan → rendered" || bad "plan change not rendered"

sleep 1; printf '{"now":"suite"}\n' > "$W/panel-input.json"
fire "$BASE/repo"; for _ in $(seq 1 50); do grep -q '"suite"' "$W/panel.json" && break; sleep 0.1; done
grep -q '"suite"' "$W/panel.json" && ok "a newer panel-input.json → its Now is on the panel" || bad "input not rendered"

git worktree add -q "$BASE/wt" -b other main 2>/dev/null
sed -i 's/"branch":"feature"/"branch":"other"/' "$W/meta.json"
fire "$BASE/wt"; for _ in $(seq 1 50); do [ ! "$W/meta.json" -nt "$W/panel.json" ] && break; sleep 0.1; done
[ ! "$W/meta.json" -nt "$W/panel.json" ] && ok "from a worktree, the main checkout's work is found" || bad "worktree not handled"

sleep 1; touch "$W/meta.json"
FLOW_PANEL_CLI="false" fire "$BASE/wt"
[ "$rc" = 0 ] && ok "a failing CLI still exits 0" || bad "failing CLI rc=$rc"
fire "$BASE"
[ "$rc" = 0 ] && ok "outside a repo: exit 0" || bad "non-repo rc=$rc"
git -C "$BASE/repo" checkout -q main
fire "$BASE/repo"
[ "$rc" = 0 ] && ok "a branch with no work: exit 0" || bad "no-work rc=$rc"

# review round 1: a render that writes nothing is not retried until an input changes
sleep 1; touch "$W/meta.json"; rm -f "$W/panel.json"
printf '#!/bin/sh\necho x >> "%s/calls"\n' "$BASE" > "$BASE/fakecli"; chmod +x "$BASE/fakecli"; rm -f "$BASE/calls"
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/wt"; sleep 0.3
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/wt"; sleep 0.3
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/wt"; sleep 0.3
[ "$(wc -l < "$BASE/calls" 2>/dev/null)" = 1 ] && ok "a failed render is tried once, not after every tool call" || bad "retried $(wc -l < "$BASE/calls" 2>/dev/null) times"
sleep 1; touch "$W/panel-input.json"
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/wt"; sleep 0.3
[ "$(wc -l < "$BASE/calls")" = 2 ] && ok "a changed input is tried again" || bad "not retried after a change"

# the render runs outside the checkout, and the event's first cwd is the one used
printf '#!/bin/sh\npwd > "%s/where"\n' "$BASE" > "$BASE/wherecli"; chmod +x "$BASE/wherecli"
sleep 1; touch "$W/meta.json"
printf '{"cwd":"%s","tool_input":{"cwd":"/tmp"}}' "$BASE/wt" | FLOW_PANEL_CLI="$BASE/wherecli" sh "$HOOK"; sleep 0.3
case "$(cat "$BASE/where" 2>/dev/null)" in "$BASE"/*|"") bad "render ran inside the checkout or not at all: $(cat "$BASE/where" 2>/dev/null)" ;; *) ok "the render runs outside the checkout" ;; esac

# a session on the work's base branch never takes the work's stamp, and a worktree with its
# own .claude/work still refreshes a work kept in the main checkout
sed -i 's/"branch":"other"/"branch":"other","base":"main"/' "$W/meta.json"
sleep 1; touch "$W/meta.json"; rm -f "$BASE/calls"
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/repo"; sleep 0.3
[ ! -f "$BASE/calls" ] && ok "a session on the base branch leaves the work alone" || bad "the base-branch session rendered the work"
mkdir -p "$BASE/wt/.claude/work/_archive"
rm -f "$W/panel.json"
fire "$BASE/wt"; for _ in $(seq 1 50); do [ -f "$W/panel.json" ] && break; sleep 0.1; done
[ -f "$W/panel.json" ] && ok "a worktree with its own .claude/work refreshes the main checkout's work" || bad "worktree .claude/work hid the work"

# a meta.json with other JSON spacing still opens the gate
sed -i 's/"branch":"other"/"branch" :  "other"/' "$W/meta.json"
sleep 1; touch "$W/meta.json"; rm -f "$BASE/calls"
FLOW_PANEL_CLI="$BASE/fakecli" fire "$BASE/wt"; sleep 0.3
[ -f "$BASE/calls" ] && ok "any JSON spacing around the branch key is matched" || bad "spacing variant not matched"

# a checkout whose path has a space still refreshes
SP="$BASE/my repo"; mkdir -p "$SP"; git -C "$SP" init -q -b feature; git -C "$SP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m b
mkdir -p "$SP/.claude/work/T-2"; printf '{"ticket":"T-2","branch":"feature","title":"y"}\n' > "$SP/.claude/work/T-2/meta.json"
rm -f "$BASE/calls"; FLOW_PANEL_CLI="$BASE/fakecli" fire "$SP"; sleep 0.3
[ -f "$BASE/calls" ] && ok "a path with a space is not split" || bad "path with a space never refreshed"

# an answered question clears the decision it answered — with no file changed, and through
# publish_cmd too; a question nobody answered, or an input with no decision, is left alone
Q="$BASE/q"; mkdir -p "$Q"; git -C "$Q" init -q -b fix; git -C "$Q" -c user.email=t@t -c user.name=t commit -q --allow-empty -m b
QW="$Q/.claude/work/T-3"; mkdir -p "$QW"
printf '{"ticket":"T-3","type":"bug","title":"q","branch":"fix","phase":"fix"}\n' > "$QW/meta.json"
printf '## panel\n- publish_cmd: cat > "%s/published.json"\n' "$BASE" > "$Q/FLOW.md"
reset() { rm -f "$QW/panel-answered.json"; printf '%s\n' "$1" > "$QW/panel-input.json"; node "$CLI" panel --repo "$Q" >/dev/null 2>&1; rm -f "$BASE/published.json" "$BASE/calls"; }
ask() { printf '{"cwd":"%s","hook_event_name":"PostToolUse","tool_name":"%s","tool_input":%s,"tool_response":%s}' "$Q" "$1" "$2" "$3" | sh "$HOOK"; rc=$?; }
cleared() { for _ in $(seq 1 50); do grep -q '"decision"' "$QW/panel.json" || return 0; sleep 0.1; done; return 1; }
untouched() { sleep 0.3; [ ! -f "$BASE/calls" ] && [ ! -f "$QW/panel-answered.json" ] && grep -q '"decision"' "$QW/panel.json"; }
NOQ='{"questions":[{"question":"Q?"}]}'
DEC='{"now":"MR 2","next":"review","decision":"confirm the summary","attention":"wait","blocks":[{"text":"sibling"}],"labels":{"decision":"Decisión"}}'

reset "$DEC"
FLOW_PANEL_CLI="$BASE/fakecli" ask AskUserQuestion "$NOQ" '{"questions":[],"answers":{},"annotations":{},"afkTimeoutMs":60000}'
[ "$rc" = 0 ] && untouched && ok "a question nobody answered leaves the decision" || bad "an unanswered question touched the panel"

reset "$DEC"; before=$(cat "$QW/panel-input.json")
ask AskUserQuestion "$NOQ" '{"questions":[{"question":"Q?"}],"answers":{"Q?":"Yes"},"annotations":{}}'
cleared && ok "an answered question clears the decision with no file changed" || bad "answered question left the decision on the panel"
grep -q '"attention": "wait"' "$QW/panel.json" && bad "answered question left attention wait" || ok "and the panel no longer waits on the user"
[ "$before" = "$(cat "$QW/panel-input.json")" ] && grep -q '"MR 2"' "$QW/panel.json" && grep -q 'sibling' "$QW/panel.json" && ok "the input is untouched; Now and blockers stay on the panel" || bad "the input was rewritten or lost fields"
for _ in $(seq 1 30); do [ -f "$BASE/published.json" ] && break; sleep 0.1; done
[ -f "$BASE/published.json" ] && ! grep -q '"decision"' "$BASE/published.json" && ! grep -q '"attention":"wait"' "$BASE/published.json" && ok "publish_cmd gets the cleared panel" || bad "publish_cmd did not get the cleared panel"

reset '{"now":"MR 3","labels":{"decision":"Decisión"}}'
FLOW_PANEL_CLI="$BASE/fakecli" ask AskUserQuestion "$NOQ" '{"answers":{"Q?":"Yes"}}'; sleep 0.3
[ ! -f "$BASE/calls" ] && ok "an answer with no decision on the panel (only a label) launches nothing" || bad "rendered for an input with no decision"

reset "$DEC"
FLOW_PANEL_CLI="$BASE/fakecli" ask AskUserQuestion '{"questions":[{"question":"Is \"answers\": {\"x\": \"y\"} valid?"}]}' '{"questions":[{"question":"Is \"answers\": {\"x\": \"y\"} valid?"}],"answers":{},"afkTimeoutMs":60000}'
[ "$rc" = 0 ] && untouched && ok "answer-shaped text inside a question is not an answer" || bad "question text was taken for an answer"

reset '{"now":"plan","decision":"pick a colour","attention":"wait"}'
ask request_user_input '{"questions":[]}' '"{\"answers\":{\"color\":{\"answers\":[\"Blue\"]}}}"'
cleared && ok "Codex: an answered request_user_input clears the decision" || bad "Codex answer left the decision"

reset '{"now":"plan","decision":"pick a colour","attention":"wait"}'
FLOW_PANEL_CLI="$BASE/fakecli" ask request_user_input '{"questions":[]}' '"{\"answers\":{\"color\":{\"answers\":[]}}}"'
[ "$rc" = 0 ] && untouched && ok "Codex: an empty answer list is not an answer" || bad "Codex empty answers cleared the decision"

reset '{"now":"plan","decision":"pick a colour"}'
start=$(date +%s%N); FLOW_PANEL_CLI="$BASE/fakecli" ask Edit '{"filePath":"x"}' '{}'; ms=$(( ($(date +%s%N) - start) / 1000000 ))
untouched && ok "any other tool leaves the decision (${ms} ms)" || bad "another tool cleared or rendered"
FLOW_PANEL_CLI="$BASE/fakecli" ask Write '{"content":"\"tool_name\":\"AskUserQuestion\" \"answers\":{\"Q?\":\"Yes\"}"}' '{}'
untouched && ok "a file that only mentions the question tool is not an answer" || bad "text naming AskUserQuestion was taken for an answer"

reset "$DEC"
ask AskUserQuestion "$NOQ" '{"answers":{"Q?":"Yes"}}'; cleared
sleep 1; printf '{"now":"MR 2","decision":"pick the next one"}\n' > "$QW/panel-input.json"
fire "$Q"; for _ in $(seq 1 50); do grep -q 'pick the next one' "$QW/panel.json" && break; sleep 0.1; done
grep -q 'pick the next one' "$QW/panel.json" && grep -q '"attention": "wait"' "$QW/panel.json" && ok "a decision written after the answer asks again" || bad "the next decision was swallowed by the old answer"

[ "$fails" = 0 ] && echo "panel-refresh: all ok" || { echo "panel-refresh: $fails failure(s)"; exit 1; }
