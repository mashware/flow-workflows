#!/usr/bin/env bash
# Roadmap trap: a plan kept as tables, under a lowercase name, with dependencies per
# deliverable. The first pending row in file order waits on another pending row; the
# next one to start sits below it. And a row still says "in progress" although the work
# that delivered it is archived as done with every MR merged.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_git_init
fx_base_app
fx_flow_config
mkdir -p docs
cat > docs/roadmap.md <<'MD'
# Plan del proyecto

## Orden

| Hito | Qué deja hecho | Depende de | Estado |
|---|---|---|---|
| H1 | La base: almacén y pipeline | — | Hecho |
| H2 | Importar pedidos desde CSV | H1 | En curso |
| H3 | Exportar pedidos | H2 | Pendiente |

## H1 — Base

Terminado cuando: el pipeline procesa un pedido de punta a punta en local.

| Entregable | Estado | Ticket | Depende de |
|---|---|---|---|
| Almacén en memoria | Hecho | DEMO-1 | — |
| Pipeline de pasos | Hecho | DEMO-2 | Almacén en memoria |

## H2 — Importación

Terminado cuando: un CSV real de un cliente entra sin intervención manual.

| Entregable | Estado | Ticket | Depende de |
|---|---|---|---|
| Lector CSV | Hecho | DEMO-11 | — |
| Validación de filas | En curso: la primera MR trajo el esquema; la segunda trae los errores por fila | DEMO-12 | Lector CSV |
| Deduplicado | Pendiente | | Mapeo de columnas |
| Mapeo de columnas | Pendiente | | Lector CSV |

## H3 — Exportación

Terminado cuando: el cliente descarga sus pedidos en CSV.

| Entregable | Estado | Ticket | Depende de |
|---|---|---|---|
| Escritor CSV | Pendiente | | — |

## Cómo se usa

- El siguiente trabajo es el primer entregable pendiente cuyas dependencias están hechas.
- La MR que cierra un entregable actualiza su estado en el mismo cambio.
MD
mkdir -p .claude/work/_archive/DEMO-12
cat > .claude/work/_archive/DEMO-12/meta.json <<'JSON'
{
  "ticket": "DEMO-12",
  "type": "feat",
  "title": "Validate imported rows",
  "branch": "DEMO-12-row-validation",
  "size": "M",
  "phase": "done",
  "phases_done": ["context", "design", "plan", "build", "review", "validate", "ship"],
  "roadmap": { "path": "docs/roadmap.md", "item": "Validación de filas", "under": "H2 — Importación" },
  "mrs": [
    { "n": 1, "title": "Row schema", "status": "merged", "url": "https://github.com/example/demo/pull/40" },
    { "n": 2, "title": "Per-row errors", "status": "merged", "url": "https://github.com/example/demo/pull/43" }
  ],
  "related_repos": [],
  "followups": [],
  "started_at": "2026-01-02T09:00:00Z",
  "updated_at": "2026-01-09T16:00:00Z",
  "notes": ""
}
JSON
fx_commit "base"
fx_install_cli
