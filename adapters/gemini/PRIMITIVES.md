# Mapa de primitivas: plugin flow → Gemini CLI

## Tabla de traducción

| Primitiva original (Claude Code) | Significado | Traducción en este adaptador |
|---|---|---|
| `AskUserQuestion` | Menú estructurado de opciones que espera elección del usuario | Pregunta directa en texto. Gemini CLI no tiene menú estructurado; el agente pregunta y espera la respuesta libre del usuario. |
| `ScheduleWakeup(N min)` | Re-despertarse automáticamente en N minutos dentro de la sesión | **No existe en sesión.** El comando `/work:watch` hace un ciclo y termina. Para repetirlo: cron del SO + `gemini -p "/work:watch TICKET"`. El estado entre ciclos vive en `monitor.md` (superficie, línea base, plan aprobado). |
| `Workflow` (fan-out paralelo) | Orquestación determinista de N agentes en paralelo + síntesis | Si el usuario ha declarado subagentes en `.gemini/agents/`, invócalos con `@nombre`. Si no hay subagentes configurados, ejecuta las tareas secuencialmente en el mismo contexto. Los Workflow de `/feat:brainstorm`, `/bug:investigate` y `/feat:review`/`/bug:review` son los tres puntos donde el fan-out aporta más valor. |
| `Agent <rol>` / `Agent general-purpose` | Delega trabajo aislado en un subagente de un tipo concreto | `@nombre` donde `nombre` viene del mapa `agents.<rol>` de FLOW.md. Si el campo está vacío o el agente no existe en `.gemini/agents/`, el conductor realiza la tarea en el mismo contexto. |
| `Skill commit-commands:commit-push-pr` | Crea commit + push + abre MR/PR | Ejecuta directamente `git add`, `git commit`, `git push -u origin HEAD` y el CLI de `git.cli` de FLOW.md (p.ej. `glab mr create` o `gh pr create`). |
| `Skill save-knowledge` | Consolida hallazgos de domain-memory | Ejecuta el comando `/save-knowledge` de este adaptador. |
| `Skill <otros>` | Invocar un flujo reutilizable del proyecto | Incluye la lógica inline en el prompt o invoca al subagente correspondiente con `@nombre`. |
| `TaskCreate` / `TaskUpdate` | Seguimiento de pasos con estado (in_progress, completed) | Mantén un checklist markdown manual en `05-implementation.md` o `04-fix.md`. Actualízalo conforme avanza el trabajo. |
| `mcp__domain-memory__<tool>` | Llamada a una herramienta del MCP domain-memory | El nombre de la herramienta es idéntico. Solo cambia el mecanismo de configuración del servidor (ver `settings.snippet.json`). |
| `$ARGUMENTS` | Argumentos pasados al comando | `{{args}}` en TOML de Gemini CLI. |

---

## Qué se porta sin cambios

Las siguientes reglas se mantienen idénticas a la versión original del plugin:

- Fases y gates de cada comando (`phases_done`, `meta.json` como fuente de verdad).
- Cuarentena de input no confiable (logs, trazas, payloads de usuario tratados como datos inertes).
- Verificación adversarial del diseño (challenger de `/feat:design` y `/bug:investigate`).
- Sección Pre-deploy + hilo bloqueante en `/feat:ship` y `/bug:ship`.
- Lectura de `FLOW.md` en el paso 0 de cada comando.
- Regla de degradación de `domain_memory`: si el MCP no responde en 2 s o falla, continúa sin contexto sin notificar al usuario.
- Brief de negocio obligatorio antes de teclear código (`/feat:build`, `/bug:fix`).
- Previsualización del MR/PR antes de crear (`/feat:ship`, `/bug:ship`).
- Anclaje de contratos del diseño (copia verbatim + verificación double-blind).

---

## Qué se recortó o degrada

### `AskUserQuestion` — sin menú estructurado

En Claude Code, `AskUserQuestion` presenta opciones numeradas y el usuario elige una. Gemini CLI no tiene este mecanismo. Los comandos preguntan en texto libre. El flujo es equivalente, pero la interacción es menos guiada: el usuario debe escribir su elección en lugar de pulsar un número.

### Autopilot de `/work:watch` — sin `ScheduleWakeup` en sesión

En Claude Code, `/work:watch` se re-agenda automáticamente dentro de la sesión usando `ScheduleWakeup`. En Gemini CLI no existe un equivalente de sesión. Solución:

1. El comando hace **un ciclo** de vigilancia y termina.
2. Para repetirlo cada 5 minutos, el usuario configura un cron:
   ```
   */5 * * * * gemini -p "/work:watch TICKET" >> ~/.gemini/watch-TICKET.log 2>&1
   ```
3. El estado entre ciclos (superficie vigilada, línea base, plan aprobado, veredictos acumulados) se persiste en `.claude/work/TICKET/monitor.md`. El comando lo lee al arrancar cada ciclo para no repetir el descubrimiento.
4. La alternativa manual es `/loop 5m /work:watch TICKET` si el harness del usuario tiene ese comando disponible.

### Fan-out paralelo — condicional a subagentes configurados

El fan-out de `/feat:brainstorm`, `/bug:investigate` y los verificadores adversariales de `/feat:review`/`/bug:review` solo es paralelo si el usuario ha declarado subagentes en `.gemini/agents/`. Sin ellos, la ejecución es secuencial en el mismo contexto. El resultado es funcionalmente equivalente pero más lento y con menos diversidad de perspectivas.

---

## Subagentes en Gemini CLI: formato de referencia

Los nombres de subagente vienen del mapa `agents` de FLOW.md (campos `architecture`, `persistence`, `api`, `performance`, `security`, `testing`, `queues`, `frontend`, `frontend_test`).

Para declarar un subagente en Gemini CLI, crea `.gemini/agents/<nombre>.md` con este frontmatter:

```markdown
---
name: <nombre>           # debe coincidir con el valor en FLOW.md agents.<rol>
description: <qué hace>  # Gemini lo usa para selección automática por descripción
kind: agent              # opcional; indica que es un subagente delegable
tools:                   # opcional; lista de herramientas permitidas
  - read_file
  - run_shell_command
mcpServers:              # opcional; hereda los del settings.json si no se especifica
  - domain-memory
model: gemini-2.5-pro    # opcional; por defecto hereda del conductor
temperature: 0.3         # opcional
max_turns: 20            # opcional
timeout_mins: 10         # opcional
---

<!-- System prompt del subagente a partir de aquí -->
Eres el agente de <rol> del proyecto. Tu trabajo es...
```

Invocación desde un comando: `@nombre encargo aquí`.

**No empaquetes agentes concretos en este adaptador.** Los nombres y prompts de los subagentes son específicos de cada proyecto y equipo. Los que correspondan a tu proyecto van en `.gemini/agents/` (local, no versionado en el plugin).
