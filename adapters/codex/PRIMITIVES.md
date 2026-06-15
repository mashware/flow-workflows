# PRIMITIVES.md — tabla de traducción de primitivas

Cómo se tradujo cada primitiva específica de Claude Code al adaptador de Codex CLI, y qué se recortó o simplificó.

## Tabla de traducción

| Primitiva (Claude Code) | Significado | Traducción en Codex |
|-------------------------|-------------|---------------------|
| `Agent <rol>` / subagente | Delega trabajo aislado en un subagente | Subagente definido en `[agents.<nombre>]` de `~/.codex/config.toml`. El nombre del rol viene del mapa `agents.<rol>` de `FLOW.md`. Si el campo está vacío en FLOW.md, se usa un subagente general en el prompt. |
| `AskUserQuestion` | Menú estructurado de opciones al usuario (UI integrada en Claude Code) | **Pregunta normal en texto**: el prompt indica al agente que haga la pregunta al usuario y espere su respuesta. No existe UI estructurada en Codex → se convierte en "pregunta al usuario y espera respuesta" en prosa. |
| `ScheduleWakeup` (autopilot de watch) | Re-despertarse en N min dentro de la sesión actual | **No existe en Codex CLI**. Ver sección "Qué NO se porta 1:1" abajo. |
| `Workflow` (orquestación paralela) | Fan-out determinista en paralelo + síntesis | Subagentes lanzados en paralelo (Codex admite múltiples subagentes simultáneos en la misma respuesta). La orquestación explícita con el DSL de `Workflow` se reemplaza por instrucciones al agente principal de lanzar N subagentes en paralelo y esperar sus resultados antes de sintetizar. |
| `Skill commit-commands:commit-push-pr` | Crear commit + push + MR/PR | Secuencia manual: `git add`, `git commit`, `git push -u origin HEAD`, y el CLI de `git.cli` de FLOW.md (p.ej. `glab mr create` o `gh pr create`). El agente ejecuta los pasos directamente. |
| `Skill <otros>` (save-knowledge, code-review, etc.) | Invocar un flujo reutilizable de Claude Code | Los skills se convierten en prompts propios del adaptador (p.ej. `/save-knowledge`) o se referencian por nombre si el proyecto los tiene configurados en Codex. |
| `mcp__domain-memory__<tool>` | Llamar al MCP domain-memory | El **mismo servidor MCP** (mismo nombre de herramienta). Solo cambia la configuración: en Claude Code se referencia desde `.mcp.json`; en Codex se declara en `~/.codex/config.toml` bajo `[mcp_servers.domain-memory]`. Ver `config.snippet.toml`. |
| `TaskCreate` / `TaskStop` | Trackear pasos con la UI de tareas de Claude Code | No existe en Codex. El agente mantiene el seguimiento de pasos a través de la bitácora en el artefacto markdown (`05-implementation.md`, `04-fix.md`) y reporta el progreso al usuario en texto. |

## Qué NO se porta 1:1

### AskUserQuestion
Claude Code tiene una herramienta `AskUserQuestion` que presenta opciones como botones en la UI. Codex no tiene esta primitiva — todas las preguntas al usuario se hacen como texto normal en la respuesta. El comportamiento es equivalente: el agente pregunta y espera la respuesta del usuario antes de continuar. Las opciones se enumeran en prosa (p.ej. "Opciones: (1) Sí, adelante. (2) No, falta algo. (3) Cancelar.").

### ScheduleWakeup (autopilot de watch)
La primitiva `ScheduleWakeup` de Claude Code permite que el agente se re-despierte automáticamente a los N minutos dentro de la misma sesión, creando un bucle autopilotado. **Codex CLI no tiene esta capacidad de sesión auto-reagendada**.

Solución adoptada en `/work-watch`:
- El comando ejecuta **un solo ciclo** de vigilancia y termina.
- El estado entre ciclos se persiste en `.claude/work/<TICKET>/monitor.md` (superficie vigilada, plan aprobado, queries concretas, valores de línea base, últimas lecturas).
- Para vigilancia continua, el usuario configura un cron del SO + `codex exec "/work-watch {TICKET}"` con el intervalo deseado; o usa las Automations nativas de la app de Codex si está disponible.
- En re-entradas (cuando `monitor.md` ya existe con el plan aprobado), el comando salta directamente al ciclo §5 sin repetir descubrimiento ni pedir confirmación de nuevo.

### Workflow DSL
El DSL de `Workflow` de Claude Code permite definir fases, schemas estructurados por agente y orquestación determinista con tipado. En Codex, la orquestación paralela se expresa en lenguaje natural: el agente principal recibe instrucciones de lanzar N subagentes en paralelo con sus respectivos encargos y esperar sus resultados estructurados antes de sintetizar. El resultado práctico es equivalente aunque sin el tipado formal del DSL.

### TaskCreate / TaskStop
La UI de tareas de Claude Code no existe en Codex. El seguimiento de pasos se hace a través de los artefactos markdown del flujo (bitácora en `05-implementation.md`, `04-fix.md`) y de los reportes al usuario al final de cada paso.
