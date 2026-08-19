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
- **Data access** (`data.*`, all optional) — only if the repo talks to a database: find the client and the local stack (a compose service, a `DATABASE_URL`/`DB_*` env var, a `Makefile` target that opens a shell) and propose `data.explain_cmd` and `data.schema_cmd` in the engine's dialect **against the development database** (MySQL over compose: `docker compose exec -T <db> mysql <schema> -e "EXPLAIN {QUERY}"` / `… -e "SHOW CREATE TABLE {TABLE}"`; PostgreSQL: `psql -c "EXPLAIN (ANALYZE, BUFFERS) {QUERY}"` / `\d+ {TABLE}`). Leave `sandbox_cmd`/`seed_cmd`/`volumes` empty unless the user has something ready; if nothing is detected, leave the section out — the query duel degrades to schema-only and says so.
- **domain-memory** — is the `domain-memory` MCP available? If yes, `domain_memory.enabled: true`.

## 3. Ask only for what cannot be inferred (in text, listing options; always leave "empty → auto-discover")
- Ticket prefix (`tracker.prefix`) and how to read it (`tracker.tool`: `acli`=Jira / `gh`=GitHub issues / `glab`=GitLab issues / `linear` / `none`), offered without preselecting (the git host does not determine the tracker). From the choice, set a default `tracker.view_cmd` the user can override: `acli` → `acli jira workitem view {TICKET}`; `gh` → `gh issue view {TICKET}`; `glab` → `glab issue view {TICKET}`; `linear`/`none` → empty. Set `tracker.comments_cmd` from the same choice (the `view_cmd`s print only the description, and the comment thread is where scope decisions and a sibling repo's published contracts live): `gh` → `gh issue view {TICKET} --comments`; `glab` → `glab issue view {TICKET} --comments`; `acli`/`linear`/`none` → empty.
- **Ticket state transitions** (`tracker.start_cmd` / `done_cmd` / `abandon_cmd` / `assignee`): optional, so tickets don't sit stale in the backlog — flow can move them to *in progress* on start, *done* on ship, *won't-do* on abandon. **Ask only if `tracker.tool` is `acli` (Jira) or `linear`**; for `gh`/`glab` skip and leave them empty (merge already auto-closes the issue via `Closes #N`), for `none` skip entirely. When asked, offer sensible defaults the user confirms/edits and explain each may be left empty: Jira → `start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}`, `done_cmd: acli jira workitem transition {TICKET} "Done"`, `abandon_cmd: acli jira workitem transition {TICKET} "Won't Do"` (state names vary per board — tell the user to match theirs). Collect `tracker.assignee` (the tracker account for `{ASSIGNEE}`; empty = fall back to `git.assignee`). Note they run best-effort and gated, and never block.
- Assignee (`git.assignee`) and squash (`git.squash`).
- MR/PR sections (`git.request_sections`, or free-form).
- Pre-deploy gate (`git.predeploy_gate`): do you run SQL manually before deploying? If yes, suggest `quality.db_diff`.
- Agents by role (`agents.*`, `review.*`): optional; explain that an empty value uses the general sub-agent. If the repo has its own agents (declared in `agents/*.md` for opencode), collect their names.
- **Data access** (`data.*`): ask only if a database was detected. Show the `explain_cmd`/`schema_cmd` you found for confirmation and say what they unlock — with them, the query duel settles an index or a collation question with a real plan instead of an argument; without them it still runs on the schema alone and declares what it could not prove. Then ask for **`data.volumes`** (real sizes of the hot tables: rows, growth, worst key): that one line is what stops a reviewer agent from inventing the volume it argues about, and it is worth filling even when the commands are empty. `sandbox_cmd`/`seed_cmd` only for repos that already have a throwaway database; creating or seeding one is a hard gate in every mode.
- Observability: default is **empty = auto-discover** in `work-watch`.

## 4. Write `FLOW.md`
Generate the file at the repo root with all contract sections — tracker, git, autonomy, quality, agents, models, data, conventions, notes, domain_memory, observability, in that order — filling in what was detected/answered and **leaving empty** what the user did not set (every command degrades gracefully on an empty key). There is no `review` section: the review panel is configured by `quality.review_depth`, `quality.review_skill` and `quality.reviewers`. When in doubt about a key or its default, the repo's `examples/FLOW.template.md` is the canonical list — read it rather than reproducing it from here.

## 5. Close
Summarise what was configured and what was left empty (= auto-discover). `FLOW.md` is **personal config, not team config** — it mixes repo facts with your own flow preferences (autonomy, the tools/agents you have installed, review depth, assignee) and holds no secrets, but it should not be committed. If it is not already git-ignored, **offer to add `FLOW.md` to `.gitignore`** (this edits a tracked file — confirm first). Suggest `/flow-feat-start` or `/flow-work-status`.

**`models`**: write the section with every key empty and do **not** ask about it unless the user brings up models themselves — empty means each step runs with the model the session was launched with, which is what everyone expects by default. Mention in the close that the section exists and where it is documented.
