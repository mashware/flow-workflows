#!/usr/bin/env bash
# Exercise the SessionStart update notice against a throwaway HOME and plugin root.
#     bash script/tests/notify-update.sh
# Cases: fresh install is silent and sets the baseline · same version is silent · a
# version change prints one line and moves the baseline · news-last-seen is never
# touched · a missing plugin.json is silent.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../../plugins/flow/hooks/notify-update.sh"
BASE="${TMPDIR:-/tmp}/flow-notify-update-test"
rm -rf "$BASE"; mkdir -p "$BASE/home" "$BASE/plugin/.claude-plugin"
export HOME="$BASE/home"
export CLAUDE_PLUGIN_ROOT="$BASE/plugin"
fails=0

manifest() { printf '{"name":"flow","version":"%s"}\n' "$1" > "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"; }
check() {  # <label> <expected-output-or-empty> <expected-marker>
  local out; out=$(sh "$HOOK" 2>&1); local rc=$?
  local marker; marker=$(cat "$HOME/.claude/flow/news-notified" 2>/dev/null || echo "<none>")
  if [ "$rc" = 0 ] && [ "$out" = "$2" ] && [ "$marker" = "$3" ]; then printf '  ok   %s\n' "$1"
  else printf '  FAIL %s\n       rc=%s out=%q marker=%s (want out=%q marker=%s)\n' "$1" "$rc" "$out" "$marker" "$2" "$3"; fails=$((fails+1)); fi
}

manifest 0.36.0
check "fresh install: silent, baseline set"            ""  "0.36.0"
check "same version: silent"                           ""  "0.36.0"
manifest 0.37.0
check "version changed: one line, baseline moved" \
      "flow updated to v0.37.0 (was v0.36.0) — run /flow:news to see what changed." "0.37.0"
check "seen once: silent again"                        ""  "0.37.0"

printf 'v0.30.0\n' > "$HOME/.claude/flow/news-last-seen"
manifest 0.38.0
check "news-last-seen is never touched (notice still fires)" \
      "flow updated to v0.38.0 (was v0.37.0) — run /flow:news to see what changed." "0.38.0"
[ "$(cat "$HOME/.claude/flow/news-last-seen")" = "v0.30.0" ] && printf '  ok   news-last-seen untouched\n' \
  || { printf '  FAIL news-last-seen was modified\n'; fails=$((fails+1)); }

rm "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"
check "no plugin.json: silent, marker unchanged"       ""  "0.38.0"

rm -rf "$BASE"
if [ "$fails" = 0 ]; then echo "notify-update: all cases pass"; else echo "notify-update: $fails failure(s)"; exit 1; fi
