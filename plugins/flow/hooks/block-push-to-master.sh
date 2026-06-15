#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Blocks dangerous git pushes to master/main.
# Receives the JSON event on stdin; exit 2 aborts the tool and returns the reason to the agent.

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null || true)

# We only care if the command contains a 'git push' (covers 'rtk git push', 'rtk proxy git push', etc.)
echo "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# 1) You are standing on master/main
if [ "$branch" = "master" ] || [ "$branch" = "main" ]; then
  echo "BLOCKED: push from '$branch'. Do not push from the main branch. Switch to a work branch (git switch -c PROJ-XXXXX-slug --no-track origin/master)." >&2
  exit 2
fi

# 2) master/main appears as a loose token (HEAD:master, origin master, refs/heads/master, master:master…)
#    We already know there is a 'git push' in the command, so a loose 'master'/'main' token is dangerous.
if echo "$cmd" | grep -qE '(^|[[:space:]]|:|/)(master|main)([[:space:]]|:|$)'; then
  echo "BLOCKED: the push references master/main. Push to your branch: 'git push -u origin HEAD'." >&2
  exit 2
fi

# 3) Blind push ('git push' / 'git push origin') with the upstream pointing at master/main
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
if { [ "$upstream" = "origin/master" ] || [ "$upstream" = "origin/main" ]; } \
   && echo "$cmd" | grep -qE 'git[[:space:]]+push([[:space:]]+origin)?[[:space:]]*$'; then
  echo "BLOCKED: upstream='$upstream'; a blind push would go to $upstream. Fix it with 'git branch --unset-upstream' and use 'git push -u origin HEAD'." >&2
  exit 2
fi

exit 0
