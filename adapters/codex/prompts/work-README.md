# `/work-README`

Muestra la guía del sistema de flujos `/feat-*` y `/bug-*` para este adaptador de Codex.

---

# Sistema de flujos `/feat-*` y `/bug-*`

Este sistema **orquesta** los subagentes y skills que ya existen en el proyecto (no los reemplaza). Su trabajo es persistir contexto entre fases, evitar que cada paso empiece de cero, y forzar un final con code-review.

## Configuración por repo: `FLOW.md`

Coloca un fichero `FLOW.md` en la raíz del repo para adaptar el plugin a tus convenciones. Define el tracker de tickets, las convenciones de rama y MR/PR, los comandos de calidad, las convenciones de código, el MCP de domain-memory y el perfil de observabilidad. Todos los comandos leen este fichero en su paso 0.

Puedes partir de la plantilla en `../../plugins/flow/examples/FLOW.template.md`.

Si el fichero no existe o una clave está vacía, cada comando autodescubre el valor o usa el comportamiento por defecto descrito en su sección correspondiente.

## Principios

- **Una carpeta por ticket**: `.claude/work/{TICKET}/` contiene `meta.json` y los artefactos en markdown.
- **Artefactos numerados**: cada fase escribe un `NN-fase.md` que el siguiente paso lee.
- **`meta.json` es la fuente de verdad** del estado (fase actual, tamaño, rama). Sin él, los comandos se niegan a continuar.
- **Tamaño manda**: en `/feat-start` y `/bug-start` se clasifica XS/S/M/L y se sugiere saltar fases en cambios pequeños.
- **Rama con base explícita y sin upstream a la base**: crear una rama ya provocó un despliegue accidental, así que `/feat-start` §5 y `/bug-start` §3 imponen dos reglas.
- **El MR/PR comunica funcionalidad, no implementación**: el título y la descripción parten del **Brief** del artefacto correspondiente, no del diseño técnico.
- **Previsualización del MR/PR obligatoria antes de crear**: en `/feat-ship` y `/bug-ship`, antes de invocar la creación, se imprime al usuario el bloque completo y se pide confirmación.
- **Los commits son opt-in del usuario**: durante `/feat-build` y `/bug-fix`, el agente **no hace `git commit` por su cuenta**.
- **Code review obligatorio**: no se hace `/feat-ship` ni se cierra `/bug-postmortem` sin pasar por `/*-review`.

## Esquema de `meta.json`

```json
{
  "ticket": "{PREFIX}XXXXX",
  "type": "feat" | "bug",
  "title": "Texto del tracker o descripción corta",
  "branch": "{PREFIX}XXXXX-slug",
  "size": "XS" | "S" | "M" | "L",
  "phase": "context" | "brainstorm" | "design" | "plan" | "build" | "review" | "validate" | "ship" | "diagnose" | "investigate" | "fix" | "postmortem" | "done" | "abandoned",
  "phases_done": ["context", ...],
  "mrs": [...],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "campo libre"
}
```

## Atajos por tamaño

| Tamaño | Features                                                          | Bugs                                               |
|--------|-------------------------------------------------------------------|----------------------------------------------------|
| XS     | start → build → review → ship                                     | start → fix → review → ship                        |
| S      | start → design (resumido) → build → review → validate → ship      | start → diagnose → fix → review → validate → ship  |
| M      | start → brainstorm → design → **plan** → build → review → validate → ship | flujo completo                           |
| L      | flujo completo (incluye **plan**)                                 | flujo completo                                     |

## Flujo `/feat-*` completo

`/feat-start {TICKET}` → `/feat-brainstorm` → `/feat-design` → `/feat-plan` → `/feat-build` → `/feat-review` → `/feat-validate` → `/feat-ship`

## Flujo `/bug-*` completo

`/bug-start {TICKET}` → `/bug-diagnose` → `/bug-investigate` → `/bug-fix` → `/bug-validate` → `/bug-review` → `/bug-postmortem` → `/bug-ship`

## Comandos transversales

- `/work-status` — muestra todos los trabajos en `.claude/work/`, fase actual y divergencia con git.
- `/work-resume` — detecta la rama actual, abre `meta.json`, recapitula y sugiere siguiente paso.
- `/work-watch {TICKET} [30m]` — vigilancia post-despliegue: observa la plataforma de observabilidad acotado al cambio, comparando contra línea base, y avisa si hay regresión. En Codex, hace UN ciclo y termina; el estado vive en `monitor.md`. Para repetirlo, usa cron del SO + `codex exec "/work-watch {TICKET}"` o las Automations de la app de Codex.
- `/work-abandon` — cierra un work sin enviar (feature descartada, fallo que no era fallo, etc.).

## Reglas de oro

1. **Nunca saltes `review`.** Si la fase anterior no está en `phases_done`, el comando se niega.
2. **Si editas código fuera del flujo**, `/work-status` te avisa de la divergencia.
3. **Los artefactos son editables a mano**. Si reescribes `03-design.md`, el siguiente paso lo respetará.
4. **`domain-memory` es opcional pero recomendado** al cerrar features grandes o postmortems (requiere `domain_memory.enabled: true` en FLOW.md).
