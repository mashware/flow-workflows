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

case "$TOOL" in
  opencode)
    if [ "$SCOPE" = project ]; then DEST=".opencode/commands"; else DEST="$HOME/.config/opencode/commands"; fi
    mkdir -p "$DEST"; cp "$HERE"/opencode/commands/*.md "$DEST"/
    echo "✓ opencode: 26 commands in $DEST  (invoke as /flow-feat-start, /flow-work-watch, …)"
    note "MCP: merge the \"mcp\" block from $HERE/opencode/opencode.json into your opencode.json"
    note "Subagents: declare the ones named in FLOW.md (agents/review map) in agents/*.md — see opencode/PRIMITIVES.md"
    ;;
  gemini)
    if [ "$SCOPE" = project ]; then DEST=".gemini/commands"; else DEST="$HOME/.gemini/commands"; fi
    mkdir -p "$DEST"; cp -r "$HERE"/gemini/commands/. "$DEST"/
    echo "✓ gemini: 26 commands in $DEST  (invoke as /flow:feat:start, /flow:work:watch, …)"
    note "MCP: merge \"mcpServers\" from $HERE/gemini/settings.snippet.json into your settings.json"
    note "Subagents: declare the ones from FLOW.md in .gemini/agents/*.md — see gemini/PRIMITIVES.md"
    ;;
  codex)
    DEST="$HOME/.codex/prompts"
    mkdir -p "$DEST"; cp "$HERE"/codex/prompts/*.md "$DEST"/
    echo "✓ codex: 26 prompts in $DEST  (invoke as /flow-feat-start, /flow-work-watch, …)"
    note "⚠ The prompts path may vary by Codex version — confirm it with /help or your version's docs."
    note "MCP/subagents: merge $HERE/codex/config.snippet.toml into ~/.codex/config.toml"
    note "Conventions: copy $HERE/codex/AGENTS.md to your repo root if you want (Codex reads it as a guide)."
    ;;
  *)
    echo "Usage: ./install.sh <opencode|gemini|codex> [project]" >&2
    exit 1
    ;;
esac

# /flow:news reads the bundled changelog from a stable, harness-agnostic path.
# (The Claude Code plugin reads it from ${CLAUDE_PLUGIN_ROOT}; the adapters lack
#  that, so they read ~/.claude/flow/CHANGELOG.md instead.)
mkdir -p "$HOME/.claude/flow"
if cp "$HERE/../plugins/flow/CHANGELOG.md" "$HOME/.claude/flow/CHANGELOG.md" 2>/dev/null; then
  note "news: changelog copied to ~/.claude/flow/CHANGELOG.md (feeds /flow-news · /flow:news)"
fi

echo
echo "→ One key step remaining: place a FLOW.md at the root of your repo."
echo "  Template: $HERE/../plugins/flow/examples/FLOW.template.md"
echo "  (without FLOW.md everything still works, just with more prompting)"
