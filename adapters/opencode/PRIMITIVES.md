# PRIMITIVES.md — Mapa de traducción de primitivas

Este documento explica cómo se tradujo cada primitiva específica de Claude Code al adaptador de opencode, y qué capacidades no tienen equivalente directo.

## Tabla de traducción

| Primitiva Claude Code | Significado original | Traducción en opencode | Notas |
|---|---|---|---|
| `Agent <rol>` / subagente | Delega trabajo aislado en un subagente con herramientas propias | `@nombre` (invocar subagente declarado en `agents/<nombre>.md` con `mode: subagent`) | Ver sección "Cómo declarar subagentes" más abajo |
| `AskUserQuestion` | Menú estructurado con opciones clickables | **Pregunta en texto al usuario y espera respuesta** | No existe UI estructurada en opencode — el agente escribe la pregunta con las opciones enumeradas y el usuario responde con texto |
| `ScheduleWakeup` | Re-despiertar la sesión en N minutos (autopilot de watch) | **Cron del SO + `opencode run -p "<prompt>"`** | No existe reagendado en sesión; el comando `work-watch` ejecuta un ciclo y termina; el estado entre ciclos se guarda en `monitor.md`; el usuario configura el cron |
| `Workflow` (orquestación paralela determinista) | Fan-out en paralelo con síntesis — varios agentes en paralelo sin verse entre ellos | **Varios subagentes `@nombre` lanzados en el mismo prompt** (opencode los puede ejecutar en paralelo si la herramienta lo soporta); si no, secuencial con consolidación manual | El agente principal sintetiza los resultados de todos los subagentes antes de continuar |
| `Skill commit-commands:commit-push-pr` | Crear commit + push + MR/PR usando el skill de la herramienta | **Git manual + CLI de `git.cli` de `FLOW.md`** (p.ej. `glab mr create` o `gh pr create`) | Si hay un skill/comando equivalente en opencode, úsalo; si no, los pasos son explícitos en `/feat-ship` y `/bug-ship` |
| `Skill <nombre>` (otros skills) | Invocar un flujo reutilizable de la herramienta | **Inline**: el contenido del skill se incorpora al prompt del comando que lo invocaba | Los skills de convenciones del proyecto se cargan leyendo los archivos referenciados en `FLOW.md` sección `conventions` |
| `mcp__domain-memory__search_knowledge` | Consultar el MCP domain-memory | **Mismo nombre de tool**: `mcp__domain-memory__search_knowledge` | El servidor MCP se configura en `opencode.json` bajo `mcp.domain-memory` |
| `mcp__domain-memory__stage_finding` | Stagear un hallazgo de dominio | **Mismo nombre**: `mcp__domain-memory__stage_finding` | Idem |
| `mcp__domain-memory__read_staging` | Leer el staging de la rama actual | **Mismo nombre**: `mcp__domain-memory__read_staging` | Idem |
| `mcp__domain-memory__save_knowledge` | Guardar en el almacén de domain-memory | **Mismo nombre**: `mcp__domain-memory__save_knowledge` | Idem |
| `TaskCreate` (crear lista de tareas) | Trackear pasos de la implementación | **Lista en markdown en el artefacto** (`05-implementation.md`): los pasos se anotan como `- [ ] paso` y se marcan con `- [x]` al completar | opencode no tiene una herramienta TaskCreate nativa; la bitácora en el artefacto cumple la misma función |

## Qué NO se porta 1:1

### AskUserQuestion
En Claude Code, `AskUserQuestion` muestra un menú estructurado con botones/opciones que el usuario puede pulsar. En opencode no existe esta UI — el agente escribe la pregunta con las opciones enumeradas en texto (p.ej. "Elige una opción: 1) Sí, adelante. 2) No, editar. 3) Cancelar.") y el usuario responde con el número o el texto de la opción.

**Efecto práctico**: las confirmaciones y elecciones del usuario siguen siendo explícitas y obligatorias; solo cambia el mecanismo (texto vs UI estructurada).

### Autopilot del watch (ScheduleWakeup)
En Claude Code, `work:watch` usa `ScheduleWakeup` para reagendarse automáticamente dentro de la misma sesión: el agente duerme N minutos y se despierta solo, sin intervención del usuario.

En opencode **no existe este mecanismo en sesión**. El equivalente es:

1. **Un ciclo por ejecución**: `work-watch` ejecuta **un ciclo** de vigilancia (consulta señales, reporta, actualiza `monitor.md`) y termina.
2. **Estado persistido**: todo lo necesario para el ciclo siguiente (plan, baseline, T0, T_fin, señales, estado acumulado) se guarda en `.claude/work/<TICKET>/monitor.md`.
3. **Ciclos continuos vía cron**: el usuario configura un cron del SO o una tarea programada que ejecute `opencode run -p "/work-watch {TICKET}"` cada ~5 minutos. Ejemplo:
   ```bash
   # Ejemplo crontab: vigilar PROJ-15421 cada 5 minutos
   */5 * * * * cd /ruta/al/repo && opencode run -p "/work-watch PROJ-15421"
   ```
4. **Re-entrada limpia**: al inicio de cada ciclo, `work-watch` detecta si `monitor.md` ya tiene el plan aprobado y salta directamente al §5 (ciclo) sin repetir el descubrimiento.

**Efecto práctico**: la vigilancia continua requiere configuración explícita del cron por parte del usuario; en Claude Code era automática. La alternativa manual (`/loop 5m /work-watch {TICKET}` de Claude Code) tampoco existe en opencode — la opción más cercana es el cron.

## Cómo declarar subagentes en opencode

Los comandos de este adaptador invocan subagentes con `@nombre`. Para que funcionen, el usuario debe declararlos en `agents/<nombre>.md` (en el directorio de opencode del proyecto o global).

### Formato de un subagente

```markdown
---
description: <Descripción breve del rol del subagente>
mode: subagent
model: <modelo, p.ej. claude-sonnet-4-5>
temperature: 0.3
---

<System prompt del subagente aquí>
```

### Dónde declarar subagentes

- **Proyecto**: `.opencode/agents/<nombre>.md`
- **Global**: `~/.config/opencode/agents/<nombre>.md`

### Qué nombres espera el adaptador

Los nombres de subagente no están en el adaptador — los define el usuario en `FLOW.md` bajo los campos `agents.*`. El adaptador los referencia como `@<agents.architecture>`, `@<agents.persistence>`, etc. Si un campo `agents.*` está vacío, el comando usa un subagente de propósito general con el rol descrito en el prompt.

**Ejemplo de `FLOW.md`**:
```yaml
## agents
- architecture: ddd-symfony-architect
- persistence: doctrine-orm-specialist
- testing: test-writer
- security: security-backend
- performance: performance-analyzer
- frontend: frontend-react-specialist
- frontend_test: frontend-testing-specialist
- queues: dlx-analyzer
```

Con esto, `/feat-design` lanzará `@ddd-symfony-architect` para la arquitectura, `@doctrine-orm-specialist` para persistencia, etc.

## Degradación cuando un subagente no está disponible

Si el subagente `@nombre` no existe en `agents/`, opencode lo reportará como error. Los comandos están escritos con degradación explícita: si el campo `agents.*` de `FLOW.md` está vacío, se usa un subagente de propósito general con el rol indicado en el prompt. Por tanto, el adaptador funciona sin ningún subagente declarado — simplemente pierde la especialización.
