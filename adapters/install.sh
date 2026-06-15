#!/usr/bin/env bash
# Instala el adaptador de flujos `flow` para el harness indicado.
# Uso: ./install.sh <opencode|gemini|codex> [project]
#   sin "project" → instalación global (carpeta de usuario del harness)
#   "project"     → instalación en el repo actual (donde aplique)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="${1:-}"
SCOPE="${2:-global}"

note() { printf '  %s\n' "$1"; }

case "$TOOL" in
  opencode)
    if [ "$SCOPE" = project ]; then DEST=".opencode/commands"; else DEST="$HOME/.config/opencode/commands"; fi
    mkdir -p "$DEST"; cp "$HERE"/opencode/commands/*.md "$DEST"/
    echo "✓ opencode: 22 comandos en $DEST  (se invocan /feat-start, /work-watch, …)"
    note "MCP: fusiona el bloque \"mcp\" de $HERE/opencode/opencode.json en tu opencode.json"
    note "Subagentes: declara los nombrados en FLOW.md (mapa agents/review) en agents/*.md — ver opencode/PRIMITIVES.md"
    ;;
  gemini)
    if [ "$SCOPE" = project ]; then DEST=".gemini/commands"; else DEST="$HOME/.gemini/commands"; fi
    mkdir -p "$DEST"; cp -r "$HERE"/gemini/commands/. "$DEST"/
    echo "✓ gemini: 22 comandos en $DEST  (se invocan /feat:start, /work:watch, …)"
    note "MCP: fusiona \"mcpServers\" de $HERE/gemini/settings.snippet.json en tu settings.json"
    note "Subagentes: declara los de FLOW.md en .gemini/agents/*.md — ver gemini/PRIMITIVES.md"
    ;;
  codex)
    DEST="$HOME/.codex/prompts"
    mkdir -p "$DEST"; cp "$HERE"/codex/prompts/*.md "$DEST"/
    echo "✓ codex: 22 prompts en $DEST  (se invocan /feat-start, /work-watch, …)"
    note "⚠ La ruta de prompts puede variar por versión de Codex — confírmala con /help o la doc de tu versión."
    note "MCP/subagentes: fusiona $HERE/codex/config.snippet.toml en ~/.codex/config.toml"
    note "Convenciones: copia $HERE/codex/AGENTS.md a la raíz de tu repo si quieres (Codex lo lee como guía)."
    ;;
  *)
    echo "Uso: ./install.sh <opencode|gemini|codex> [project]" >&2
    exit 1
    ;;
esac

echo
echo "→ Falta el paso clave: pon un FLOW.md en la raíz de tu repo."
echo "  Plantilla: $HERE/../plugins/flow/examples/FLOW.template.md"
echo "  (sin FLOW.md funciona igual, solo preguntando más cosas)"
