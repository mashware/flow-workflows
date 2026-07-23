# flow-init

Creates (or updates) the `FLOW.md` at the repo root. It's the configuration read by all other
commands. Goal: the user answers the **minimum** — everything that can be deduced from the repo
is auto-detected and only confirmed. The structure and key names of `FLOW.md` are in the adapter
README and in `AGENTS.md`.

## 1. If `FLOW.md` already exists
Show it and ask the user (in text): **update** or **cancel**. Don't overwrite without confirmation.

## 2. Auto-detection (do NOT ask for what can be deduced)
Run and deduce; show findings to confirm/correct:
- **Git host and CLI** — from `git remote -v`: `github.com`→github/`gh`/PR; `gitlab.*`→gitlab/`glab`/MR; `bitbucket.org`→bitbucket/PR; `dev.azure.com`→azure/`az`/PR; Gitea/Forgejo→gitea/`tea`; unknown domain (self-hosted)→ask which one and what CLI. Check installed CLI: `command -v gh glab tea az`.
- **Base branch** — `git symbolic-ref refs/remotes/origin/HEAD` → `origin/main` or `origin/master` (`git.default_base`).
- **Quality commands** — inspect the repo and propose what's there (empty if none): `Makefile` (targets test/lint/stan/fmt/migrate), `package.json` scripts, `composer.json` (phpunit/phpstan/cs-fixer), pyproject/pytest/ruff/mypy, Cargo, go. If there are schema migrations, propose `quality.db_diff` and raise `git.predeploy_gate`.
- **domain-memory** — is the `domain-memory` MCP configured in `config.toml`? If yes, `domain_memory.enabled: true`.

## 3. Ask only for what cannot be deduced (in text, listing options; always leave "empty → auto-discover")
- Ticket prefix (`tracker.prefix`) and how to read it (`tracker.tool`: `acli`=Jira / `gh`=GitHub issues / `glab`=GitLab issues / `linear` / `none`), offered without preselecting (the git host does not determine the tracker). From the choice, set a default `tracker.view_cmd` the user can override: `acli` → `acli jira workitem view {TICKET}`; `gh` → `gh issue view {TICKET}`; `glab` → `glab issue view {TICKET}`; `linear`/`none` → empty.
- **Ticket state transitions** (`tracker.start_cmd` / `done_cmd` / `abandon_cmd` / `assignee`): optional, so tickets don't sit stale in the backlog — flow can move them to *in progress* on start, *done* on ship, *won't-do* on abandon. **Ask only if `tracker.tool` is `acli` (Jira) or `linear`**; for `gh`/`glab` skip and leave them empty (merge already auto-closes the issue via `Closes #N`), for `none` skip entirely. When asked, offer sensible defaults the user confirms/edits and explain each may be left empty: Jira → `start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}`, `done_cmd: acli jira workitem transition {TICKET} "Done"`, `abandon_cmd: acli jira workitem transition {TICKET} "Won't Do"` (state names vary per board — tell the user to match theirs). Collect `tracker.assignee` (the tracker account for `{ASSIGNEE}`; empty = fall back to `git.assignee`). Note they run best-effort and gated, and never block.
- Assignee (`git.assignee`) and squash (`git.squash`).
- MR/PR sections (`git.request_sections`, or free-form).
- Pre-deploy brake (`git.predeploy_gate`): do you run SQL manually before deploying? If yes, propose `quality.db_diff`.
- Agents by role (`agents.*`, `review.*`): optional; empty uses the general subagent. If it has custom agents (`[agents.*]` sections in `config.toml`), collect the names.
- Observability: default **empty = auto-discover** in `work-watch`.

## 4. Write `FLOW.md`
Generate the file at the root with all contract sections (tracker, git, quality, agents, review, conventions, domain_memory, observability), filling in what was detected/answered and **leaving empty** what the user didn't set.

## 5. Close
Summarize what was configured and what was left empty (= auto-discover). `FLOW.md` is **personal config, not team config** — it mixes repo facts with your own flow preferences (autonomy, the tools/agents you have installed, review depth, assignee) and holds no secrets, but it should not be committed. If it is not already git-ignored, **offer to add `FLOW.md` to `.gitignore`** (this edits a tracked file — confirm first). Suggest `/flow-feat-start` or `/flow-work-status`.
