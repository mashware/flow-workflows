# FLOW.md

Configuración del plugin `flow` para este repositorio. Los comandos `/flow:*` leen este
fichero en su paso 0. Borra lo que no apliques; **lo vacío o ausente = autodescubrir o
comportamiento por defecto** (cada comando dice qué hace si falta un dato).

Colócalo en la raíz del repo (puede comitearse: es config de equipo, no secretos).

## tracker
Cómo se identifican y leen los tickets.

- `prefix:`            # p.ej. `PROJ-`. Vacío = sin prefijo / ticket de forma libre.
- `tool:`             # `acli` (Jira) | `gh` (GitHub issues) | `linear` | `none` (manual). Vacío = none.
- `view_cmd:`         # opcional, comando para ver un ticket. `{TICKET}` se sustituye. Ej: `acli jira workitem view {TICKET}`

## git
Convenciones de rama y de Pull/Merge Request.

- `host:`             # `gitlab` | `github`. Decide la terminología y el CLI por defecto.
- `cli:`              # `glab` | `gh`. Vacío = se deduce de `host`.
- `request_term:`     # `MR` | `PR`. Cómo nombrar el request en los textos. Vacío = se deduce de `host`.
- `default_base:`     # base de ramas nuevas, p.ej. `origin/master` u `origin/main`.
- `branch_pattern:`   # p.ej. `{PREFIX}{TICKET}-{slug}`. `{slug}` en inglés, kebab-case.
- `assignee:`         # usuario al que se asigna el MR/PR. Vacío = no asignar.
- `squash:`           # `true` | `false` (squash-before-merge).
- `request_sections:` # secciones de la descripción del MR/PR, una por línea con `- `. Vacío = libre.
- `predeploy_gate:`   # `true` si este repo ejecuta el SQL de esquema a mano en el servidor ANTES de desplegar y quiere frenar el MR/PR hasta hacerlo. Vacío/false = sin sección Pre-deploy ni hilo bloqueante.

## quality
Comandos del repo para los quality gates. **Vacío = el comando autodescubre** (Makefile,
scripts de npm/composer, etc.) y avisa de lo que use.

- `test:`             # ej. `make test`
- `test_one:`         # ej. `make test-filter filter={FILTER}` (`{FILTER}` se sustituye)
- `static_analysis:`  # ej. `make phpstan-ci`
- `style_fix:`        # ej. `make cs-fixer-changed`
- `db_update:`        # ej. `make database-update` (vacío si no aplica)
- `db_diff:`          # comando que muestra el SQL de esquema pendiente de aplicar, ej. `make database-compare` (para el SQL de pre-deploy)
- `frontend_test:`    # ej. `make test-frontend` (vacío si no hay frontend)
- `review_skill:`     # skill orquestador del panel de code-review en /flow:*:review. Vacío = no hay skill; mira `reviewers` abajo.
- `reviewers:`        # si `review_skill` está vacío: lista de agentes que corren en paralelo como panel de review (uno por línea con `- `). Vacío y sin skill = solo el built-in `code-review`.

## agents
Mapa rol→agente para los pasos que delegan en un especialista (`design`, `investigate`,
`validate`, `plan`, `build`, `fix`, `watch`, y los refuerzos por área de `review`). Los agentes
deben existir y ser descubribles en la máquina (`~/.claude/agents`, `.agents/agents` del repo, u
otro plugin) — esto solo dice **cuál** invocar, no lo crea. **Rol vacío = el comando usa
`Agent general-purpose` con el rol en el prompt, o se salta el paso si era opcional.**

- `architecture:`   # diseño/capas/arquitectura
- `persistence:`    # BD/ORM/mappings/migraciones/consultas
- `api:`            # endpoints/DTO/rutas/contratos HTTP
- `performance:`    # N+1, índices, hot paths, carga
- `queues:`         # colas, mensajes muertos, workers
- `security:`       # amenazas, autenticación, datos sensibles
- `frontend:`       # componentes/UI
- `frontend_test:`  # tests de frontend
- `testing:`        # tests de backend / cobertura

## conventions
Texto libre: convenciones que los comandos deben respetar al escribir/revisar código
(capas, patrones, prohibiciones). Vacío = sin convenciones específicas.

<!-- ej.: DDD (Domain/Application/Infrastructure); no #[AsMessageHandler]; etc. -->

## domain_memory
Conocimiento de dominio vía el MCP `domain-memory` (https://github.com/mashware/domain-memory).

- `enabled:`          # `true` si el MCP está instalado e iniciado. Vacío/false = los comandos
                      # saltan los pasos de search/stage/save de dominio sin avisar.

## observability
Perfil para `/flow:work:watch` (vigilancia post-deploy). **Vacío = el comando autodescubre
todo** (servicios, dashboards, monitores) como hace su fase de descubrimiento.

- `platform:`         # `datadog` | otro. Vacío = autodescubrir.
- `site:`             # ej. `app.datadoghq.com` (org/site).
- `deploy_detect:`    # cómo identificar TU deploy. Texto libre. Ej: "merge→pipeline padre (glab por SHA)→bridge→pipeline hija→jobs de go-live".
- `services:`         # uno por línea: `name | role(web|workers|...) | apm:<query> | logs:<filtro> | sql:<service> | deploy_job:<job>`
- `queues:`           # ej. `rabbitmq, *_dlx por delta`
- `notes:`            # baselines/umbrales medidos, flags de bajo tráfico, etc.
