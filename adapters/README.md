# adapters — los flujos `flow` en otros harnesses

El plugin `flow` (en `../plugins/flow`) es para **Claude Code**. Estos adaptadores llevan los
mismos flujos `feat`/`bug`/`work` a otros agentes de terminal, reescribiendo solo el
**envoltorio** (formato de comandos, subagentes, MCP) — la **lógica y la prosa son las mismas**.

| Harness | Comandos | Subagentes | MCP | Autopilot watch |
|---|---|---|---|---|
| **opencode** | `commands/*.md` (`/feat-start`) | `agents/*.md` `mode:subagent`, `@nombre` | `opencode.json` | cron + `opencode run -p` |
| **Gemini CLI** | `commands/**/*.toml` (`/feat:start`) | `.gemini/agents/*.md`, `@nombre` | `settings.json` `mcpServers` | cron + `gemini -p` |
| **Codex CLI** | `prompts/*.md` (`/feat-start`) | `[agents.*]` en `config.toml` | `[mcp_servers.*]` | cron + `codex exec` |

## Instalar

```bash
./install.sh opencode      # o: gemini | codex
./install.sh opencode project   # variante en el repo actual (donde aplique)
```
El script **copia los comandos** (additivo, seguro) y te dice qué **fragmento de config**
(MCP/subagentes) fusionar a mano en tu `opencode.json` / `settings.json` / `config.toml` —
no toca tus configs automáticamente para no pisar lo que ya tengas.

Después: pon un **`FLOW.md`** en la raíz de tu repo (plantilla en
`../plugins/flow/examples/FLOW.template.md`). Es lo que configura tracker, git, comandos de
test, observabilidad y el mapa de subagentes para TU proyecto.

## Qué se porta y qué no (honesto)

- **Se porta igual**: fases (start→ship, diagnose→postmortem), reglas, gates, `FLOW.md`, MCP
  (`domain-memory`), Pre-deploy + hilo bloqueante, y los **subagentes** (review/investigate) —
  los tres harnesses los soportan, solo cambia el formato de declaración.
- **Se recorta** (ver el `PRIMITIVES.md` de cada adaptador):
  - **`AskUserQuestion`**: ninguno tiene menú estructurado → queda como pregunta en texto.
  - **Autopilot de `/work:watch`**: no hay re-despertar en-sesión → pasa a **cron del SO +
    ejecución headless**. El comando hace UN ciclo y termina; el estado vive en `monitor.md`,
    que cada ciclo re-lee. Funciona, pero el disparador es externo, no la propia sesión.

## Aviso

Estos adaptadores están generados **fieles al formato documentado de cada herramienta, pero
sin probar dentro de ella** (no se pueden ejecutar desde aquí). Son una primera versión sólida;
valídalos al usarlos y ajusta rutas si tu versión del harness difiere — especialmente en Codex,
donde la ubicación de prompts cambia entre versiones (ver `codex/README.md`).

> Fuente única de la lógica: `../plugins/flow/commands/`. Si cambias un flujo allí, regenera el
> adaptador afectado para no divergir.
