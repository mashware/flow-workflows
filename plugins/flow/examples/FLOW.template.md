# FLOW.md

Configuration for the `flow` plugin for this repository. The `/flow:*` commands read this
file in their step 0. Delete what does not apply; **empty or absent = auto-discover or
default behavior** (each command states what it does when a value is missing).

Place it at the repo root (can be committed: it is team config, not secrets).

## tracker
How tickets are identified and read.

- `prefix:`            # e.g. `PROJ-`. Empty = no prefix / free-form ticket.
- `tool:`             # `acli` (Jira) | `gh` (GitHub issues) | `glab` (GitLab issues) | `linear` | `none` (manual). Empty = none.
- `view_cmd:`         # optional, command to view a ticket. `{TICKET}` is substituted. e.g.:
                      #   Jira:   `acli jira workitem view {TICKET}`
                      #   GitHub: `gh issue view {TICKET}`
                      #   GitLab: `glab issue view {TICKET}`

## git
Branch and Pull/Merge Request conventions.

- `host:`             # `gitlab` | `github`. Determines the terminology and default CLI.
- `cli:`              # `glab` | `gh`. Empty = inferred from `host`.
- `request_term:`     # `MR` | `PR`. How to name the request in text. Empty = inferred from `host`.
- `default_base:`     # base for new branches, e.g. `origin/master` or `origin/main`.
- `branch_pattern:`   # e.g. `{PREFIX}{TICKET}-{slug}`. `{slug}` in English, kebab-case.
- `assignee:`         # user to assign the MR/PR to. Empty = do not assign.
- `squash:`           # `true` | `false` (squash-before-merge).
- `request_sections:` # MR/PR description sections, one per line with `- `. Empty = free-form.
- `predeploy_gate:`   # `true` if this repo runs schema SQL manually on the server BEFORE deploying and wants to block the MR/PR until done. Empty/false = no Pre-deploy section or blocking thread.
- `train_chain:`      # multi-PR train (stacked branches) behavior at the end of `/flow:feat:ship` when there are still pending MR/PRs. `ask` | `always` | `wait`. The train NEVER waits for the previous MR/PR to merge except in `wait`.
                      #   ask    → ask "continue with the next MR/PR?" and, on yes, create the next stacked branch and chain into `/flow:feat:build`.
                      #   always → chain into the next MR/PR's `/flow:feat:build` automatically (records it), no prompt.
                      #   wait   → do NOT continue: stop and recommend continuing only after the current MR/PR is merged (legacy behavior).
                      # Empty = derive from `autonomy.mode`: `manual` → `ask`; `guided`/`auto` → `always`.
- `worktree:`         # `off` (default) | `ask` | `always`. Whether `/flow:feat:start` & `/flow:bug:start` create the new branch as a git worktree instead of switching in place. `ask` = prompt each time; `always` = always; `off`/empty = never (in-place, current behavior).
- `worktree_path:`    # path template for the worktree dir. `{branch}` and `{repo}` are substituted. Empty with `worktree`≠`off` = `.worktrees/{branch}` at the repo root (git-ignore it). e.g. `.worktrees/{branch}` or `../{repo}.worktrees/{branch}`.
- `worktree_resync:`   # commands `/flow:work:try` runs after switching the main checkout to a branch (and again on `--back`), to re-sync the environment (e.g. DB schema, assets). One command per line with `- `, run in order. Empty = `/flow:work:try` only does the git switch, no env re-sync. e.g.:
                      #   - make database-update
                      #   - make frontend

## autonomy
How much the flow advances on its own vs. stopping to ask you.

- `mode:`             # `manual` (default) | `guided` | `auto`. Empty = `manual`.
                      #   manual — current behavior: every phase stops at each decision point and, at the
                      #            end, only recommends the next command (never invokes it).
                      #   guided — the command resolves low-risk, unambiguous decisions itself with the
                      #            recommended default (recorded in the phase artifact) instead of asking,
                      #            still asks at genuine decision points, and chains into the next command.
                      #   auto   — as guided, plus auto-resolves the remaining decision points with sensible
                      #            (recorded) defaults, chaining phases without pausing.
                      # HARD GATES stop and ask in EVERY mode, no exceptions: any push or MR/PR (ship),
                      # branch creation with an ambiguous base, DB schema changes/migrations, and a review
                      # with high-severity findings.

## quality
Repo commands for quality gates. **Empty = the command auto-discovers** (Makefile,
npm/composer scripts, etc.) and reports what it uses.

- `test:`             # e.g. `make test`
- `test_one:`         # e.g. `make test-filter filter={FILTER}` (`{FILTER}` is substituted)
- `static_analysis:`  # e.g. `make phpstan-ci`
- `style_fix:`        # e.g. `make cs-fixer-changed`
- `db_update:`        # e.g. `make database-update` (empty if not applicable)
- `db_diff:`          # command that shows pending schema SQL, e.g. `make database-compare` (for pre-deploy SQL)
- `frontend_test:`    # e.g. `make test-frontend` (empty if no frontend)
- `review_depth:`     # how much of the review panel runs, scaled by work size, in `/flow:*:review`. `proportional` (default) | `full`.
                      #   proportional → XS: only the built-in `code-review` (medium effort), no panel. S: built-in `code-review` (high) plus
                      #                  the panel ONLY if the diff touches a sensitive surface (auth/authorization, secrets, payments/billing,
                      #                  personal/sensitive data, a public API/contract shape, or a DB migration/schema change); otherwise built-in only.
                      #                  M/L: full panel. Keeps trivial changes fast without giving up depth where it matters.
                      #   full         → always run the built-in `code-review` (high) + the full panel regardless of size (pre-0.7 behavior).
                      # Empty = `proportional`.
- `review_skill:`     # orchestrating skill for the code-review panel in /flow:*:review. Empty = no skill; see `reviewers` below.
- `reviewers:`        # if `review_skill` is empty: list of agents that run in parallel as a review panel (one per line with `- `). Empty with no skill = only the built-in `code-review`.

## agents
Role→agent map for steps that delegate to a specialist (`design`, `investigate`,
`validate`, `plan`, `build`, `fix`, `watch`, and the area reinforcements in `review`). Agents
must exist and be discoverable on the machine (`~/.claude/agents`, `.agents/agents` in the repo, or
another plugin) — this only states **which** one to invoke, it does not create it. **Empty role = the command uses
`Agent general-purpose` with the role in the prompt, or skips the step if it was optional.**

- `architecture:`   # design/layers/architecture
- `persistence:`    # DB/ORM/mappings/migrations/queries
- `api:`            # endpoints/DTOs/routes/HTTP contracts
- `performance:`    # N+1, indexes, hot paths, load
- `queues:`         # queues, dead-letter, workers
- `security:`       # threats, authentication, sensitive data
- `frontend:`       # components/UI
- `frontend_test:`  # frontend tests
- `testing:`        # backend tests / coverage

## conventions
Free text: conventions the commands must respect when writing/reviewing code
(layers, patterns, prohibitions). Empty = no specific conventions.

<!-- e.g.: DDD (Domain/Application/Infrastructure); no #[AsMessageHandler]; etc. -->

## notes
Per-command extra guidance. When a command runs, it MUST follow the entry matching its command
plus the `all` entry, as **mandatory additional instructions for that step**, on top of the
command's built-in logic. Use the logical command id (`feat:design`, `bug:fix`, `work:watch`),
regardless of how your harness spells the invocation. Keep each note short and specific (a
reminder, not a second manual). Empty = no extra guidance.

- `all:`             # applies to every command
- `feat:design:`     # add only the commands you want to extend; any command id works
- `bug:fix:`
- `work:watch:`

## domain_memory
Domain knowledge via the `domain-memory` MCP (https://github.com/mashware/domain-memory).

- `enabled:`          # `true` if the MCP is installed and running. Empty/false = commands
                      # skip the domain search/stage/save steps silently.

## observability
Profile for `/flow:work:watch` (post-deploy monitoring). **Empty = the command auto-discovers
everything** (services, dashboards, monitors) in its discovery phase.

- `platform:`         # `datadog` | other. Empty = auto-discover.
- `site:`             # e.g. `app.datadoghq.com` (org/site).
- `deploy_detect:`    # how to identify YOUR deploy. Free text. e.g.: "merge→parent pipeline (glab by SHA)→bridge→child pipeline→go-live jobs".
- `services:`         # one per line: `name | role(web|workers|...) | apm:<query> | logs:<filter> | sql:<service> | deploy_job:<job>`
- `queues:`           # e.g. `rabbitmq, *_dlx by delta`
- `notes:`            # measured baselines/thresholds, low-traffic flags, etc.
