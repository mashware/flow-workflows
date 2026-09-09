# FLOW.md

Configuration for the `flow` plugin for this repository. Every key and its default is documented in
the plugin's `examples/FLOW.template.md`; only the keys with a value are written here.

**This is an example**, filled in for a Symfony + Doctrine + MySQL + Docker Compose repo. It is not
loaded by anything: copy it to your repo root and change what does not apply. See `README.md` in
this folder.

## tracker
- prefix: PROJ-
- tool: acli
- view_cmd: acli jira workitem view {TICKET}
- comments_cmd: acli jira workitem view {TICKET} --comments
- assignee: a.dev
- start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}
- abandon_cmd: acli jira workitem transition {TICKET} "Won't Do"
- debt_log: docs/DEBT.md

## git
- host: gitlab
- cli: glab
- default_base: origin/master
- branch_pattern: {PREFIX}{TICKET}-{slug}
- assignee: a.dev
- squash: true
- request_sections:
  - What changes for the user
  - How it works
  - How to test it
  - Pre-deploy SQL
- predeploy_gate: true
- worktree: ask
- worktree_resync:
  - make database-update
  - make frontend

## autonomy
- mode: guided

## quality
- test: make test && make test-frontend
- test_one: make test-filter filter={FILTER}
- static_analysis: make phpstan-ci
- style_fix: make cs-fixer-changed
- db_update: make database-update
- db_diff: make database-compare
- functional_check: the app runs at https://localhost via `docker compose up -d`; `make fixtures` seeds a dev user (dev@example.com / dev); Chrome automation is available, so an HTTP or UI criterion can be driven end to end
- bench_cmd: docker compose exec -T php bin/console app:bench {TARGET}
- review_depth: proportional
- respond_max_rounds: 3
- reviewers:
  - symfony-reviewer
  - doctrine-query-reviewer
  - symfony-security-reviewer

## agents
- architecture: symfony-reviewer
- persistence: doctrine-query-reviewer
- api: symfony-reviewer
- performance: doctrine-query-reviewer
- security: symfony-security-reviewer
- testing: phpunit-tdd-guide
- fanout_max: 4
- budget_max: 12

## data
- explain_cmd: docker compose exec -T mysql mysql app -e "EXPLAIN ANALYZE {QUERY}"
- schema_cmd: docker compose exec -T mysql mysql app -e "SHOW CREATE TABLE {TABLE}"
- sandbox_cmd: docker compose exec -T mysql mysql -e "CREATE DATABASE {NAME}"
- volumes:
  - orders: ~12M rows, +400k/month, worst customer_id ~9k rows
  - order_events: ~180M rows, +6M/month, `payload` averages 900B, p99 14KB
  - customers: ~900k rows, effectively static

## conventions
- Domain / Application / Infrastructure, one bounded context per `src/<Context>/`. A class under `Domain/` imports nothing from Symfony or Doctrine.
- Application layer is commands and queries with one handler each; a handler returns a DTO, never an entity.
- Repository interfaces live in `Domain/`, their Doctrine implementations in `Infrastructure/Persistence/`. No `EntityManager` outside that folder.
- Mappings are XML under `Infrastructure/Persistence/Doctrine/mapping/`; no attributes or annotations on entity classes.
- Entities have no public setters. State changes through intention-revealing methods that record a domain event.
- A domain event is handled by a Messenger handler, never by a Doctrine lifecycle listener.
- Controllers are single-action `__invoke`, thin: validate the request DTO, dispatch, serialize. No business rule in a controller.
- Every new endpoint ships with a functional test that boots the kernel; a use case ships with a unit test that does not.
- Never mock a repository interface in a Domain unit test — use the in-memory implementation in `tests/Double/`.
- Migrations are generated (`make database-diff`), then read and edited by hand: no destructive statement without an explicit down.

## notes
- all: prices are integer cents in a `Money` value object; a float amount anywhere is a bug.
- feat:design: name the bounded context the change belongs to before proposing classes.

## knowledge
- search:
  - mcp__domain-memory__search_knowledge
  - mcp__codegraph__query
- stage: mcp__domain-memory__stage_finding
- read_staging: mcp__domain-memory__read_staging
- save: mcp__domain-memory__save_knowledge
