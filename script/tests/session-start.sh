#!/usr/bin/env bash
# Exercise the SessionStart work notice against throwaway repos.
#     bash script/tests/session-start.sh
# Cases: not a repo · no work folder · no work on this branch · a matching work with and
# without a panel · panel and meta disagreeing on the phase · an MR/PR train · an archived
# work alone · an accepted follow-up nobody started · a worktree checkout · an unreadable
# meta.json · the hook run from somewhere other than the session's directory · a compaction
# restoring the brief and plan, capped, degrading when there is none, and never inviting a
# resume of work that is still running.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../../plugins/flow/hooks/session-start.sh"
BASE="${TMPDIR:-/tmp}/flow-session-start-test"
fails=0

run() { # <cwd> [<run-from>] — feed the event the way the harness does
  local from=${2:-$1}
  ( cd "$from" 2>/dev/null || cd /; printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$1" | sh "$HOOK" 2>&1 )
}
runsrc() { # <cwd> <source> — the same event, with the startup source the harness sends
  ( cd "$1" 2>/dev/null || cd /; printf '{"hook_event_name":"SessionStart","cwd":"%s","source":"%s"}' "$1" "$2" | sh "$HOOK" 2>&1 )
}
want() { # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       got=%q\n       want=%q\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
}
contains() { # <label> <actual> <substring>
  case "$2" in *"$3"*) printf '  ok   %s\n' "$1" ;;
  *) printf '  FAIL %s\n       got=%q\n       want to contain=%q\n' "$1" "$2" "$3"; fails=$((fails+1)) ;;
  esac
}

newrepo() { # <name> <branch>
  local d="$BASE/$1"
  rm -rf "$d"; mkdir -p "$d"
  git -C "$d" init -q -b "$2"
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  printf 'x\n' > "$d/f"; git -C "$d" add f; git -C "$d" commit -qm init
  printf '%s' "$d"
}
meta() { # <workdir> <json>
  mkdir -p "$1"; printf '%s\n' "$2" > "$1/meta.json"
}

rm -rf "$BASE"; mkdir -p "$BASE"

# --- silence where there is nothing to say ------------------------------------------------
mkdir -p "$BASE/plain"
want "not a git repo: silent" "$(run "$BASE/plain")" ""

R=$(newrepo repo-empty main)
want "no .claude/work: silent" "$(run "$R")" ""

R=$(newrepo repo-nomatch PROJ-1-slug)
meta "$R/.claude/work/PROJ-9" '{ "ticket": "PROJ-9", "branch": "PROJ-9-other", "size": "S", "phase": "build" }'
want "no work on this branch: silent" "$(run "$R")" ""

# --- the ordinary case --------------------------------------------------------------------
R=$(newrepo repo-match PROJ-1-slug)
meta "$R/.claude/work/PROJ-1" '{ "ticket": "PROJ-1", "branch": "PROJ-1-slug", "size": "S", "phase": "build", "phases_done": ["context"] }'
printf '# PROJ-1\n\nRetry window for failed digests.\n' > "$R/.claude/work/PROJ-1/00-summary.md"
want "matching work, no panel: header + summary line" "$(run "$R")" \
  "PROJ-1 · S · phase build
Last stop: Retry window for failed digests. — /flow:work:resume"

cat > "$R/.claude/work/PROJ-1/panel.json" <<'JSON'
{
  "updated_at": "2026-09-08T22:10:00+02:00",
  "phase": "build",
  "lines": [
    {"text": "Retry window", "style": "title"},
    {"ref": "Now", "text": "unit suite over the footer partial", "mark": "info"}
  ]
}
JSON
want "panel Now wins over the summary" "$(run "$R")" \
  "PROJ-1 · S · phase build
Last stop: unit suite over the footer partial — /flow:work:resume"

# --- panel and meta disagree: a phase that never closed -------------------------------------
sed -i.bak 's/"phase": "build"/"phase": "review"/' "$R/.claude/work/PROJ-1/panel.json"; rm -f "$R/.claude/work/PROJ-1/panel.json.bak"
contains "panel and meta disagree: says which phase was running" "$(run "$R")" "review was still running"

# --- an MR/PR train --------------------------------------------------------------------------
R=$(newrepo repo-train PROJ-2-two)
meta "$R/.claude/work/PROJ-2" '{
  "ticket": "PROJ-2",
  "branch": "PROJ-2-one",
  "size": "M",
  "phase": "review",
  "mrs": [
    { "n": 1, "title": "a", "status": "merged" },
    { "n": 2, "title": "b", "status": "in_progress", "branch": "PROJ-2-two" },
    { "n": 3, "title": "c", "status": "pending" }
  ]
}'
contains "mrs[].branch matches too, and the train is counted" "$(run "$R")" "PROJ-2 · M · phase review · MR #2 of 3"

# --- an archived work is not where you are ---------------------------------------------------
R=$(newrepo repo-archived PROJ-3-slug)
meta "$R/.claude/work/_archive/PROJ-3" '{ "ticket": "PROJ-3", "branch": "PROJ-3-slug", "size": "XS", "phase": "done" }'
want "archived work only: silent" "$(run "$R")" ""

# --- a follow-up somebody accepted and nobody started ------------------------------------------
meta "$R/.claude/work/_archive/PROJ-4" '{
  "ticket": "PROJ-4",
  "branch": "PROJ-4-slug",
  "phase": "done",
  "followups": [
    { "id": "F1", "title": "backfill the counters", "status": "declined", "work": null },
    { "id": "F2", "title": "index the lookup", "status": "accepted", "work": null }
  ]
}'
want "accepted follow-up, no work on this branch: one line" "$(run "$R")" \
  "Also: F2 from PROJ-4 accepted and never started — /flow:work:status"

meta "$R/.claude/work/_archive/PROJ-5" '{
  "ticket": "PROJ-5", "phase": "done",
  "followups": [ { "id": "F1", "title": "x", "status": "accepted", "work": null } ]
}'
contains "several accepted follow-ups: still one line, with a count" "$(run "$R")" "more) — /flow:work:status"

# --- a worktree: the branch is here, the work folder is in the main checkout ---------------------
R=$(newrepo repo-worktree main)
meta "$R/.claude/work/PROJ-6" '{ "ticket": "PROJ-6", "branch": "PROJ-6-slug", "size": "L", "phase": "design" }'
git -C "$R" worktree add -q -b PROJ-6-slug "$R/.worktrees/PROJ-6-slug" >/dev/null 2>&1
contains "worktree checkout: resolves the work from the main checkout" "$(run "$R/.worktrees/PROJ-6-slug")" \
  "PROJ-6 · L · phase design"

# --- degraded, never silent -----------------------------------------------------------------------
R=$(newrepo repo-broken PROJ-7-slug)
mkdir -p "$R/.claude/work/PROJ-7"
printf '{ "branch": "PROJ-7-slug", ' > "$R/.claude/work/PROJ-7/meta.json"
want "unreadable meta.json: the one line that is still true" "$(run "$R")" \
  "A work exists on this branch — /flow:work:resume"

# --- the directory comes from the event, not from where the hook runs -------------------------------
R=$(newrepo repo-cwd PROJ-8-slug)
meta "$R/.claude/work/PROJ-8" '{ "ticket": "PROJ-8", "branch": "PROJ-8-slug", "size": "XS", "phase": "build" }'
contains "run from /, reads the session's directory" "$(run "$R" /)" "PROJ-8 · XS · phase build"

# --- a compaction: the contract, not the whereabouts ------------------------------------------------
# `source: compact` means the turn survived and only the context did not, so the brief and the
# plan `build` holds itself to are what the session lost — and `/flow:work:resume` would be an
# invitation to restart something already in flight.
R=$(newrepo repo-compact PROJ-10-slug)
meta "$R/.claude/work/PROJ-10" '{ "ticket": "PROJ-10", "branch": "PROJ-10-slug", "size": "M", "phase": "build" }'
cat > "$R/.claude/work/PROJ-10/05-implementation.md" <<'EOF'
# Implementation PROJ-10

## Brief MR/PR #1
- The user will be able to unsubscribe from the digest.

**This MR/PR does NOT include**:
- the preference centre rework

## Plan MR/PR #1
1. footer partial — `templates/digest.html.twig` — covered by step 2
2. opt-out check — `src/Mailer/DigestMailer.php` — DigestMailerTest

- **Point of no return**: none.
- **Out of this plan**: the preference centre.

## Changes per file
- templates/digest.html.twig — the footer link
EOF
out=$(runsrc "$R" compact)
contains "compaction: restores the brief" "$out" "The user will be able to unsubscribe"
contains "compaction: restores what is out of scope" "$out" "the preference centre rework"
contains "compaction: restores the numbered plan" "$out" "src/Mailer/DigestMailer.php"
contains "compaction: labels it a record, not an instruction" "$out" "not a new instruction"
contains "compaction: still says where the work is" "$out" "PROJ-10 · M · phase build"
case "$out" in
  *"/flow:work:resume"*) printf '  FAIL %s\n' "compaction: never invites a resume"; fails=$((fails+1)) ;;
  *) printf '  ok   %s\n' "compaction: never invites a resume" ;;
esac
case "$out" in
  *"Changes per file"*) printf '  FAIL %s\n' "compaction: stops at the contract"; fails=$((fails+1)) ;;
  *) printf '  ok   %s\n' "compaction: stops at the contract" ;;
esac

# The same repo, opened normally: the ordinary notice, contract untouched.
out=$(runsrc "$R" startup)
contains "a normal start is unchanged by the contract being there" "$out" "/flow:work:resume"
case "$out" in
  *"unsubscribe from the digest"*) printf '  FAIL %s\n' "a normal start does not print the contract"; fails=$((fails+1)) ;;
  *) printf '  ok   %s\n' "a normal start does not print the contract" ;;
esac

# A plan longer than the cap is truncated, not poured into the turn.
R=$(newrepo repo-compact-long PROJ-11-slug)
meta "$R/.claude/work/PROJ-11" '{ "ticket": "PROJ-11", "branch": "PROJ-11-slug", "size": "L", "phase": "build" }'
{ printf '## Brief MR/PR #1\n'; i=0; while [ $i -lt 90 ]; do printf -- '- line %s\n' "$i"; i=$((i+1)); done; } \
  > "$R/.claude/work/PROJ-11/05-implementation.md"
out=$(runsrc "$R" compact)
contains "a long contract is capped" "$out" "truncated"
want "capped at 60 lines of contract plus the header" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "66"

# A bug keeps the same contract in `04-fix.md` under a plain `## Brief`, and loses it to a
# compaction exactly like a feature does.
R=$(newrepo repo-compact-bug PROJ-13-slug)
meta "$R/.claude/work/PROJ-13" '{ "ticket": "PROJ-13", "type": "bug", "branch": "PROJ-13-slug", "size": "S", "phase": "fix" }'
cat > "$R/.claude/work/PROJ-13/04-fix.md" <<'EOF'
# Fix PROJ-13

## Brief
**What stops happening after the fix**:
- the digest is sent twice on a retry

**What is NOT touched**:
- the retry policy itself

## Plan
1. failing test — `tests/DigestRetryTest.php` — proves the double send
2. idempotency key — `src/Mailer/DigestMailer.php` — covered by step 1

- **Point of no return**: none.

## Fix description
The fix consists of an idempotency key.
EOF
out=$(runsrc "$R" compact)
contains "a bug's brief is restored too" "$out" "sent twice on a retry"
contains "a bug's out-of-scope is restored" "$out" "the retry policy itself"
contains "and it names the file it came from" "$out" "04-fix.md — a record"
contains "a bug's plan is restored with its brief" "$out" "tests/DigestRetryTest.php"
case "$out" in
  *"The fix consists of"*) printf '  FAIL %s\n' "a bug's contract stops at the brief"; fails=$((fails+1)) ;;
  *) printf '  ok   %s\n' "a bug's contract stops at the brief" ;;
esac

# Before build there is no contract: the header still orients, the resume line stays away.
R=$(newrepo repo-compact-early PROJ-12-slug)
meta "$R/.claude/work/PROJ-12" '{ "ticket": "PROJ-12", "branch": "PROJ-12-slug", "size": "M", "phase": "design" }'
out=$(runsrc "$R" compact)
contains "no contract yet: still says where the work is" "$out" "PROJ-12 · M · phase design"
case "$out" in
  *"/flow:work:resume"*) printf '  FAIL %s\n' "no contract yet: still no resume invitation"; fails=$((fails+1)) ;;
  *) printf '  ok   %s\n' "no contract yet: still no resume invitation" ;;
esac

rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "session-start: all cases pass"; else echo "session-start: $fails failure(s)"; exit 1; fi
