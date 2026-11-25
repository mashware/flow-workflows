#!/usr/bin/env sh
# flow plugin — UserPromptSubmit hook: name the session after the work on this branch.
# A terminal that follows the session title (Ivy does) shows the console as the phrase Claude
# Code generated from the conversation, although flow already knows the task. This hands it
# `<ticket> <title>` as the session title — the same slot `/rename` writes.
#
# Claude Code lets a hook overwrite any title, a person's `/rename` included, so the guard is
# here: the hook sees the session's custom title in `session_title` (absent while there is
# none) and acts only when it is absent or is a name this hook set itself before — kept in a
# short list, so a resumed or forked session still recognises its own. Anything else was set
# by somebody else and is left alone. UserPromptSubmit only:
# at SessionStart the title is not reported, so a resumed session's own name could not be
# told from nothing.
#
# Runs on every prompt of every session in every repo the plugin is installed in: no work
# for this branch and a prompt that is not a start → exit at once, silent. The one prompt
# that is a start (`/flow:feat:start 258`) names the console after its identifier, because
# the work does not exist yet and the next prompt would be too late for the first screen. No jq (same reasons as session-start.sh); every
# failure exits 0 and prints nothing.

event=$(cat 2>/dev/null || printf '')

# First "key": "value" of a JSON text, the raw string body. grep -o lists the matches in
# order, so the first one is the first in the file, even on a single line.
jraw() { # <key> <text>
	printf '%s' "$2" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\\\]\|\\\\.\)*\)\"" | head -1 | sed "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
}
# The simple escapes back to text; a \uXXXX cannot be decoded without a JSON tool, so it
# becomes `?` rather than a half sequence that would break the output.
junesc() {
	_p=$(printf '\001')
	sed -e "s/\\\\\\\\/$_p/g" -e 's/\\u[0-9A-Fa-f]\{4\}/?/g; s/\\[nrt]/ /g; s/\\"/"/g; s/\\\//\//g' -e "s/$_p/\\\\/g"
}
# Back to a JSON string body: only `\` and `"` need an escape once control characters are gone.
jesc() {
	tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cwd=$(jraw cwd "$event" | junesc)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD

command -v git >/dev/null 2>&1 || exit 0
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '')

main_root=""
common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || printf '')
if [ -n "$common" ]; then
	case "$common" in
	/*) ;;
	*) common="$root/$common" ;;
	esac
	common=$(cd "$common" 2>/dev/null && pwd || printf '')
	case "$common" in
	*/.git) main_root=${common%/.git} ;;
	esac
fi

# The work this branch belongs to: the same rule as session-start.sh and /flow:next §1, with
# the branch and the path matched literally.
bre=$(printf '%s' "$branch" | sed 's/[][\.*^$/]/\\&/g')
rre=$(printf '%s' "$root" | sed 's/[][\.*^$/]/\\&/g')
meta=""
for r in "$root" "$main_root"; do
	[ -n "$r" ] && [ -d "$r/.claude/work" ] || continue
	for candidate in "$r"/.claude/work/*/meta.json; do
		[ -f "$candidate" ] || continue
		if [ -n "$branch" ] && grep -q "\"branch\"[[:space:]]*:[[:space:]]*\"$bre\"" "$candidate" 2>/dev/null; then
			meta=$candidate
			break
		fi
		if grep -q "\"worktree\"[[:space:]]*:[[:space:]]*\"$rre\"" "$candidate" 2>/dev/null; then
			meta=$candidate
			break
		fi
	done
	[ -n "$meta" ] && break
done
if [ -n "$meta" ]; then
	metatext=$(cat "$meta" 2>/dev/null || printf '')
	ticket=$(jraw ticket "$metatext" | junesc | tr -d '\000-\037')
	slug=$(jraw slug "$metatext" | junesc | tr -d '\000-\037')
	title=$(jraw title "$metatext" | junesc | tr -d '\000-\037')
else
	# No work on this branch yet. The prompt that starts one — `/flow:feat:start 258` — is the
	# only moment the console could be named, and the work's title is not known until the
	# command has read the ticket, so the identifier it was given stands in for it until the
	# next prompt finds the work. A start with no identifier names nothing.
	prompt=$(jraw prompt "$event" | junesc)
	set -f
	# shellcheck disable=SC2086
	set -- $prompt
	set +f
	case ${1:-} in
	/flow:feat:start | /flow:bug:start) ;;
	*) exit 0 ;;
	esac
	shift
	ticket=""
	for word in "$@"; do
		case $word in
		-*) continue ;;
		esac
		ticket=$word
		break
	done
	case $ticket in
	'#'[0-9]* | [0-9]* | [A-Za-z][A-Za-z0-9]*-[0-9]*) ;;
	*) exit 0 ;;
	esac
	ticket=$(printf '%s' "$ticket" | tr -d '\000-\037')
	slug=""
	title=""
fi

# A bare issue number reads as `#258`; a slug is not an identifier worth showing.
case $ticket in
'' | "$slug") ticket="" ;;
*[!0-9]*) ;;
*) ticket="#$ticket" ;;
esac
name=$(printf '%s %s' "$ticket" "$title" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
[ -n "$name" ] || exit 0

# Ivy refuses a title over 128 characters. 120 bytes is inside it in any encoding, and the
# limit is on the whole name, ticket included. The cut never leaves half a character and
# needs no particular locale: iconv drops a broken tail, and without it the non-ASCII tail goes.
if [ "$(printf '%s' "$name" | wc -c)" -gt 120 ]; then
	cut=$(printf '%s' "$name" | LC_ALL=C cut -b1-118)
	if command -v iconv >/dev/null 2>&1; then
		cut=$(printf '%s' "$cut" | iconv -c -f UTF-8 -t UTF-8 2>/dev/null)
	else
		cut=$(printf '%s' "$cut" | LC_ALL=C sed 's/[^ -~]*$//')
	fi
	name="$cut…"
fi

current=$(jraw session_title "$event" | junesc)
statedir=${CLAUDE_PLUGIN_DATA:-${HOME:-}/.cache/flow}
[ -n "$statedir" ] && [ "$statedir" != "/.cache/flow" ] || exit 0
setfile=$statedir/session-titles

# Somebody else's title — empty is nobody's, ours is ours.
if [ -n "$current" ] && [ "$current" != "$name" ] && ! grep -qxF -- "$current" "$setfile" 2>/dev/null; then
	exit 0
fi

{
	mkdir -p "$statedir"
	if [ "$(tail -n 1 "$setfile" 2>/dev/null)" != "$name" ]; then
		{ grep -vxF -- "$name" "$setfile" 2>/dev/null; printf '%s\n' "$name"; } | tail -n 200 >"$setfile.$$" && mv "$setfile.$$" "$setfile"
	fi
} 2>/dev/null
[ "$current" = "$name" ] && exit 0
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}' "$(printf '%s' "$name" | jesc)"
exit 0
