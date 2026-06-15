---
description: Arranca una feature nueva (lee el tracker, clasifica tamaño, crea rama y artefacto inicial)
---

# `/feat:start $ARGUMENTS`

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

Estás iniciando una feature. `$ARGUMENTS` debe ser el identificador del ticket (formato `tracker.prefix` de `FLOW.md`; vacío = libre). Si está vacío, pídeselo al usuario y termina sin escribir nada.

## 1. Pre-flight

- Lee `FLOW.md` en la raíz del repo. Si no existe, continúa con comportamiento por defecto (cada paso indica qué hace si falta una clave).
- Verifica que el repo tiene estructura de proyecto reconocible. Si no, avisa y termina.
- Si `.claude/work/$ARGUMENTS/meta.json` ya existe, no lo sobreescribas: avisa al usuario y sugiere `/work:resume`.

## 2. Recopila contexto

Lanza estas tareas en **paralelo**:

1. **Tracker**: si `tracker.tool` de `FLOW.md` no es `none`, lee el ticket con `tracker.view_cmd` sustituyendo `{TICKET}` — extrae título, descripción, criterios de aceptación. Si `tool` es `none` o vacío, o si el comando falla, pide al usuario que pegue el enunciado y continúa con lo que aporte.
2. **domain-memory**: si `domain_memory.enabled` es `true`, invoca el MCP `domain-memory` con `search_knowledge` usando el título y palabras clave del ticket. Si no responde en 2s o falla, sigue sin contexto.
3. **Git**: comprueba que estás en rama limpia. Si hay cambios sin commitear, avisa pero no bloquees.

## 3. Clarifica huecos del ticket

Antes de clasificar tamaño, identifica si quedan dudas que afectan al diseño y que no resuelve el enunciado ni `domain-memory`. Ejemplos típicos:

- Comportamiento con distintos tipos de plan o acceso.
- Locales, países o idiomas con reglas distintas.
- Qué pasa con usuarios existentes del flujo actual (compatibilidad).
- Qué cuenta como "éxito" (métrica, evento, log que hay que dejar).
- Casos límite obvios no especificados (entrada vacía, duplicado, fallo de red).

Si hay dudas, **pregúntalas todas de golpe** con `AskUserQuestion` (máx 4 preguntas, las más bloqueantes). No inventes ni asumas. Si todo está claro, sigue.

Las respuestas se anotan en `01-context.md` bajo "Decisiones aclaradas en /feat:start".

## 4. Clasifica el tamaño

A partir del enunciado y el contexto, propón un tamaño y pídele confirmación al usuario (pregunta única con `AskUserQuestion`):

| Tamaño | Criterio                                                                  | Fases sugeridas                     |
|--------|---------------------------------------------------------------------------|-------------------------------------|
| XS     | < 50 líneas, sin DB, sin API nueva, sin lógica de dominio                 | start → build → review → ship       |
| S      | Cambio acotado, 1-3 archivos relevantes, sin migraciones                  | start → design (corto) → build → review → validate → ship |
| M      | Lógica de dominio nueva, posibles migraciones, varios módulos             | start → brainstorm → design → build → review → validate → ship |
| L      | Cross-module, integraciones externas, cambios de modelo importantes       | flujo completo, considerar dividir  |

Recomienda el tamaño que tú estimes con un "(Recomendado)".

## 5. Crea la rama

**Dos reglas innegociables**, porque romperlas ya ha provocado un despliegue accidental:

1. **Nunca** crees la rama implícitamente desde donde estés parado. Si estás en la rama de otra tarea, un `git checkout -b` heredaría sus commits.
2. **Nunca** dejes que la rama nueva tenga la rama base como upstream automático. Con `branch.autoSetupMerge=true` un `git checkout -b X <base>` fija el upstream a esa base, y un push que resuelva el upstream puede acabar en la rama principal y disparar un despliegue.

### 5.1 Mira dónde estás antes de nada
```bash
git rev-parse --abbrev-ref HEAD   # rama actual
git status --porcelain            # ¿tree limpio?
```
- Si hay cambios sin commitear: avisa y pregunta antes de seguir (se arrastran al hacer `switch`).
- Si la rama actual **no es la rama principal** (master/main): NO asumas la base. Pregunta con `AskUserQuestion`:
  - **Base = `git.default_base` de FLOW.md** *(Recomendado)* — tarea independiente. Es el caso normal.
  - **Stack sobre `<rama-actual>`** (modo tren) — solo si esta tarea depende de otra aún sin mergear. Anótalo en `meta.json` como `stacked_on` y recuerda que el MR/PR apuntará a esa rama, no a la base principal.

### 5.2 Crea con base explícita y SIN heredar su upstream
Nombre: según `git.branch_pattern` de `FLOW.md` (sustituye `{PREFIX}` y `{TICKET}`; `{slug}` en inglés, kebab-case). Crea solo si el usuario confirma:
```bash
git fetch origin
git switch --create <nombre-rama> --no-track <git.default_base>      # tarea independiente
# — o, en modo tren confirmado: —
git switch --create <nombre-rama> --no-track origin/<rama-padre>
```
`--no-track` es **obligatorio**: es lo que impide que el upstream quede en la base remota. La base explícita (la de `git.default_base` o la rama padre, nunca "donde estoy") es lo que evita heredar commits de otra tarea.

### 5.3 Regla de push (se ejecuta en `ship`, se declara aquí)
El primer push es **siempre** explícito a la rama propia, nunca un push que resuelva upstream a ciegas:
```bash
git push -u origin HEAD    # upstream = origin/<nombre-rama>, jamás la base principal
```

## 6. Escribe artefactos

Crea `.claude/work/$ARGUMENTS/`:

### `meta.json`
```json
{
  "ticket": "$ARGUMENTS",
  "type": "feat",
  "title": "<título del ticket>",
  "branch": "<rama creada en §5>",
  "stacked_on": null,
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "started_at": "<ISO8601 ahora>",
  "updated_at": "<ISO8601 ahora>",
  "notes": ""
}
```

### `01-context.md`
Estructura:
```markdown
# Contexto <TICKET>

## Ticket
<resumen del enunciado en 3-5 bullets>

## Criterios de aceptación
<lista del tracker o "no especificados">

## Conocimiento de dominio relevante
<hits de domain-memory con un bullet por hallazgo, o "sin hallazgos">

## Estado del repo al arrancar
- Rama: <nombre>
- Último commit: <hash corto + mensaje>

## Decisiones aclaradas en /feat:start
<lista pregunta → respuesta del usuario, o "no había dudas">

## Tamaño estimado: <XS|S|M|L>
<2 líneas justificando>
```

## 7. Cierre

Resume al usuario en 2-3 líneas:
- Ticket, tamaño, rama.
- Siguiente comando recomendado según tamaño (ver tabla).

No invoques al siguiente paso automáticamente.
