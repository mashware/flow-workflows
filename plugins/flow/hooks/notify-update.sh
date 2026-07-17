#!/usr/bin/env sh
# flow plugin — SessionStart hook.
# Surfaces a one-line nudge the FIRST session after the installed plugin version
# changes, so the user knows to run /flow:news. Silent otherwise.
#
# Uses its OWN marker (news-notified). It must NEVER touch news-last-seen, which
# /flow:news owns to compute the "what changed since you last looked" delta.
set -eu

PLUGIN_JSON="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
STATE_DIR="${HOME}/.claude/flow"
NOTIFIED="${STATE_DIR}/news-notified"

# No plugin.json → nothing to compare; stay silent.
[ -f "$PLUGIN_JSON" ] || exit 0

# Extract "version": "x.y.z" without a jq dependency.
cur=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_JSON" | head -1)
[ -n "$cur" ] || exit 0

mkdir -p "$STATE_DIR"

# First encounter (fresh install): set the baseline silently — do not nag on day one.
if [ ! -f "$NOTIFIED" ]; then
	printf '%s\n' "$cur" > "$NOTIFIED"
	exit 0
fi

prev=$(head -1 "$NOTIFIED" 2>/dev/null || printf '')
if [ "$prev" != "$cur" ]; then
	printf 'flow updated to v%s (was v%s) — run /flow:news to see what changed.\n' "$cur" "$prev"
	printf '%s\n' "$cur" > "$NOTIFIED"
fi

exit 0
