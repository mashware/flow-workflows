---
description: Asistente que genera el FLOW.md de este repo (autodetecta lo que puede, pregunta lo mínimo)
---

# `/flow:init`

Crea (o actualiza) el `FLOW.md` en la raíz del repo. Es la configuración que leen el resto de
comandos `/flow:*`. El objetivo: que el usuario conteste lo **mínimo** — todo lo deducible del
repo se autodetecta y solo se confirma.

Referencia del contrato y los nombres de clave: `examples/FLOW.template.md` del plugin. No
inventes claves que no estén ahí.

## 1. Si ya existe `FLOW.md`

Si hay un `FLOW.md` en la raíz, muéstralo y pregunta: **actualizar** (re-detecta y re-pregunta,
conservando lo que el usuario no quiera cambiar), o **cancelar**. No lo sobreescribas sin
confirmación.

## 2. Autodetección (NO preguntes lo que puedas deducir)

Ejecuta y deduce; muestra lo encontrado para que el usuario lo confirme o corrija:

- **Host git y CLI** — de `git remote -v`:
  - `github.com` → host `github`, cli `gh`, request_term `PR`.
  - `gitlab.*` → `gitlab`, `glab`, `MR`.
  - `bitbucket.org` → `bitbucket`, request_term `PR`.
  - `dev.azure.com`/`visualstudio.com` → `azure`, cli `az`, `PR`.
  - dominio de Gitea/Forgejo conocido → `gitea`, cli `tea`.
  - dominio desconocido (self-hosted) → pregunta cuál es (GitLab/Gitea/otro) y qué CLI usa.
  - Comprueba qué CLI está instalado de verdad: `command -v gh glab tea az`.
- **Rama base** — `git symbolic-ref refs/remotes/origin/HEAD` (o `git remote show origin`): `origin/main` u `origin/master` → `git.default_base`.
- **Comandos de calidad** — inspecciona el repo y propón lo que encuentres (vacío si no hay):
  - `Makefile` → grep de targets `test`, `lint`, `phpstan`/`stan`, `cs-fixer`/`fmt`, `database`/`migrate`.
  - `package.json` → `scripts` (test, lint, build, typecheck).
  - `composer.json` → scripts; presencia de phpunit/phpstan/php-cs-fixer.
  - `pyproject.toml`/`tox.ini` → pytest/ruff/mypy; `Cargo.toml` → `cargo test/clippy`; `go.mod` → `go test ./...`.
  - Si hay migraciones de esquema (Doctrine, Alembic, Rails, Prisma…), propón `quality.db_diff` y plantea `git.predeploy_gate`.
- **domain-memory** — ¿está el MCP `domain-memory` disponible en esta sesión? Si sí, `domain_memory.enabled: true`; si no, déjalo vacío.

## 3. Preguntar solo lo no deducible

Para cada punto, usa `AskUserQuestion` con opciones y un valor recomendado; deja siempre la vía
"dejar vacío → autodescubrir / sin esto". Pregunta:

- **Prefijo de ticket** (`tracker.prefix`, ej. `PROJ-`, o ninguno) y **cómo leer un ticket** (`tracker.tool`: acli/gh/linear/none).
- **Asignee** del MR/PR (`git.assignee`, o ninguno) y **squash** (`git.squash`).
- **Secciones** del MR/PR (`git.request_sections`, o libre).
- **Freno de pre-deploy** (`git.predeploy_gate`): ¿ejecutáis SQL a mano en el servidor antes de desplegar? Si sí y detectaste un comando de diff de esquema, propón `quality.db_diff`.
- **Agentes por rol** (`agents.*` y `quality.review_skill`/`reviewers`): opcional. Explica que se pueden dejar vacíos (se usa `general-purpose`) y rellenar luego. Si el usuario tiene agentes propios, recoge los nombres.
- **Observabilidad** (`observability`): por defecto **vacío = autodescubrir** en `/flow:work:watch`. Solo recoge perfil si el usuario lo da hecho.

Lo autodetectado en §2 se muestra como valor por defecto; el usuario solo corrige lo que no encaje.

## 4. Escribir `FLOW.md`

Genera el fichero en la raíz del repo con la **misma estructura de secciones** que
`examples/FLOW.template.md` (tracker, git, quality, agents, review, conventions, domain_memory,
observability), rellenando lo detectado/respondido y **dejando vacías** las claves que el usuario
no quiera fijar (cada comando ya degrada con elegancia ante una clave vacía).

## 5. Cierre

Resume en pantalla: qué quedó configurado y qué quedó **vacío (= autodescubrir)**. Recuerda que
`FLOW.md` puede comitearse (es config de equipo, no secretos). Sugiere el siguiente paso:
`/flow:feat:start` o `/flow:work:status`.
