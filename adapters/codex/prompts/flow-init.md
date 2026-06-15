# flow-init

Crea (o actualiza) el `FLOW.md` en la raíz del repo. Es la configuración que leen el resto de
comandos. Objetivo: que el usuario conteste lo **mínimo** — todo lo deducible del repo se
autodetecta y solo se confirma. La estructura y nombres de clave de `FLOW.md` están en el README
del adaptador y en `AGENTS.md`.

## 1. Si ya existe `FLOW.md`
Muéstralo y pregunta al usuario (en texto): **actualizar** o **cancelar**. No lo sobreescribas sin confirmación.

## 2. Autodetección (NO preguntes lo deducible)
Ejecuta y deduce; muestra lo hallado para confirmar/corregir:
- **Host git y CLI** — de `git remote -v`: `github.com`→github/`gh`/PR; `gitlab.*`→gitlab/`glab`/MR; `bitbucket.org`→bitbucket/PR; `dev.azure.com`→azure/`az`/PR; Gitea/Forgejo→gitea/`tea`; dominio desconocido (self-hosted)→pregunta cuál y qué CLI. Comprueba CLI instalado: `command -v gh glab tea az`.
- **Rama base** — `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` u `origin/master` (`git.default_base`).
- **Comandos de calidad** — inspecciona el repo y propón lo que haya (vacío si no): `Makefile` (targets test/lint/stan/fmt/migrate), `package.json` scripts, `composer.json` (phpunit/phpstan/cs-fixer), pyproject/pytest/ruff/mypy, Cargo, go. Si hay migraciones de esquema, propón `quality.db_diff` y plantea `git.predeploy_gate`.
- **domain-memory** — ¿está el MCP `domain-memory` configurado en `config.toml`? Si sí, `domain_memory.enabled: true`.

## 3. Preguntar solo lo no deducible (en texto, enumerando opciones; deja siempre "vacío → autodescubrir")
- Prefijo de ticket (`tracker.prefix`) y cómo leerlo (`tracker.tool`: acli/gh/linear/none).
- Asignee (`git.assignee`) y squash (`git.squash`).
- Secciones del MR/PR (`git.request_sections`, o libre).
- Freno de pre-deploy (`git.predeploy_gate`): ¿ejecutáis SQL a mano antes de desplegar? Si sí, propón `quality.db_diff`.
- Agentes por rol (`agents.*`, `review.*`): opcional; vacío usa el subagente general. Si tiene agentes propios (secciones `[agents.*]` de `config.toml`), recoge los nombres.
- Observabilidad: por defecto **vacío = autodescubrir** en `work-watch`.

## 4. Escribir `FLOW.md`
Genera el fichero en la raíz con todas las secciones del contrato (tracker, git, quality, agents, review, conventions, domain_memory, observability), rellenando lo detectado/respondido y **dejando vacío** lo que el usuario no fije.

## 5. Cierre
Resume qué quedó configurado y qué vacío (= autodescubrir). `FLOW.md` puede comitearse. Sugiere `/feat-start` o `/work-status`.
