---
description: Assistant that generates the FLOW.md for this repo (auto-detects what it can, asks for the minimum)
---

# flow-init

Creates (or updates) `FLOW.md` at the repo root. This is the configuration read by all other
commands. Goal: minimise what the user has to answer — everything that can be inferred from the
repo is auto-detected and only confirmed. The structure and key names of `FLOW.md` are in the
adapter README (configuration section).

## 1. If `FLOW.md` already exists
Show it and ask the user (in text): **update** (re-detect and re-ask) or **cancel**. Do not overwrite without confirmation.

## 2. Auto-detection (do NOT ask for what can be inferred)
Run and infer; show findings for confirmation or correction:
- **Git host and CLI** — from `git remote -v`: `github.com`→github/`gh`/PR; `gitlab.*`→gitlab/`glab`/MR; `bitbucket.org`→bitbucket/PR; `dev.azure.com`→azure/`az`/PR; Gitea/Forgejo→gitea/`tea`; unknown domain (self-hosted)→ask which host and which CLI. Check installed CLI: `command -v gh glab tea az`.
- **Base branch** — `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` or `origin/master` (`git.default_base`).
- **Quality commands** — inspect the repo and suggest what is present (leave empty if none): `Makefile` (test/lint/stan/fmt/migrate targets), `package.json` scripts, `composer.json` (phpunit/phpstan/cs-fixer), pyproject/pytest/ruff/mypy, Cargo, go. If there are schema migrations, suggest `quality.db_diff` and propose `git.predeploy_gate`.
- **domain-memory** — is the `domain-memory` MCP available? If yes, `domain_memory.enabled: true`.

## 3. Ask only for what cannot be inferred (in text, listing options; always leave "empty → auto-discover")
- Ticket prefix (`tracker.prefix`) and how to read it (`tracker.tool`: `acli`=Jira / `gh`=GitHub issues / `glab`=GitLab issues / `linear` / `none`), offered without preselecting (the git host does not determine the tracker). From the choice, set a default `tracker.view_cmd` the user can override: `acli` → `acli jira workitem view {TICKET}`; `gh` → `gh issue view {TICKET}`; `glab` → `glab issue view {TICKET}`; `linear`/`none` → empty.
- Assignee (`git.assignee`) and squash (`git.squash`).
- MR/PR sections (`git.request_sections`, or free-form).
- Pre-deploy gate (`git.predeploy_gate`): do you run SQL manually before deploying? If yes, suggest `quality.db_diff`.
- Agents by role (`agents.*`, `review.*`): optional; explain that an empty value uses the general sub-agent. If the repo has its own agents (declared in `agents/*.md` for opencode), collect their names.
- Observability: default is **empty = auto-discover** in `work-watch`.

## 4. Write `FLOW.md`
Generate the file at the repo root with all contract sections (tracker, git, quality, agents, review, conventions, domain_memory, observability), filling in what was detected/answered and **leaving empty** what the user did not set.

## 5. Close
Summarise what was configured and what was left empty (= auto-discover). `FLOW.md` is **personal config, not team config** — it mixes repo facts with your own flow preferences (autonomy, the tools/agents you have installed, review depth, assignee) and holds no secrets, but it should not be committed. If it is not already git-ignored, **offer to add `FLOW.md` to `.gitignore`** (this edits a tracked file — confirm first). Suggest `/flow-feat-start` or `/flow-work-status`.
