#!/usr/bin/env bash
# Installs the `flow` workflow adapter for the specified harness.
# Usage: ./install.sh <opencode|gemini|codex> [project]
#   without "project" → global install (harness user folder)
#   "project"         → install into the current repo (where applicable)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="${1:-}"
SCOPE="${2:-global}"

note() { printf '  %s\n' "$1"; }

# A reinstall copies over what is there but never removes what upstream deleted, so a
# command dropped from the plugin stays installed and invocable for ever. Clear the
# previous flow-* files first — only ours, by prefix, never the whole directory.
sweep() {
  local dest=$1 pattern=$2 removed
  [ -d "$dest" ] || return 0
  removed=$(find "$dest" -name "$pattern" -type f -print -delete 2>/dev/null | wc -l | tr -d " ")
  [ "$removed" -gt 0 ] && note "removed $removed previously installed file(s) from $dest"
  return 0
}

case "$TOOL" in
  opencode)
    if [ "$SCOPE" = project ]; then DEST=".opencode/commands"; else DEST="$HOME/.config/opencode/commands"; fi
    mkdir -p "$DEST"; sweep "$DEST" "flow-*.md"; cp "$HERE"/opencode/commands/*.md "$DEST"/
    N=$(ls "$HERE"/opencode/commands/*.md | wc -l | tr -d " ")
    echo "✓ opencode: $N commands in $DEST  (invoke as /flow-feat-start, /flow-work-watch, …)"
    note "MCP: merge the \"mcp\" block from $HERE/opencode/opencode.json into your opencode.json"
    note "Subagents: declare the ones named in FLOW.md (agents/review map) in agents/*.md — see opencode/PRIMITIVES.md"
    ;;
  gemini)
    if [ "$SCOPE" = project ]; then DEST=".gemini/commands"; else DEST="$HOME/.gemini/commands"; fi
    mkdir -p "$DEST"; rm -rf "$DEST/flow"; cp -r "$HERE"/gemini/commands/. "$DEST"/
    N=$(find "$HERE"/gemini/commands -name "*.toml" | wc -l | tr -d " ")
    echo "✓ gemini: $N commands in $DEST  (invoke as /flow:feat:start, /flow:work:watch, …)"
    note "MCP: merge \"mcpServers\" from $HERE/gemini/settings.snippet.json into your settings.json"
    note "Subagents: declare the ones from FLOW.md in .gemini/agents/*.md — see gemini/PRIMITIVES.md"
    ;;
  codex)
    if [ "$SCOPE" = project ]; then
      note "⚠ codex has no per-project prompts directory — installing globally instead"
    fi
    DEST="$HOME/.codex/prompts"
    mkdir -p "$DEST"; sweep "$DEST" "flow-*.md"; cp "$HERE"/codex/prompts/*.md "$DEST"/
    N=$(ls "$HERE"/codex/prompts/*.md | wc -l | tr -d " ")
    echo "✓ codex: $N prompts in $DEST  (invoke as /flow-feat-start, /flow-work-watch, …)"
    note "⚠ The prompts path may vary by Codex version — confirm it with /help or your version's docs."
    note "MCP/subagents: merge $HERE/codex/config.snippet.toml into ~/.codex/config.toml"
    note "Conventions: copy $HERE/codex/AGENTS.md to your repo root if you want (Codex reads it as a guide)."
    ;;
  *)
    echo "Usage: ./install.sh <opencode|gemini|codex> [project]" >&2
    exit 1
    ;;
esac

# The adapters have no ${CLAUDE_PLUGIN_ROOT}, so what the plugin reads from there lands
# in ~/.claude/flow instead: the shared rules every command points at (CORE.<tool>.md,
# generated per harness by script/adapter-build.py), the changelog /flow:news reads, and
# the manifest it takes the installed version from.
mkdir -p "$HOME/.claude/flow"
cp "$HERE/$TOOL/CORE.md" "$HOME/.claude/flow/CORE.$TOOL.md"
note "core: shared rules copied to ~/.claude/flow/CORE.$TOOL.md (every command reads it once per session)"
if cp "$HERE/../plugins/flow/CHANGELOG.md" "$HOME/.claude/flow/CHANGELOG.md" 2>/dev/null; then
  note "news: changelog copied to ~/.claude/flow/CHANGELOG.md (feeds /flow-news · /flow:news)"
fi
cp "$HERE/../plugins/flow/.claude-plugin/plugin.json" "$HOME/.claude/flow/plugin.json" 2>/dev/null || true

echo
echo "→ One key step remaining: place a FLOW.md at the root of your repo."
echo "  Template: $HERE/../plugins/flow/examples/FLOW.template.md"
echo "  (without FLOW.md everything still works, just with more prompting)"
