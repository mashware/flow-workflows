#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Blocks dangerous git pushes to master/main.
# Receives the JSON event on stdin; exit 2 aborts the tool and returns the reason to the agent.

event=$(cat)

# jq parses the event. Without it there is no command to inspect — and a guard that
# cannot read its input must not report "nothing dangerous here": that is how the
# hook silently stopped guarding anything. Fall back to a crude grep for a push and
# block on it, so a missing dependency costs a false positive rather than a deploy.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  if printf '%s' "$event" | grep -qE 'git[[:space:]]+push'; then
    echo "BLOCKED: this hook needs 'jq' to inspect the command and jq is not installed, so it cannot tell a safe push from a push to the main branch. Install jq, or run the push yourself after checking the target branch." >&2
    exit 2
  fi
  exit 0
fi

# A heredoc body is DATA, not command: a commit message quoting 'git push origin master'
# is prose about a push, not a push, and blocking it stops the very commit that documents
# it. Drop the body — between the marker and its closing line — and keep everything else,
# so a push chained after the heredoc is still judged.
cmd=$(printf '%s' "$cmd" | awk '
  !inbody {
    if (match($0, /<<-?[ \t]*[\047\042]?[A-Za-z_][A-Za-z0-9_]*[\047\042]?/)) {
      marker = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[ \t]*[\047\042]?/, "", marker)
      sub(/[\047\042]$/, "", marker)
      inbody = 1
    }
    print
    next
  }
  {
    line = $0
    sub(/^[ \t]+/, "", line)
    if (line == marker) inbody = 0
  }
')

# Fast exit for the overwhelming majority of commands. Covers 'rtk git push',
# 'rtk proxy git push', and any wrapper that ends up invoking one.
echo "$cmd" | grep -qE 'git[[:space:]]+push' || exit 0

# The branch that decides is the one in the directory the push RUNS in, not the one in the
# session's directory. With worktrees — the layout this plugin prescribes — the main checkout
# sits on the main branch while the branch being pushed is checked out somewhere else, so
# reading HEAD here blocked every legitimate push from a worktree. Start from the session's
# directory and let 'cd <path>' and 'git -C <path>' move it, the way the shell would.
base_dir=$(printf '%s' "$event" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$base_dir" ] && [ -d "$base_dir" ] || base_dir=$PWD

# A path only a shell could resolve (a variable, a glob, '-', '~') leaves the directory where
# it was. That is the conservative answer: the session's checkout is the one that tends to be
# sitting on the main branch, so an unresolvable path errs towards blocking, never towards
# waving a push through.
resolve_dir() {
  local from=$1 path=$2
  path=${path%\"}; path=${path#\"}
  path=${path%\'}; path=${path#\'}
  case $path in
    ''|-|~*|*'$'*|*'*'*|*'`'*) printf '%s' "$from" ;;
    /*) if [ -d "$path" ]; then printf '%s' "$path"; else printf '%s' "$from"; fi ;;
    *)  if [ -d "$from/$path" ]; then printf '%s' "$from/$path"; else printf '%s' "$from"; fi ;;
  esac
}

# Judge each push on its own. A command chains several things — only the segments that
# actually run a push are evidence, so 'git commit -m "sync master fixes" && git push -u
# origin HEAD' is a safe push next to an unrelated mention of the main branch, and every
# push in a chain gets checked rather than just the last one. The separator is kept at the
# head of the segment it introduces, so a 'cd' that may never run can be told apart.
segments=$(printf '%s' "$cmd" | tr '\n' ';' | sed -E 's/(\&\&|\|\||\||;)/\n\1 /g')

judge() {
  local seg=$1 dir=$2

  # 'git -C <path>' aims this one push at another checkout whatever the directory is.
  if [[ $seg =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
    dir=$(resolve_dir "$dir" "${BASH_REMATCH[1]}")
  fi

  # 1) The push runs on master/main — nothing it sends is what you meant.
  local branch
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ "$branch" = "master" ] || [ "$branch" = "main" ]; then
    echo "BLOCKED: push from '$branch' (in $dir). Do not push from the main branch. Switch to a work branch (git switch -c PROJ-XXXXX-slug --no-track origin/master), or run the push where that branch is checked out ('git -C <worktree> push -u origin HEAD')." >&2
    return 2
  fi

  # A directory can be named after the main branch ('.worktrees/main', a clone in ~/src/master).
  # Those words name a path, not a ref, so the path arguments leave before the branch is looked
  # for as a token — otherwise pushing from such a worktree is refused for its spelling.
  local refs
  refs=$(printf '%s' "$seg" | sed -E 's/(^|[[:space:]])(-C|cd)[[:space:]]+[^[:space:]]+//g')

  # 2) master/main as a loose token (HEAD:master, origin master, refs/heads/master…).
  if echo "$refs" | grep -qE '(^|[[:space:]]|:|/)(master|main)([[:space:]]|:|$)'; then
    echo "BLOCKED: the push references master/main. Push to your branch: 'git push -u origin HEAD'." >&2
    return 2
  fi

  # 3) --all/--mirror push every branch, carrying the main branch along whatever the
  #    upstream says.
  if echo "$seg" | grep -qE '[[:space:]](--all|--mirror)([[:space:]]|$)' \
     && { git -C "$dir" show-ref --verify --quiet refs/heads/master 2>/dev/null \
          || git -C "$dir" show-ref --verify --quiet refs/heads/main 2>/dev/null; }; then
    echo "BLOCKED: '--all'/'--mirror' pushes every branch, the main branch included. Push only your branch: 'git push -u origin HEAD'." >&2
    return 2
  fi

  # 4) A push with NO explicit refspec, with the upstream pointing at master/main.
  #    Matching only a command that *ended* in 'git push [origin]' was the original bug:
  #    every flag pushed the match off the end, so 'git push --force' — the most
  #    destructive form — walked straight through the check written for it. So strip the
  #    flags and see whether a refspec was actually given.
  local args stripped remaining threshold upstream
  args=$(printf '%s' "$seg" | sed -E 's/.*git[[:space:]]+push//')

  # Only these four take their value as a SEPARATE word; the rest of git push's options
  # attach it with '=', so treating them as value-taking would swallow the remote and
  # make an explicit push look like a bare one.
  stripped=$(printf '%s\n' $args | awk '
    skip { skip = 0; next }
    /^-/ {
      if ($0 ~ /^(-o|--push-option|--repo|--receive-pack|--exec)$/) skip = 1
      next
    }
    { print }
  ')

  # What remains is [<remote>] [<refspec>…] — unless --repo supplied the remote, in which
  # case every remaining word is a refspec. One bare word is the remote alone → no refspec.
  if echo "$seg" | grep -qE '(^|[[:space:]])--repo([[:space:]]|=)'; then
    threshold=0
  else
    threshold=1
  fi
  remaining=$(printf '%s\n' $stripped | grep -c .)

  if [ "$remaining" -le "$threshold" ]; then
    upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "")
    if [ "$upstream" = "origin/master" ] || [ "$upstream" = "origin/main" ]; then
      echo "BLOCKED: upstream='$upstream'; this push names no refspec, so it would resolve to $upstream. Fix it with 'git branch --unset-upstream' and use 'git push -u origin HEAD'." >&2
      return 2
    fi
  fi
  return 0
}

cur_dir=$base_dir
while IFS= read -r segment; do
  # A 'cd' moves every command after it, so the tracked directory moves with it — except
  # behind '||', where the shell runs it only if the previous command failed. Trusting that
  # one could hand a push the directory it never reached; ignoring it keeps the checkout we
  # know about, which is the strict side.
  if [ "${segment#||}" = "$segment" ]; then
    trimmed=$(printf '%s' "$segment" | sed -E 's/^[[:space:]]*(\&\&|;|\|)?[[:space:]]*\(*[[:space:]]*//')
    case $trimmed in
      cd[[:space:]]*)
        cur_dir=$(resolve_dir "$cur_dir" "$(printf '%s' "$trimmed" | awk '{print $2}')")
        ;;
    esac
  fi
  echo "$segment" | grep -qE 'git[[:space:]]+push' || continue
  judge "$segment" "$cur_dir" || exit 2
done <<SEGMENTS
$segments
SEGMENTS

exit 0
