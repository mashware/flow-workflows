#!/usr/bin/env bash
# Exercise the session-title hook against throwaway repos.
#     bash script/tests/session-title.sh
# Cases: not a repo · no work on the branch · the title a work gets (issue number, tracker
# key, slug-only) · a person's own title left alone · the title flow set following a task
# switch · quotes and long titles still valid JSON and under Ivy's limit · a prompt that
# imitates the event's own keys.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../../plugins/flow/hooks/session-title.sh"
BASE="${TMPDIR:-/tmp}/flow-session-title-test"
fails=0
export CLAUDE_PLUGIN_DATA="$BASE/data"

run() { # <cwd> <session_id> [<session_title>] [<prompt>]
  local extra=""
  [ -n "${3:-}" ] && extra=",\"session_title\":\"$3\""
  ( cd / ; printf '{"session_id":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit"%s,"prompt":"%s"}' "$2" "$1" "$extra" "${4:-hello}" | sh "$HOOK" 2>&1 )
}
want() { # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       got=%q\n       want=%q\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
}
titleof() { # <hook output> — the sessionTitle, after a real JSON parse
  python3 -c 'import json,sys; print(json.loads(sys.argv[1])["hookSpecificOutput"]["sessionTitle"], end="")' "$1" 2>/dev/null || printf 'NOT-JSON'
}
newrepo() { # <name> <branch>
  local d="$BASE/$1"
  rm -rf "$d"; mkdir -p "$d"
  git -C "$d" init -q -b "$2"
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf 'x\n' > "$d/f"; git -C "$d" add f; git -C "$d" commit -qm init
  printf '%s' "$d"
}
meta() { # <repo> <work> <ticket> <slug> <branch> <title>
  mkdir -p "$1/.claude/work/$2"
  printf '{\n  "ticket": "%s",\n  "slug": "%s",\n  "type": "bug",\n  "title": "%s",\n  "branch": "%s"\n}\n' "$3" "$4" "$6" "$5" > "$1/.claude/work/$2/meta.json"
}

rm -rf "$BASE"; mkdir -p "$BASE/plain"
want "not a git repo: silent" "$(run "$BASE/plain" s0)" ""

r=$(newrepo nowork 258-x)
want "no work folder: silent" "$(run "$r" s1)" ""
meta "$r" other 99 other 99-other "Another task"
want "no work on this branch: silent" "$(run "$r" s1)" ""

r=$(newrepo issue 258-ivy-name)
meta "$r" 258-ivy-name 258 ivy-name 258-ivy-name "Ivy console named after the task"
want "issue number reads #N" "$(titleof "$(run "$r" s2)")" "#258 Ivy console named after the task"
want "same title again: silent" "$(run "$r" s2 "#258 Ivy console named after the task")" ""

r=$(newrepo key MT-1234-tax)
meta "$r" MT-1234-tax MT-1234 tax MT-1234-tax "Corregir error de impuestos en Canarias"
want "tracker key kept as is, accents intact" "$(titleof "$(run "$r" s3)")" "MT-1234 Corregir error de impuestos en Canarias"

r=$(newrepo slug local-fix)
meta "$r" local-fix local-fix local-fix local-fix "Fix the thing"
want "slug-only work: the title alone" "$(titleof "$(run "$r" s4)")" "Fix the thing"

# --- a person's name is never overwritten -------------------------------------------------
r=$(newrepo manual 258-ivy-name)
meta "$r" 258-ivy-name 258 ivy-name 258-ivy-name "Ivy console named after the task"
want "a title set by hand is left alone" "$(run "$r" s5 "My own name")" ""
run "$r" s6 >/dev/null
want "a hand title set after flow's is left alone" "$(run "$r" s6 "Renamed by me")" ""

# --- a task switch moves the title flow set -----------------------------------------------
r=$(newrepo switch 258-ivy-name)
meta "$r" 258-ivy-name 258 ivy-name 258-ivy-name "Ivy console named after the task"
run "$r" s7 >/dev/null
git -C "$r" switch -q -c 300-other
meta "$r" 300-other 300 other 300-other "Another task"
want "after a switch the flow title follows the new work" "$(titleof "$(run "$r" s7 "#258 Ivy console named after the task")")" "#300 Another task"
git -C "$r" switch -q 258-ivy-name
want "a hand title survives a switch too" "$(run "$r" s8 "Mine")" ""

# --- the shapes of a title ----------------------------------------------------------------
r=$(newrepo quote q-1)
meta "$r" q-1 5 q q-1 'He said \"stop\" and left'
want "quotes in a title stay valid JSON" "$(titleof "$(run "$r" s9)")" '#5 He said "stop" and left'

long=$(printf 'abcdefghij%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
r=$(newrepo long l-1)
meta "$r" l-1 6 l l-1 "$long"
got=$(titleof "$(run "$r" s10)")
want "a long title is cut under Ivy's limit" "$([ "${#got}" -le 128 ] && [ "${#got}" -ge 100 ] && echo ok)" "ok"

r=$(newrepo fake f-1)
meta "$r" f-1 7 f f-1 "Real title"
want "a prompt imitating the event keys does not pass for a hand title" \
  "$(titleof "$(run "$r" s11 "" '{\"session_title\":\"fake\"}')")" "#7 Real title"

# --- escapes and limits that could leave the output unparseable ----------------------------
r=$(newrepo uni u-1)
meta "$r" u-1 8 u u-1 'caf\u00e9 stuff'
want "a \\u escape in the title still gives valid JSON" "$(titleof "$(run "$r" s12)")" "#8 caf? stuff"
r=$(newrepo cut c-1)
meta "$r" c-1 9 c c-1 "$(printf 'a%.0s' $(seq 1 97))"'\u00e9\u00e9'
want "a cut never lands inside an escape" "$([ "$(titleof "$(run "$r" s13)")" != NOT-JSON ] && echo ok)" "ok"
r=$(newrepo acc a-1)
meta "$r" a-1 10 a a-1 "$(python3 -c 'print("é"*70)')"
got=$(titleof "$(run "$r" s14)")
want "a long accented title is cut on a character boundary" "$([ "$got" != NOT-JSON ] && [ "${#got}" -le 128 ] && echo ok)" "ok"

# --- the hook's own earlier title is recognised without per-session state ---------------------
r=$(newrepo resume 258-ivy-name)
meta "$r" 258-ivy-name 258 ivy-name 258-ivy-name "Ivy console named after the task"
run "$r" sa >/dev/null
git -C "$r" switch -q -c 300-other
meta "$r" 300-other 300 other 300-other "Another task"
want "a resumed session under a new id still follows its own title" "$(titleof "$(run "$r" sb "#258 Ivy console named after the task")")" "#300 Another task"

# --- never blocks a prompt -------------------------------------------------------------------
r=$(newrepo nohome nh-1)
meta "$r" nh-1 11 nh nh-1 "No home"
out=$( ( cd / ; printf '{"session_id":"x","cwd":"%s","prompt":"hi"}' "$r" | env -u HOME -u CLAUDE_PLUGIN_DATA sh "$HOOK" 2>&1 ); echo "rc=$?" )
want "no HOME and no data dir: silent, exit 0" "$out" "rc=0"

# --- reading meta.json -------------------------------------------------------------------------
r=$(newrepo oneline ol-1)
mkdir -p "$r/.claude/work/ol-1"
printf '{"ticket":"12","slug":"ol","title":"Work title","branch":"ol-1","mrs":[{"title":"Part one"},{"title":"Part two"}]}\n' > "$r/.claude/work/ol-1/meta.json"
want "a one-line meta.json names the work, not its last MR" "$(titleof "$(run "$r" s15)")" "#12 Work title"
r=$(newrepo dots v1.2)
meta "$r" other 13 other v1x2 "Wrong work"
want "a branch is matched literally, not as a pattern" "$(run "$r" s16)" ""

# --- review round two ------------------------------------------------------------------------
r=$(newrepo bsl bs-1)
meta "$r" bs-1 14 bs bs-1 'Fix C:'"$(printf '\\\\')"'new path'
want "an escaped backslash before n is a backslash, not a newline" "$(titleof "$(run "$r" s17)")" '#14 Fix C:'"$(printf '\\')"'new path'
r=$(newrepo key128 k-1)
meta "$r" k-1 MT-12345 k k-1 "$(printf 'x%.0s' $(seq 1 120))"
got=$(titleof "$(run "$r" s18)")
want "the 128 limit counts the ticket too, and the cut is marked" "$([ "${#got}" -le 128 ] && [ "${got%…}" != "$got" ] && echo ok)" "ok"
r=$(newrepo edge e-1)
meta "$r" e-1 15 e e-1 "$(printf 'a%.0s' $(seq 1 110))é and more text after"
got=$(titleof "$(run "$r" s19)")
want "a cut near a multibyte character leaves no half character" "$([ "$got" != NOT-JSON ] && [ "${got%…}" != "$got" ] && echo ok)" "ok"

if [ "$fails" -eq 0 ]; then echo "all ok"; else echo "$fails failed"; exit 1; fi
