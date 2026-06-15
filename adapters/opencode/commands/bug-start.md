---
description: Arranca el flujo de incidencia (tracker, domain-memory, tamaño, rama, artefacto inicial)
---

# `/bug-start $ARGUMENTS`

Inicia una incidencia. `$ARGUMENTS` es el ticket (formato `tracker.prefix` de FLOW.md; vacío = libre). Si vacío, pídelo y termina.

## 0. Pre-flight

Lee `FLOW.md` en la raíz del repo para las convenciones de este repo (tracker, git, calidad, dominio, observabilidad). Si no existe o una clave está vacía, usa el valor por defecto o autodescubre según indique cada paso. Sobre `domain_memory`: si está activo pero el MCP falla o tarda más de 2 s, continúa sin ese contexto, no bloquees ni se lo notifiques al usuario.

- Verifica que estás en el repo correcto.
- Si `.claude/work/$ARGUMENTS/meta.json` existe, sugiere `/work-resume`.

## 1. Recopila contexto

En paralelo:

1. **Tracker**: léelo con `tracker.view_cmd` de FLOW.md (sustituye `{TICKET}` por `$ARGUMENTS`). Si `tool:none` o falta la clave, pídele al usuario el síntoma, severidad y entorno.
2. **domain-memory** (si `domain_memory.enabled`): `search_knowledge` con palabras clave del síntoma. Importante para detectar si ya hubo postmortems del mismo área.
3. **Observabilidad** si el incidente está reciente: si tienes pistas (servicio, traza, registro), considera usar las herramientas MCP de `observability.platform` de FLOW.md. Si no, no fuerces.
4. **Git**: comprueba rama limpia y commit base.

## 2. Clasifica el tamaño

| Tamaño | Criterio                                                  | Fases sugeridas                              |
|--------|-----------------------------------------------------------|----------------------------------------------|
| XS     | Arreglo obvio (errata, condición invertida, null check)     | start → fix → review → ship                  |
| S      | Síntoma claro, causa razonablemente acotada               | start → diagnose → fix → review → validate → ship |
| M      | Síntoma claro pero causa no evidente, posible regresión   | start → diagnose → investigate → fix → validate → review → postmortem |
| L      | Incidente crítico, multi-componente, producción afectada  | flujo completo + postmortem obligatorio       |

## 3. Rama

Mismas dos reglas innegociables que en `/feat-start` §5 (romperlas ya causó un despliegue accidental):

1. **Base explícita**, nunca implícita desde donde estés. Si estás en la rama de otra tarea, heredarías sus commits.
2. **Sin heredar upstream**: con `branch.autoSetupMerge=true` (configuración del equipo), crear desde `git.default_base` de FLOW.md sin `--no-track` deja el upstream en esa base y un envío puede acabar en ella.

```bash
git rev-parse --abbrev-ref HEAD && git status --porcelain   # dónde estoy / árbol limpio
git fetch origin
git switch --create $ARGUMENTS-fix-slug --no-track <git.default_base>   # base independiente; --no-track obligatorio
```

Si la rama actual no es la base principal, pregunta la base al usuario (`git.default_base` recomendado, o apilada sobre la actual en modo tren → anótalo como `stacked_on`). Crea solo si el usuario lo confirma. Primer envío siempre `git push -u origin HEAD` (en `ship`), jamás a la base principal.

## 4. Escribe artefactos

`.claude/work/$ARGUMENTS/meta.json`:
```json
{
  "ticket": "$ARGUMENTS",
  "type": "bug",
  "title": "<síntoma del tracker>",
  "branch": "<rama creada en §3>",
  "stacked_on": null,
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "started_at": "...",
  "updated_at": "...",
  "notes": ""
}
```

`.claude/work/$ARGUMENTS/01-context.md`:
```markdown
# Contexto incidencia {TICKET}

## Síntoma reportado
<lo que dice el reporter>

## Datos del tracker
- Severidad / prioridad:
- Entorno afectado:
- Reporter:
- Fecha primer aviso:

## Conocimiento previo (domain-memory)
<hallazgos o "sin hallazgos">

## Pistas iniciales
- Stack trace / registro conocido:
- Traza de observabilidad (si la hay):
- Workers en cola de fallos (si aplica):

## Tamaño estimado: <XS|S|M|L>
```

## 5. Cierre

Resume y sugiere siguiente comando según tamaño (`/bug-fix` para XS, `/bug-diagnose` en el resto). No avanza solo.
