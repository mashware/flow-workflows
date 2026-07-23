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
- **Ticket state transitions** (`tracker.start_cmd` / `done_cmd` / `abandon_cmd` / `assignee`): optional, so tickets don't sit stale in the backlog — flow can move them to *in progress* on start, *done* on ship, *won't-do* on abandon. **Ask only if `tracker.tool` is `acli` (Jira) or `linear`**; for `gh`/`glab` skip and leave them empty (merge already auto-closes the issue via `Closes #N`), for `none` skip entirely. When asked, offer sensible defaults the user confirms/edits and explain each may be left empty: Jira → `start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}`, `done_cmd: acli jira workitem transition {TICKET} "Done"`, `abandon_cmd: acli jira workitem transition {TICKET} "Won't Do"` (state names vary per board — tell the user to match theirs). Collect `tracker.assignee` (the tracker account for `{ASSIGNEE}`; empty = fall back to `git.assignee`). Note they run best-effort and gated, and never block.
- **MR/PR assignee** (`git.assignee`, or none) and **squash** (`git.squash`).
- **MR/PR sections** (`git.request_sections`, or free-form).
- **Pre-deploy gate** (`git.predeploy_gate`): do you run schema SQL manually on the server before deploying? If yes and you detected a schema diff command, propose `quality.db_diff`.
- **Train chaining** (`git.train_chain`): optional, only relevant for multi-PR features on stacked branches. Explain the default (empty = derived from `autonomy.mode`: `manual` asks "continue with the next MR/PR?", `guided`/`auto` chain automatically — the train never waits for the previous MR/PR to merge). Only set `ask`/`always`/`wait` if the user wants to override that. Most repos leave it empty.
- **Agents by role** (`agents.*` and `quality.review_skill`/`reviewers`): optional. Explain that they can be left empty (`general-purpose` is used) and filled in later. If the user has custom agents, collect the names.
- **Review depth** (`quality.review_depth`): default `proportional` scales the review panel by work size (XS/small changes get only the built-in `code-review`, keeping trivial changes fast; the specialized panel runs on M/L and on sensitive small changes). Only set `full` if the user wants the whole panel on every change regardless of size. Most repos leave it empty (= proportional).
- **Autonomy** (`autonomy.mode`): how much the flow advances on its own. Offer `manual` *(Recommended)* — every phase stops at each decision and only recommends the next command (current behavior) — `guided` — auto-resolves low-risk/unambiguous decisions and chains phases, still asking at real decision points — or `auto` — also auto-resolves the rest with recorded defaults. Explain that the hard gates (push/MR-PR, ambiguous-base branch creation, DB/migrations, high-severity review findings) always stop and ask regardless of the mode, and that it can be changed at any time by editing `FLOW.md`. Empty = `manual`.
- **Observability** (`observability`): default is **empty = auto-discover** in `/flow:work:watch`. Only collect a profile if the user provides one ready to go.

What was auto-detected in §2 is shown as the default value; the user only corrects what does not fit.

## 4. Write `FLOW.md`

Generate the file at the repo root with the **same section structure** as
`examples/FLOW.template.md` (tracker, git, autonomy, quality, agents, review, conventions,
domain_memory, observability), filling in what was detected/answered and **leaving empty** the keys
the user does not want to fix (each command already degrades gracefully on an empty key).

## 5. Close

Summarize on screen: what was configured and what was left **empty (= auto-discover)**.

`FLOW.md` is **personal config, not team config**: it mixes repo facts (tracker, quality commands,
conventions) with your own flow preferences (autonomy mode, the tools/agents you have installed,
review depth, assignee) — what one developer wants differs from the next, and the same file on
another machine may reference agents or an MCP that isn't there. It holds **no secrets** (those
stay in your credential store), but it should not be committed. So: if `FLOW.md` is not already
git-ignored, **offer to add it to `.gitignore`** (append a `FLOW.md` line) — this edits a tracked
file, so confirm before writing. A team that wants to share the repo-fact subset can still commit
it deliberately.

Then suggest the next step: `/flow:feat:start` or `/flow:work:status`.
