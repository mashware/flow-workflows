---
description: Assistant that generates the FLOW.md for this repo (auto-detects what it can, asks the minimum)
---

# `/flow:init`

Creates (or updates) `FLOW.md` at the repo root. This is the configuration read by all other
`/flow:*` commands. The goal: the user answers the **minimum** — everything that can be inferred
from the repo is auto-detected and only confirmed.

Contract reference and key names: `examples/FLOW.template.md` from the plugin. Do not
invent keys that are not there.

## 1. If `FLOW.md` already exists

If there is a `FLOW.md` at the root, show it and ask: **update** (re-detect and re-ask,
preserving what the user does not want to change), or **cancel**. Do not overwrite without
confirmation.

## 2. Auto-detection (do NOT ask about what you can infer)

Run and deduce; show what was found so the user can confirm or correct:

- **Git host and CLI** — from `git remote -v`:
  - `github.com` → host `github`, cli `gh`, request_term `PR`.
  - `gitlab.*` → `gitlab`, `glab`, `MR`.
  - `bitbucket.org` → `bitbucket`, request_term `PR`.
  - `dev.azure.com`/`visualstudio.com` → `azure`, cli `az`, `PR`.
  - Known Gitea/Forgejo domain → `gitea`, cli `tea`.
  - Unknown domain (self-hosted) → ask which one (GitLab/Gitea/other) and which CLI it uses.
  - Check which CLI is actually installed: `command -v gh glab tea az`.
- **Base branch** — `git symbolic-ref refs/remotes/origin/HEAD` (or `git remote show origin`): `origin/main` or `origin/master` → `git.default_base`.
- **Quality commands** — inspect the repo and propose what you find (leave empty if nothing found):
  - `Makefile` → grep targets `test`, `lint`, `phpstan`/`stan`, `cs-fixer`/`fmt`, `database`/`migrate`.
  - `package.json` → `scripts` (test, lint, build, typecheck).
  - `composer.json` → scripts; presence of phpunit/phpstan/php-cs-fixer.
  - `pyproject.toml`/`tox.ini` → pytest/ruff/mypy; `Cargo.toml` → `cargo test/clippy`; `go.mod` → `go test ./...`.
  - If schema migrations exist (Doctrine, Alembic, Rails, Prisma…), propose `quality.db_diff` and raise `git.predeploy_gate`.
- **domain-memory** — is the `domain-memory` MCP available in this session? If yes, `domain_memory.enabled: true`; if not, leave it empty.

## 3. Ask only what cannot be inferred

For each point, use `AskUserQuestion` with options and a recommended value; always leave the path
"leave empty → auto-discover / skip this". Ask about:

- **Ticket prefix** (`tracker.prefix`, e.g., `PROJ-`, or none) and **how to read a ticket** (`tracker.tool`). Offer the options **without preselecting one** (the git host does not determine the tracker — a GitLab repo may track in Jira): `acli` (Jira), `gh` (GitHub issues), `glab` (GitLab issues), `linear`, or `none` (manual). From the chosen `tool`, set a default `tracker.view_cmd` the user can override: `acli` → `acli jira workitem view {TICKET}`; `gh` → `gh issue view {TICKET}`; `glab` → `glab issue view {TICKET}`; `linear`/`none` → leave empty. When proposing `gh`/`glab`, check the CLI is installed (`command -v gh glab`); if missing, keep the choice but warn the step will degrade to a manual paste until it is.
- **MR/PR assignee** (`git.assignee`, or none) and **squash** (`git.squash`).
- **MR/PR sections** (`git.request_sections`, or free-form).
- **Pre-deploy gate** (`git.predeploy_gate`): do you run schema SQL manually on the server before deploying? If yes and you detected a schema diff command, propose `quality.db_diff`.
- **Agents by role** (`agents.*` and `quality.review_skill`/`reviewers`): optional. Explain that they can be left empty (`general-purpose` is used) and filled in later. If the user has custom agents, collect the names.
- **Observability** (`observability`): default is **empty = auto-discover** in `/flow:work:watch`. Only collect a profile if the user provides one ready to go.

What was auto-detected in §2 is shown as the default value; the user only corrects what does not fit.

## 4. Write `FLOW.md`

Generate the file at the repo root with the **same section structure** as
`examples/FLOW.template.md` (tracker, git, quality, agents, review, conventions, domain_memory,
observability), filling in what was detected/answered and **leaving empty** the keys the user
does not want to fix (each command already degrades gracefully on an empty key).

## 5. Close

Summarize on screen: what was configured and what was left **empty (= auto-discover)**. Remind
the user that `FLOW.md` can be committed (it is team config, not secrets). Suggest the next step:
`/flow:feat:start` or `/flow:work:status`.
