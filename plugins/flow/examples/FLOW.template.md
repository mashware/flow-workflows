# FLOW.md

Configuration for the `flow` plugin for this repository. The `/flow:*` commands read this
file in their step 0. Delete what does not apply; **empty or absent = auto-discover or
default behavior** (each command states what it does when a value is missing).

Place it at the repo root. This is **personal config, not team config** — it mixes repo facts
(tracker, quality commands, conventions) with your own flow preferences (autonomy mode, the
tools/agents you have installed, review depth, assignee), so what one developer wants differs from
the next and the same file on another machine may point at agents or an MCP that isn't there. It
holds **no secrets** (those stay in your credential store), but **add `FLOW.md` to your
`.gitignore`** — `/flow:init` offers to do this for you. A team that wants to share the repo-fact
subset can still commit it deliberately.

## tracker
How tickets are identified and read.

- `prefix:`            # e.g. `PROJ-`. Empty = no prefix / free-form ticket.
- `tool:`             # `acli` (Jira) | `gh` (GitHub issues) | `glab` (GitLab issues) | `linear` | `none` (manual). Empty = none.
- `view_cmd:`         # optional, command to view a ticket. `{TICKET}` is substituted. e.g.:
                      #   Jira:   `acli jira workitem view {TICKET}`
                      #   GitHub: `gh issue view {TICKET}`
                      #   GitLab: `glab issue view {TICKET}`
- `comments_cmd:`     # optional, command to read the ticket's COMMENT THREAD. `{TICKET}` substituted. The `view_cmd`s above
                      # print only the description, and the thread is where scope changes and the contracts published by a
                      # sibling repo live (`/flow:feat:ship` §6.3 posts them as a comment) — so `start` reads it too. e.g.:
                      #   GitHub: `gh issue view {TICKET} --comments`
                      #   GitLab: `glab issue view {TICKET} --comments`
                      # Empty = derived from `tool` for `gh`/`glab`; for Jira/`linear` the commands try the native way once
                      # and, if there is none, warn in one line that the thread was not read (never silently assume it was empty).
- `assignee:`         # tracker username/account for the `{ASSIGNEE}` token in the commands below. Empty = fall back to `git.assignee`.
- `start_cmd:`        # optional, run when a work STARTS (`/flow:feat:start`, `/flow:bug:start`) to move the ticket to "in progress" and/or assign it. `{TICKET}` and `{ASSIGNEE}` substituted; chain two calls with `&&`. Empty = do not transition on start. e.g.:
                      #   Jira: `acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}`
- `done_cmd:`         # optional, run when a work SHIPS and is merged (`phase` reaches `done`) to move the ticket to "done". `{TICKET}` substituted. Empty = do not transition. **Leave empty on GitHub/GitLab** — the `Closes #N` in the MR/PR body already auto-closes the issue on merge. e.g.:
                      #   Jira: `acli jira workitem transition {TICKET} "Done"`
- `abandon_cmd:`      # optional, run when a work is ABANDONED (`/flow:work:abandon`) to move the ticket to a cancelled / won't-do state. `{TICKET}` substituted. Empty = do not transition. e.g.:
                      #   Jira: `acli jira workitem transition {TICKET} "Won't Do"`
                      #
                      # The three `*_cmd` transitions are **best-effort, idempotent, and gated**: outward-facing, so
                      # they are asked before running in `autonomy.mode: manual` and run automatically in `guided`/`auto`;
                      # a failure or an already-in-state ticket warns and continues, never blocks. They run only in
                      # ticket mode with a real tracker id (skipped for ticket-less / local-only works).
- `debt_log:`         # optional. Versioned Markdown file where `ship` appends the follow-ups that are recorded but never asked about (flow-core §7): `tooling` gaps in the repo's own
                      #   machinery — a test that does not bind, a guard with slack, stale prose — plus whatever the skeptic ruled real-but-nobody's-next-task and whatever sat above
                      #   `followup_ask_max`. Empty = `docs/DEBT.md`, created on first use. One file per repo.
- `followup_ask_max:` # how many parked findings one finished work may turn into questions at `ship`'s Close (flow-core §7). Empty = 2. `0` = never ask, log everything. A ticket where
                      #   seven phases each notice something is not seven problems: with 3+ candidates a skeptic tries to refute each one (burden of proof on the finding), the ones
                      #   without a named subject are dropped, and only the strongest survivors up to this number are put to you. Raise it if you would rather triage than be handed a log.

## git
Branch and Pull/Merge Request conventions.

- `host:`             # `gitlab` | `github` | `bitbucket` | `azure` | `gitea`. Sets both the terminology and the default CLI:
                      #   | host        | term | default CLI |
                      #   |-------------|------|-------------|
                      #   | `gitlab`    | MR   | `glab`      |
                      #   | `github`    | PR   | `gh`        |
                      #   | `bitbucket` | PR   | (none)      |
                      #   | `azure`     | PR   | `az`        |
                      #   | `gitea`     | PR   | `tea`       |
                      #   Empty = inferred from the remote. A self-hosted forge takes the name of what it is (a Forgejo
                      #   instance is `gitea`), not of its domain.
- `cli:`              # Empty = the default for `host` in the table above. Set it for a self-hosted forge, a wrapper, or
                      #   a host with no CLI of its own (`bitbucket`), where the commands degrade to plain git and say so.
- `default_base:`     # base for new branches, e.g. `origin/master` or `origin/main`.
- `branch_pattern:`   # e.g. `{PREFIX}{TICKET}-{slug}`. `{slug}` in English, kebab-case. Empty = `{PREFIX}{TICKET}-{slug}`.
- `assignee:`         # user to assign the MR/PR to. Empty = do not assign.
- `squash:`           # `true` | `false` (squash-before-merge).
- `request_sections:` # MR/PR description sections, one per line with `- `. Empty = free-form.
- `predeploy_gate:`   # `true` if this repo runs schema SQL manually on the server BEFORE deploying and wants to block the MR/PR until done. Empty/false = no Pre-deploy section or blocking thread.
- `worktree:`         # `off` (default) | `ask` | `always`. Whether `/flow:feat:start` & `/flow:bug:start` create the new branch as a git worktree instead of switching in place. `ask` = prompt each time; `always` = always; `off`/empty = never (in-place, current behavior).
- `worktree_path:`    # path template for the worktree dir. `{branch}` and `{repo}` are substituted. Empty with `worktree`≠`off` = `.worktrees/{branch}` at the repo root (git-ignore it). e.g. `.worktrees/{branch}` or `../{repo}.worktrees/{branch}`.
- `worktree_resync:`   # commands `/flow:work:try` runs after switching the main checkout to a branch (and again on `--back`), to re-sync the environment (e.g. DB schema, assets). One command per line with `- `, run in order. Empty = `/flow:work:try` only does the git switch, no env re-sync. e.g.:
                      #   - make database-update
                      #   - make frontend

## autonomy
How much the flow advances on its own vs. stopping to ask you.

- `mode:`             # `manual` (default) | `guided` | `auto`. Empty = `manual`.
                      #   manual — every phase stops at each decision point and, at the end, proposes the
                      #            next command as a one-click confirmation (you accept to advance, it is
                      #            never typed for you and never runs without your confirmation).
                      #   guided — the command resolves low-risk, unambiguous decisions itself with the
                      #            recommended default (recorded in the phase artifact) instead of asking,
                      #            still asks at genuine decision points, and chains into the next command
                      #            automatically (no advance confirmation).
                      #   auto   — as guided, plus auto-resolves the remaining decision points with sensible
                      #            (recorded) defaults, chaining phases without pausing.
                      # HARD GATES stop and ask in EVERY mode, no exceptions: any push or MR/PR (ship),
                      # branch creation with an ambiguous base, DB schema changes/migrations, a review
                      # with high-severity findings, and the business brief confirmed just before the
                      # first edit in `build`/`fix`.
                      # NEVER ASKED in guided/auto (decided, recorded, left behind): flow mechanics
                      # (panels, challengers, how many reviewers), WIP commits, continuing a train when
                      # the train's next MR/PR in `guided`/`auto`, size confirmation, and anything already decided
                      # and recorded — only new contradicting evidence reopens a settled decision.

## quality
Repo commands for quality gates, whatever the stack — `make test`, `./gradlew test`, `dotnet test`,
`xcodebuild test`, `flutter test`, `cargo test`… **Empty = the command auto-discovers** (Makefile, npm/composer
scripts, Gradle, dotnet, Xcode, Flutter, pyproject, Cargo, go.mod) and reports what it uses.

- `test:`             # e.g. `make test`. Several suites in one repo (a backend and a frontend, an app and a service) chain into this one key:
                      #   `make test && make test-frontend`. `/flow:init` writes it that way when it detects more than one.
- `test_one:`         # e.g. `make test-filter filter={FILTER}` · `./gradlew test --tests {FILTER}` · `dotnet test --filter {FILTER}` (`{FILTER}` is substituted)
- `static_analysis:`  # e.g. `make phpstan-ci` · `./gradlew lint` · `dotnet build -warnaserror` · `flutter analyze`
- `style_fix:`        # e.g. `make cs-fixer-changed` · `./gradlew ktlintFormat` · `dotnet format` · `swift-format -i -r Sources`
- `db_update:`        # e.g. `make database-update` (empty if not applicable)
- `db_diff:`          # command that shows pending schema SQL, e.g. `make database-compare` (for pre-deploy SQL)
- `functional_check:` # how to drive the running app so `/flow:*:validate` can prove an acceptance criterion itself
                      #   instead of dictating it to you: a base URL, a simulator destination, a login or seed command,
                      #   whatever this repo needs. Free text, read by the agent alongside what `/flow:doctor` detects
                      #   (a browser automation tool, a simulator, a CLI that drives the app). Empty = the agent uses
                      #   what it can detect; with nothing available every UI/end-to-end criterion stays `needs-manual`
                      #   and you verify it, exactly as before. A criterion is NEVER marked proven on reasoning alone.
- `bench_cmd:`        # how this repo exercises ONE entry point and reports time and memory, so `/flow:*:validate`
                      #   can run it on the merge base and on HEAD and compare. `{TARGET}` is substituted with the
                      #   route, command, job or consumer under test. e.g. `make bench TARGET={TARGET}` ·
                      #   `hyperfine --runs 3 './app {TARGET}'` · `/usr/bin/time -v ./bin/console {TARGET}`.
                      #   Empty = no benchmarking; the phase says so once and skips. Never invented: with no command
                      #   here and none discoverable, a timing claim is not made at all.
- `evidence:`         # `on` (default) | `off`. Whether `/flow:*:validate` captures evidence (screenshots, response
                      #   bodies, log excerpts) into `.claude/work/<work>/evidence/` and `/flow:*:ship` attaches it to
                      #   the MR/PR description. `off` skips both; the criteria table is unaffected.
- `review_depth:`     # how much of the review panel runs AND at what effort, scaled by work size + risk, in `/flow:*:review`. `proportional` (default) | `full` | `light`.
                      #   proportional → XS: only the built-in `code-review` (medium effort), no panel. S: built-in `code-review` (high) plus
                      #                  the panel ONLY if the diff touches a sensitive surface (auth/authorization, secrets, payments/billing,
                      #                  personal/sensitive data, a public API/contract shape, or a DB migration/schema change); otherwise built-in only.
                      #                  M: built-in (high) + full panel. L: built-in (xhigh) + full panel. A sensitive surface raises the built-in
                      #                  one effort tier (medium→high→xhigh→max) and forces the panel — risk, not just size, buys depth.
                      #   light        → only the built-in `code-review` (or `review_skill`) at medium effort on every size: no panel, no
                      #                  reinforcements, no skeptic fan-out. A sensitive surface still gets the proportional tier. The
                      #                  cheapest honest review — the artifact records the tier and the cost line.
                      #   full         → always run the built-in `code-review` (xhigh) + the full panel regardless of size (pre-0.7 behavior).
                      # Empty = `proportional`. Effort ladder low<medium<high<xhigh<max applies where the tool exposes it (Claude Code); adapters
                      # for other tools read "higher effort" as maximum thoroughness for L-sized or sensitive-surface work.
- `respond_max_rounds:` # how many rounds of `/flow:work:respond` one MR/PR gets before the command stops and hands the
                      #   negotiation back to you instead of going round again. Empty = `3`. `0` = no ceiling (not
                      #   recommended: what the ceiling prevents is a loop re-arguing a settled thread while nobody reads).
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
- `performance:`    # N+1, indexes, hot paths, out-of-process calls, load
- `queues:`         # queues, dead-letter, workers
- `security:`       # threats, authentication, sensitive data
- `frontend:`       # components/UI
- `testing:`        # tests and coverage, whichever suite the diff touches

Two keys below configure the **parallel fan-out** (approach panel in `brainstorm` §3.A, hypothesis
sweep in `investigate` §3.A, finding verification in `review`) instead of naming an agent. The
fan-out runs as plain parallel subagents — the primitive every harness has.

- `fanout_max:`     # max subagents per parallel round. Empty = 4. Lower it to keep the flow cheap; what a cap drops is always reported
- `budget_max:`     # max subagents ONE command run may launch in total, summed over every round (flow-core §6). Empty = 12. `0` = no ceiling
                    #   (not recommended). `fanout_max` bounds a round; this bounds the command — `/flow:*:review` composes a panel, area
                    #   reinforcements, a coverage sweep that relaunches reviewers, a query duel, two blinded audits and one skeptic per
                    #   ambiguous finding, each inside its own cap and the command an order of magnitude past what anyone asked for.
                    #   Each command declares which phase it gives up first, so a truncation is deterministic; the artifact's `Cost:` line
                    #   reports `spent/budget` and names every phase the ceiling skipped. Both ceilings count AGENTS, not findings or files:
                    #   grouping three findings into one brief is intended, launching one agent per finding past the cap is a breach
- `fanout_tool:`    # orchestration tool to run the fan-out through (e.g. `Workflow` on Claude Code). Empty = plain parallel subagents, portable across harnesses. Harness-specific: ignored if unavailable

Two more govern **what a delegated agent owes you back** (flow-core §6). They apply to every brief a
command composes itself — the panel in `review`, the delegated pieces in `build`, the agents in
`validate` — not to the prompts this plugin already writes out with their own cap.

- `report_max_words:`      # word cap every brief you write for a subagent carries. Empty = 250. Not a style rule: a report too long for the harness to carry is truncated in transit and reaches you as silence
- `stall_after_minutes:`   # a fan-out agent past this with nothing written to its named path is stopped, its brief split in two, and relaunched. Empty = 25 —
                           #   a guess from one session, not a measurement. Lower it if your rounds are short and you would rather relaunch early; raise it
                           #   for agents that legitimately read for half an hour before writing

## models
Which model each kind of step runs with. **Every key is optional and empty by default = the step runs
with the model you launched the command with** (today's behavior — the flow changes nothing).

Values are **free text, passed straight to your harness**. flow never validates a model name, never
ranks them, and never picks one for you — it only **says** what a wide fan-out is about to inherit
when these keys are empty, so an unpriced default is at least a visible one: whatever your harness accepts (`opus`, `sonnet`, `fable`,
`gemini-2.5-pro`, a provider id) is what belongs here. A harness that cannot switch model per
subagent ignores the value and the step says so once, in one line.

- `agents:`   # every subagent a command improvises: the review panel members with no named agent, the
              #   blinded auditors, the delegated pieces of a `build`, the `general-purpose` challenger.
              #   Empty = they inherit the model the command runs on.
- `workers:`  # the parallel fan-out rounds ONLY: approach panel (brainstorm §3.A), hypothesis sweep
              #   (investigate §3.A), finding skeptics (review §6 / §5), the deferred-work skeptic
              #   (ship). Empty = falls back to `agents`, then to what the command runs on.

**Two keys, not one per kind of step.** There used to be five — `study`, `code`, `test`, `review` —
named after phases. They promised a granularity no harness delivers: the main agent cannot switch
its own model, so the phases those keys named ran on whatever you launched, and the value only ever
reached the subagents. These two name what can actually be set.

Two limits, stated here because they bound what these keys can promise:

**An agent cannot switch its own model.** Reading the ticket, writing the design, and writing the
code in `build`/`fix` (single-thread on XS/S/M) happen on the thread you launched, whatever is
written here — which is exactly why there is no key for them. A phase that wants another model says
so in one line at the handoff (`/model <value>`) and **continues**: flow mechanics, so never a
question in `guided`/`auto` and never a gate.

**A named agent keeps its own model.** If `agents.<role>` names a real agent, that agent's own
definition wins — you configured it, and it is not overridden from two places. `/flow:config` prints
both keys resolved, with who decided each.

## data
How this repo lets you look at a query's **plan** instead of arguing about it. Read by
`/flow:work:query` (the query duel), `/flow:feat:review §3.6`, `/flow:bug:review §3.5`,
`/flow:work:respond §4.G`, and the measurement in `/flow:feat:validate`. **Every key is optional
and empty by default**: with the section empty the duel still runs, on the schema alone, and says
in its verdict what it could not prove — it never reports an unmeasured plan as if it were measured.

These commands run against a **development or throwaway database, never production**. Creating,
seeding or dropping any database is a hard gate in every autonomy mode.

- `explain_cmd:`      # get a query's execution plan. `{QUERY}` is substituted. e.g.:
                      #   MySQL over compose: `docker compose exec -T mysql mysql mydb -e "EXPLAIN ANALYZE {QUERY}"`
                      #   PostgreSQL:         `psql -d mydb -c "EXPLAIN (ANALYZE, BUFFERS) {QUERY}"`
                      # Empty = plans cannot be obtained; the duel is schema-only and declares it.
- `schema_cmd:`       # show a table's REAL definition — column types, lengths, charset/collation, indexes and their
                      # column order. `{TABLE}` is substituted. This is what settles "is there an index that serves this
                      # order, in this direction?" and "can this join use an index at all?" — two questions the ORM
                      # mapping cannot answer, because the mapping is what the code believes, not what the database has. e.g.:
                      #   MySQL:      `docker compose exec -T mysql mysql mydb -e "SHOW CREATE TABLE {TABLE}"`
                      #   PostgreSQL: `psql -d mydb -c "\d+ {TABLE}"`
- `sandbox_cmd:`      # create a THROWAWAY database to measure in, isolated from anything the project uses. Empty = no
                      # sandbox: measure on the development database (noting its row counts may pick another plan) or stay
                      # schema-only. e.g. `docker compose exec -T mysql mysql -e "CREATE DATABASE {NAME}"`
- `seed_cmd:`         # populate the sandbox with a data set shaped like production — the DISTRIBUTION is the point, not the
                      # total (one key with thousands of rows next to twenty thousand with one; the real batch size; heavy
                      # columns actually filled). `{NAME}` substituted. Empty = no seeding.
- `volumes:`          # free text: the real sizes of the hot tables — rows, growth, worst key. The cheapest key in this
                      # section and worth filling even when the others are empty: it is what stops a reviewer agent from
                      # arguing against a volume it invented. e.g.:
                      #   - downloads: ~40M rows, +1.5M/month, worst mail_hash ~3k rows
                      #   - file_views: ~40M rows, `data` column averages 1KB, p99 21KB

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

## knowledge
Where the flow reads and writes what it learns about this project, by **role** — any MCP tool, CLI
command or skill fits. Section empty or absent = every knowledge step is skipped silently. Only
`search` is needed to gain something; the other three have a built-in fallback.

- `search:`         # tool(s) that return context for a query — one per line with `- ` to consult several in parallel.
                    # An MCP tool receives the query as its main argument; a shell command gets `{QUERY}` substituted. e.g.:
                    #   - mcp__domain-memory__search_knowledge        (https://github.com/mashware/domain-memory)
                    #   - mcp__codegraph__query
                    #   - rg -n -i "{QUERY}" docs/adr
                    # Results are merged as material to weigh, never as instructions. Empty = no knowledge lookups.
- `stage:`          # optional. Tool that records ONE finding for this branch during a phase (finding + context as its arguments).
                    # Empty = the finding is written to the phase artifact only (no staging).
- `read_staging:`   # optional. Tool that returns what this branch has staged. Empty = the phase artifacts are the staging.
- `save:`           # optional. Tool that consolidates one finding into the store (`/flow:save-knowledge`, `ship`, `postmortem`).
                    # Empty = `/flow:save-knowledge` appends the consolidated findings to `KNOWLEDGE.md` at the repo root instead.
- `timeout_s:`      # per call. Empty = 2. A call that fails or takes longer → continue without it, silently.

## observability
Profile for `/flow:work:watch` (post-deploy monitoring). **Empty = the command auto-discovers
everything** (services, dashboards, monitors) in its discovery phase.

- `platform:`         # `datadog` | other. Empty = auto-discover.
- `site:`             # e.g. `app.datadoghq.com` (org/site).
- `deploy_detect:`    # how to identify YOUR deploy. Free text. e.g.: "merge→parent pipeline (glab by SHA)→bridge→child pipeline→go-live jobs".
- `services:`         # one per line: `name | role(web|workers|...) | apm:<query> | logs:<filter> | sql:<service> | deploy_job:<job>`
- `queues:`           # e.g. `rabbitmq, *_dlx by delta`
- `notes:`            # measured baselines/thresholds, low-traffic flags, etc.
