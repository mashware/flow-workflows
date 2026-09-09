# Configuring flow: base plus harness overlay

`FLOW.md` is the shared configuration at your repo root. An optional sparse
`FLOW.<harness>.md` overrides the values that differ between Claude Code, Codex, opencode, and
Gemini CLI. Together they tell the `/flow:*` commands how tickets are read, branches and MR/PRs are
made, tests run, review is staffed, models are selected, and deploys are watched. Every command
resolves the base plus the active overlay in its step 0.

**Anything effectively empty is auto-detected or asked for.** A repo with neither the base nor its
active overlay still works, just with more questions and fewer shortcuts. Nothing here is required.

Four things surround this file, each with one job — if the template and this document ever
disagree, the template wins:

| | Role |
|---|---|
| [`plugins/flow/examples/FLOW.template.md`](../plugins/flow/examples/FLOW.template.md) | The **skeleton to copy**, and the canonical list of keys |
| This document | What each key **means**, its default, and when it's worth setting |
| `/flow:doctor` | Your **effective merged** config — value, source file, empty masks and fallback, validated — then whether the environment it assumes exists here: CLIs and their auth, agents, hooks, MCP, base branch |
| `/flow:init` | **Generates** the base and, when needed, the active harness overlay, auto-detecting what it can |

## Getting the FLOW configuration

```
/flow:init        # auto-detects git host, test commands, tracker… and asks the minimum
```

Or copy the template by hand and delete what does not apply. Most repos need only `FLOW.md`.

### Harness overlays

The supported overlay names are:

| Running product | Active overlay |
|---|---|
| Claude Code | `FLOW.claude.md` |
| Codex | `FLOW.codex.md` |
| opencode | `FLOW.opencode.md` |
| Gemini CLI | `FLOW.gemini.md` |

The product executing the command chooses the overlay; a model name never does. Unknown
`FLOW.*.md` files are ignored. The base is optional too, so an overlay-only configuration is valid.

Resolution is per section and key:

1. A key present in the active overlay wins, even when its value is empty.
2. An explicitly empty overlay value masks the base and selects the documented empty fallback.
3. A key absent from the overlay inherits `FLOW.md`.
4. A list-valued key replaces the complete base list.
5. `conventions` has no keys, so its overlay lines are appended after the base and both apply.

```markdown
# FLOW.md
## quality
- test: make test

## models
- agents: shared-provider-model
- workers: shared-worker-model
```

```markdown
# FLOW.codex.md
## models
- agents: codex-model
- workers:
```

Here the empty `workers` masks `shared-worker-model` and takes its normal fallback, the effective
`agents` value (`codex-model`). Empty both overlay keys to make both inherit the Codex session
model.

The overlay can technically override any documented key, but it should stay sparse. Repo facts
and shared preferences belong in `FLOW.md`; model names, installed agent/skill names,
orchestration tools, and harness-specific MCP tools belong in the overlay.

This is backward-compatible in the upgrade direction: a new flow version reads every existing
`FLOW.md` unchanged, and `/flow:init` never moves values automatically. Older flow versions do not
know the overlay filenames and therefore ignore them; keep all common values in the base if the
same checkout must also run an older installation.

**Then add `/FLOW.md` and `/FLOW.*.md` to your `.gitignore`** — `/flow:init` offers to do it. These
files are **personal config, not team config**: they mix repo facts (tracker, quality commands)
with your own preferences (autonomy mode, the agents and MCPs *you* have installed, review depth,
your assignee name). The same files on a teammate's machine may point at agents that are not there.
They hold no secrets — those stay in your credential store. A team that wants to share only the
repo-fact subset can commit it deliberately.

## Sections at a glance

| Section | What it configures | Empty means |
|---|---|---|
| [`tracker`](#tracker) | How tickets are identified, read, and transitioned | No tracker: work runs ticket-less or you paste the ticket |
| [`git`](#git) | Branches, MR/PRs, worktrees, PR trains, pre-deploy gate | Inferred from the remote; conservative defaults |
| [`autonomy`](#autonomy) | How much a phase decides on its own | `manual` — stops at every decision |
| [`quality`](#quality) | Test/lint/analysis commands and how deep review goes | Auto-discovered; review is `proportional` |
| [`agents`](#agents) | Role → specialist agent map, and how wide the parallel fan-out goes | `general-purpose` with the role in the prompt; fan-out capped at 4 |
| [`models`](#models) | Which model the subagents run with | Everything runs with the model you launched the command with |
| [`data`](#data) | How to read a query's plan and the real size of the hot tables | The query duel runs on the schema alone and says what it could not prove |
| [`conventions`](#conventions) | Rules the code must respect | No specific conventions |
| [`notes`](#notes) | Extra mandatory instructions per command | No extra guidance |
| [`knowledge`](#knowledge) | Where the flow reads and writes what it learns, by role (`search`, `stage`, `read_staging`, `save`) | Knowledge steps are skipped silently |
| [`observability`](#observability) | What `/flow:work:watch` monitors | Auto-discovered at watch time |

---

## Every key at a glance

The authoritative list is the template that ships with the plugin; this table is generated from it.

<!-- config-keys:begin -->
_Generated from [`plugins/flow/examples/FLOW.template.md`](../plugins/flow/examples/FLOW.template.md) by `script/config-keys.py` — edit the template, not this table._

| Section | Key | What it does (first line of the template comment) |
|---|---|---|
| `tracker` | `prefix` | e.g. `PROJ-`. Empty = no prefix / free-form ticket |
| `tracker` | `tool` | `acli` (Jira) \| `gh` (GitHub issues) \| `glab` (GitLab issues) \| `linear` \| `none` (manual). Empty = none |
| `tracker` | `view_cmd` | optional, command to view a ticket. `{TICKET}` is substituted. e.g.: |
| `tracker` | `comments_cmd` | optional, command to read the ticket's COMMENT THREAD. `{TICKET}` substituted. The `view_cmd`s above |
| `tracker` | `assignee` | tracker username/account for the `{ASSIGNEE}` token in the commands below. Empty = fall back to `git.assignee` |
| `tracker` | `start_cmd` | optional, run when a work STARTS (`/flow:feat:start`, `/flow:bug:start`) to move the ticket to "in progress" and/or assign it. `{TICKET}` and `{ASSIGNEE}` substituted; chain two calls with `&&`. Empty = do not transition on start. e.g.: |
| `tracker` | `done_cmd` | optional, run when a work SHIPS and is merged (`phase` reaches `done`) to move the ticket to "done". `{TICKET}` substituted. Empty = do not transition. **Leave empty on GitHub/GitLab** — the `Closes #N` in the MR/PR body already auto-closes the issue on merge. e.g.: |
| `tracker` | `abandon_cmd` | optional, run when a work is ABANDONED (`/flow:work:abandon`) to move the ticket to a cancelled / won't-do state. `{TICKET}` substituted. Empty = do not transition. e.g.: |
| `tracker` | `debt_log` | optional. Versioned Markdown file where `ship` appends the follow-ups that are recorded but never asked about (flow-core §7): `tooling` gaps in the repo's own |
| `tracker` | `followup_ask_max` | how many parked findings one finished work may turn into questions at `ship`'s Close (flow-core §7). Empty = 2. `0` = never ask, log everything. A ticket where |
| `git` | `host` | `gitlab` \| `github` \| `bitbucket` \| `azure` \| `gitea`. Sets both the terminology and the default CLI: |
| `git` | `cli` | Empty = the default for `host` in the table above. Set it for a self-hosted forge, a wrapper, or |
| `git` | `default_base` | base for new branches, e.g. `origin/master` or `origin/main` |
| `git` | `branch_pattern` | e.g. `{PREFIX}{TICKET}-{slug}`. `{slug}` in English, kebab-case. Empty = `{PREFIX}{TICKET}-{slug}` |
| `git` | `assignee` | user to assign the MR/PR to. Empty = do not assign |
| `git` | `squash` | `true` \| `false` (squash-before-merge) |
| `git` | `request_sections` | MR/PR description sections, one per line with `- `. Empty = free-form |
| `git` | `predeploy_gate` | `true` if this repo runs schema SQL manually on the server BEFORE deploying and wants to block the MR/PR until done. Empty/false = no Pre-deploy section or blocking thread |
| `git` | `worktree` | `off` (default) \| `ask` \| `always`. Whether `/flow:feat:start` & `/flow:bug:start` create the new branch as a git worktree instead of switching in place. `ask` = prompt each time; `always` = always; `off`/empty = never (in-place, current behavior) |
| `git` | `worktree_path` | path template for the worktree dir. `{branch}` and `{repo}` are substituted. Empty with `worktree`≠`off` = `.worktrees/{branch}` at the repo root (git-ignore it). e.g. `.worktrees/{branch}` or `../{repo}.worktrees/{branch}` |
| `git` | `worktree_resync` | commands `/flow:work:try` runs after switching the main checkout to a branch (and again on `--back`), to re-sync the environment (e.g. DB schema, assets). One command per line with `- `, run in order. Empty = `/flow:work:try` only does the git switch, no env re-sync. e.g.: |
| `autonomy` | `mode` | `manual` (default) \| `guided` \| `auto`. Empty = `manual` |
| `quality` | `test` | e.g. `make test`. Several suites in one repo (a backend and a frontend, an app and a service) chain into this one key: |
| `quality` | `test_one` | e.g. `make test-filter filter={FILTER}` · `./gradlew test --tests {FILTER}` · `dotnet test --filter {FILTER}` (`{FILTER}` is substituted) |
| `quality` | `static_analysis` | e.g. `make phpstan-ci` · `./gradlew lint` · `dotnet build -warnaserror` · `flutter analyze` |
| `quality` | `style_fix` | e.g. `make cs-fixer-changed` · `./gradlew ktlintFormat` · `dotnet format` · `swift-format -i -r Sources` |
| `quality` | `db_update` | e.g. `make database-update` (empty if not applicable) |
| `quality` | `db_diff` | command that shows pending schema SQL, e.g. `make database-compare` (for pre-deploy SQL) |
| `quality` | `functional_check` | how to drive the running app so `/flow:*:validate` can prove an acceptance criterion itself |
| `quality` | `bench_cmd` | how this repo exercises ONE entry point and reports time and memory, so `/flow:*:validate` |
| `quality` | `evidence` | `on` (default) \| `off`. Whether `/flow:*:validate` captures evidence (screenshots, response |
| `quality` | `review_depth` | how much of the review panel runs AND at what effort, scaled by work size + risk, in `/flow:*:review`. `proportional` (default) \| `full` \| `light` |
| `quality` | `respond_max_rounds` | how many rounds of `/flow:work:respond` one MR/PR gets before the command stops and hands the |
| `quality` | `review_skill` | orchestrating skill for the code-review panel in /flow:*:review. Empty = no skill; see `reviewers` below |
| `quality` | `reviewers` | if `review_skill` is empty: list of agents that run in parallel as a review panel (one per line with `- `). Empty with no skill = only the built-in `code-review` |
| `agents` | `architecture` | design/layers/architecture |
| `agents` | `persistence` | DB/ORM/mappings/migrations/queries |
| `agents` | `api` | endpoints/DTOs/routes/HTTP contracts |
| `agents` | `performance` | N+1, indexes, hot paths, out-of-process calls, load |
| `agents` | `queues` | queues, dead-letter, workers |
| `agents` | `security` | threats, authentication, sensitive data |
| `agents` | `frontend` | components/UI |
| `agents` | `testing` | tests and coverage, whichever suite the diff touches |
| `agents` | `fanout_max` | max subagents per parallel round. Empty = 4. Lower it to keep the flow cheap; what a cap drops is always reported |
| `agents` | `budget_max` | max subagents ONE command run may launch in total, summed over every round (flow-core §6). Empty = 12. `0` = no ceiling |
| `agents` | `fanout_tool` | orchestration tool to run the fan-out through (e.g. `Workflow` on Claude Code). Empty = plain parallel subagents, portable across harnesses. Harness-specific: ignored if unavailable |
| `agents` | `report_max_words` | word cap every brief you write for a subagent carries. Empty = 250. Not a style rule: a report too long for the harness to carry is truncated in transit and reaches you as silence |
| `agents` | `stall_after_minutes` | a fan-out agent past this with nothing written to its named path is stopped, its brief split in two, and relaunched. Empty = 25 — |
| `models` | `agents` | every subagent a command improvises: the review panel members with no named agent, the |
| `models` | `workers` | the parallel fan-out rounds ONLY: approach panel (design §1.5.3), hypothesis sweep |
| `data` | `explain_cmd` | get a query's execution plan. `{QUERY}` is substituted. e.g.: |
| `data` | `schema_cmd` | show a table's REAL definition — column types, lengths, charset/collation, indexes and their |
| `data` | `sandbox_cmd` | create a THROWAWAY database to measure in, isolated from anything the project uses. Empty = no |
| `data` | `seed_cmd` | populate the sandbox with a data set shaped like production — the DISTRIBUTION is the point, not the |
| `data` | `volumes` | free text: the real sizes of the hot tables — rows, growth, worst key. The cheapest key in this |
| `notes` | `all` | applies to every command |
| `knowledge` | `search` | tool(s) that return context for a query — one per line with `- ` to consult several in parallel |
| `knowledge` | `stage` | optional. Tool that records ONE finding for this branch during a phase (finding + context as its arguments) |
| `knowledge` | `read_staging` | optional. Tool that returns what this branch has staged. Empty = the phase artifacts are the staging |
| `knowledge` | `save` | optional. Tool that consolidates one finding into the store (`ship`, `postmortem`, `abandon`, and the |
| `knowledge` | `timeout_s` | per call. Empty = 2. A call that fails or takes longer → continue without it, silently |
| `observability` | `platform` | `datadog` \| other. Empty = auto-discover |
| `observability` | `site` | e.g. `app.datadoghq.com` (org/site) |
| `observability` | `deploy_detect` | how to identify YOUR deploy. Free text. e.g.: "merge→parent pipeline (glab by SHA)→bridge→child pipeline→go-live jobs" |
| `observability` | `services` | one per line: `name \| role(web\|workers\|...) \| apm:<query> \| logs:<filter> \| sql:<service> \| deploy_job:<job>` |
| `observability` | `queues` | e.g. `rabbitmq, *_dlx by delta` |
| `observability` | `notes` | measured baselines/thresholds, low-traffic flags, etc |
<!-- config-keys:end -->

---

## `tracker`

How tickets are identified and read.

| Key | What it does | Empty |
|---|---|---|
| `prefix` | Ticket prefix, e.g. `PROJ-` | No prefix / free-form ticket |
| `tool` | `acli` (Jira) · `gh` · `glab` · `linear` · `none` | `none` |
| `view_cmd` | Command to read a ticket; `{TICKET}` is substituted | Asks you to paste the ticket |
| `comments_cmd` | Command to read the ticket's **comment thread**; `{TICKET}` substituted | Derived from `tool` (`--comments` on `gh`/`glab`); otherwise `start` warns the thread wasn't read |
| `assignee` | Tracker account for the `{ASSIGNEE}` token | Falls back to `git.assignee` |
| `start_cmd` | Run when a work **starts** — move to *in progress*, assign | No transition on start |
| `done_cmd` | Run when a work **ships and merges** (`phase` reaches `done`) | No transition |
| `abandon_cmd` | Run on `/flow:work:abandon` — move to *cancelled / won't do* | No transition |

```
- tool:      acli
- view_cmd:  acli jira workitem view {TICKET}
- start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}
```

### Why `comments_cmd` exists

`gh issue view N`, `glab issue view N` and `acli jira workitem view KEY` all stop at the
description. But the thread is where the ticket is *decided*: a scope cut, a sharpened criterion,
and — on a multi-repo task — the **contract the sibling repo published when it shipped its half**
(`/flow:feat:ship` §6.3 posts it as a comment, not as an edit of the description). A `start` that
reads only the description starts the second repo blind to what the first one already settled.

So `/flow:feat:start` §2.1 and `/flow:bug:start` §1.1 read the thread as part of "read the ticket",
and `/flow:work:resume` §2.5 re-reads it after a break — showing only what is new — because the
other repo may have shipped its half while you were away. When the thread cannot be read, all three
say so in one line instead of assuming there was nothing there.

### Ticket state transitions

The three `*_cmd` keys let flow move the ticket as the work moves, so you don't keep the board in
sync by hand. They are deliberately unambitious:

- **Best-effort and idempotent** — a failure, or a ticket already in that state, warns and
  continues. A tracker hiccup never blocks your work.
- **Gated, because they're outward-facing** — asked before running in `autonomy.mode: manual`,
  run automatically in `guided`/`auto`.
- **Ticket mode only** — skipped for ticket-less / local-only works, which have no tracker id.
- `done_cmd` fires when the work reaches `phase: done`, i.e. **merged** — not when you archive
  the folder.

**On GitHub/GitLab, leave `done_cmd` empty**: the `Closes #N` that `ship` puts in the MR/PR body
already closes the issue on merge, and a second transition is noise.

### Working without a tracker

`tool: none` (or no `tracker` section) is fully supported. Run `/flow:feat:start` with **no
arguments** and it drafts the work from the conversation you just had — title, summary,
acceptance criteria, the decisions you already closed while talking — for you to confirm. The
work is then identified by a slug instead of a ticket id.

---

## `git`

Branch and Pull/Merge Request conventions.

| Key | What it does | Empty |
|---|---|---|
| `host` | `gitlab` · `github` · `bitbucket` · `azure` · `gitea` — sets terminology and default CLI | Inferred from the remote |
| `cli` | The forge's CLI | The default for `host` (below) |
| `default_base` | Base for new branches, e.g. `origin/main` | Asked when ambiguous |
| `branch_pattern` | e.g. `{PREFIX}{TICKET}-{slug}` (slug in English kebab-case) | Sensible default |
| `assignee` | User to assign the MR/PR to | Not assigned |
| `squash` | `true` · `false` (squash before merge) | Forge default |
| `request_sections` | MR/PR description sections, one per line | Free-form body |
| `predeploy_gate` | `true` if schema SQL is run manually before deploying | No pre-deploy gate |
| `worktree` | `off` · `ask` · `always` | `off` — branches switch in place |
| `worktree_path` | Path template; `{branch}`, `{repo}` substituted | `.worktrees/{branch}` |
| `worktree_resync` | Commands `/flow:work:try` runs after switching | Git switch only, no env re-sync |

`host` decides how a request is named in every stop, artifact and MR/PR preview, and which CLI the
commands reach for. There is no key for the term: it follows the host, because a GitLab repo that
calls them PRs and a GitHub repo that calls them MRs are not things that exist.

| `host` | Term | Default `cli` |
|---|---|---|
| `gitlab` | MR | `glab` |
| `github` | PR | `gh` |
| `bitbucket` | PR | none — the forge steps degrade to plain git and say so |
| `azure` | PR | `az` |
| `gitea` | PR | `tea` |

### Multi-MR/PR trains

On M/L work, `/flow:feat:plan` splits the feature into several small MR/PRs and `build → review
→ validate → ship` repeats per MR/PR. Each one is stacked on the previous branch, and
**the train never waits for the previous MR/PR to merge** — waiting is what makes people give up
and open one huge PR instead.

There is no key for this. At the end of `ship`, with MR/PRs still pending, `autonomy.mode` decides:
`manual` asks *"continue with the next MR/PR?"* and creates the next stacked branch on yes;
`guided` and `auto` continue and record it. A run that would rather stop answers *no*, which is the
same answer the retired `train_chain: wait` gave, one decision later and without a key to configure.

### Worktrees and `/flow:work:try`

With `worktree: ask` or `always`, `/flow:feat:start` and `/flow:bug:start` create the new branch
as a **git worktree** instead of switching your checkout, so several works coexist on disk.
Git-ignore whatever `worktree_path` points at.

Worktrees accumulate: one per work, and only removed if you say yes at the end of `ship` or
`abandon`. `/flow:work:clean` is the sweep that clears the ones whose MR/PR already merged —
along with their branches and their `.claude/work/` folders — after showing you the list.

`worktree_resync` is the other half: `/flow:work:try <branch>` points your **main** checkout at
someone's branch to test it against this environment, and `--back` returns. The listed commands
run after each switch so the environment follows the code:

```
- worktree_resync:
  - make database-update
  - make frontend
```

### Pre-deploy SQL gate (`predeploy_gate`)

Set `true` when this repo's schema SQL is applied by hand on the server **before** the deploy.
`/flow:feat:ship` then adds a Pre-deploy section to the MR/PR and a blocking thread, so the MR/PR
cannot be merged until the SQL has been run. `quality.db_diff` is the command that shows the
pending SQL.

---

## `autonomy`

How much the flow advances on its own versus stopping to ask you.

| `mode` | Behavior |
|---|---|
| `manual` *(default)* | Every phase stops at each decision point and, at the end, **proposes** the next command as a one-click confirmation — you accept to advance; it is never typed for you and never runs unconfirmed |
| `guided` | Resolves low-risk, unambiguous decisions itself with the recommended default (recorded in the artifact), still asks at genuine decision points, and chains into the next command automatically |
| `auto` | As `guided`, plus auto-resolves the remaining decision points with sensible recorded defaults, chaining phases without pausing |

**Hard gates stop and ask in every mode, no exceptions:**

- any push, or opening an MR/PR — so `validate` and `bug:review` never chain into `ship`: the
  unattended run deliberately ends there, with `ship` proposed for you to confirm
- creating a branch when the base is ambiguous
- DB schema changes and migrations
- a review that came back with high-severity findings
- the **business brief** before any code is written (`feat:build` §2, `bug:fix` §2) — the last
  point where the scope can be fixed before there is a diff to argue with

**And the symmetric list — never asked in `guided`/`auto`.** A gate that always stops is only half
the contract; without the other half, `auto` degrades into `manual` one reasonable-looking question
at a time. These are decided, recorded and left behind:

- **flow mechanics** — whether to launch a panel, challengers or a skeptic filter, how many
  reviewers, inline vs subagent: a call on cost and latency, which is the agent's to make
- **WIP commits** on the work branch
- **continuing to the next MR/PR of a train** in `guided`/`auto` — and in particular never offering
  to *wait for the merge*, which nothing asks for any more
- **size confirmation** — the estimate is recorded and `design`/`plan` reclassify it later
- **anything already decided and recorded** in the artifacts or `meta.json.notes`. Only new
  evidence contradicting the premise reopens a settled decision, and then the evidence leads

Whatever a phase decided on its own is written into that phase's artifact, so `guided`/`auto`
stay auditable after the fact.

**How a stop reads.** Independent of the mode, every stop opens with a fixed header — ticket, size,
phase, `MR #n of N`, the plan state from `meta.json.mrs`, one line of what just finished and one
line of what is needed from you — and then at most ~10 lines of body. Those lines are short bullets
rather than prose, and they are written in the language of what changed for whoever uses the
software, not of the code that changed: a class name earns a line only when you have to decide about
it, asked something technical, or named it first. The rest goes to the phase artifact. Two things stay out of the chat entirely: the agent narrating its own process or
mistakes, and subagent completion notices, which never get a turn of their own. The fewer stops a
mode produces, the more each one has to carry: in `auto` there are only two per MR/PR (the brief
and `ship`), and everything between them ran while you were looking elsewhere.

**What the mode does to commits.** During `feat:build` and `bug:fix`, the step's changes are always
reported before anything is recorded; the mode decides who says "commit". `manual` — you do, per
step, and nothing is committed without your word. `guided` — asked once at the first step, then
applied for the rest of the build. `auto` — the agent commits each step's WIP and keeps going;
choosing `auto` *is* the commit authorization, and it covers only WIP commits on the work branch,
never a push.

---

## `quality`

Repo commands for the quality gates. **Empty = the command auto-discovers it** (Makefile,
npm/composer scripts…) and reports what it used.

| Key | Example |
|---|---|
| `test` | `make test` |
| `test_one` | `make test-filter filter={FILTER}` (`{FILTER}` substituted) |
| `static_analysis` | `make phpstan-ci` |
| `style_fix` | `make cs-fixer-changed` |
| `db_update` | `make database-update` |
| `db_diff` | `make database-compare` — shows pending schema SQL |

A repo with more than one suite chains them into `test`: `make test && make test-frontend`. `/flow:init`
writes it that way when it detects a backend and a frontend, and there is no second key for the
second suite — one key that runs everything is what `validate`, `review` and `green` all read.

Four more keys configure review rather than commands:

| Key | What it does | Empty |
|---|---|---|
| `review_depth` | `proportional` · `full` · `light` — how much of the panel runs, and at what effort | `proportional` |
| `review_skill` | Orchestrating skill for the review panel | No skill; see `reviewers` |
| `reviewers` | Agents that run in parallel as a panel, one per line | Only the built-in `code-review` |
| `respond_max_rounds` | Rounds `/flow:work:respond` gets on one MR/PR before it stops and hands the negotiation back | `3` (`0` = no ceiling) |

### The round budget (`respond_max_rounds`)

`/flow:work:respond` is a loop: reviewers comment, the flow answers, sometimes it changes code, the
reviewer comes back. Without a ceiling that loop can spend round after round restating a position
nobody has moved on — and because each round is only appended to `08-feedback.md`, you find out by
reading the artifact, which is too late. At the ceiling the command **stops before starting the next
round**, in every autonomy mode, and reports the open threads, what each spent round tried, and the
one sentence the reviewer and the flow do not agree on. Raising it, taking the thread over, or
granting one more round is your call. A round that only rephrases an earlier answer escalates
immediately rather than waiting for the ceiling. The counter lives in `meta.json`
(`respond_rounds`, per MR/PR) so a session resumed days later does not lose count.

### How much review runs (`review_depth`)

`/flow:feat:review` and `/flow:bug:review` are mandatory, but a one-line change does not deserve
the same treatment as a payments refactor. `proportional` scales the panel by **size and risk**:

| Size | `proportional` |
|---|---|
| XS | Built-in `code-review` at medium effort, no panel |
| S | Built-in at high effort; the panel runs **only** if the diff touches a sensitive surface |
| M | Built-in at high effort + full panel |
| L | Built-in at xhigh effort + full panel |

**The size that decides is the diff's, not the feature's.** `meta.json.size` describes the whole
work, and in a multi-MR/PR train every MR/PR inherits it — which is how a 41-line third MR/PR ends
up reviewed as the L its feature is, the largest single source of wasted review in this plugin. The
review measures the diff in front of it (≤ 150 changed lines → XS · 151-600 → S · 601-1500 → M ·
> 1500 → L) and runs on the **lower** of that and the recorded size; a diff pointing higher than the
recorded size gets one line in the artifact saying the work may be misclassified, not a heavier
review. The sensitive-surface bump below applies on top and is never scaled away.

A **sensitive surface** — authentication/authorization, secrets, payments/billing,
personal/sensitive data, a public API or contract shape, a DB migration/schema change — raises
the built-in reviewer one effort tier (medium → high → xhigh → max) *and* forces the full panel.
Risk buys depth, not just size.

`full` always runs the built-in reviewer at xhigh plus the whole panel, whatever the size.

`light` runs **only** the built-in reviewer (or `review_skill`) at medium effort on every size: no
panel, no reinforcements, no skeptic fan-out. A sensitive surface still upgrades the work to the
`proportional` tier. It is the cheapest honest review, for repos where token cost matters more
than coverage — and the review artifact says so.

Whatever the tier, `06-review.md` and the stop header carry one **cost line**: how many subagents
ran (reviewers · reinforcements · skeptics), at which tier and effort. What a review costs is
something you read, not something you discover on the bill.

When the panel runs, it runs **whole**: its members own categories the rest of the flow does not
revisit, so a skipped one leaves that category with no owner. The review artifact records **ran vs
defined** (`N/M`, plus who did not run and why) — a partial panel is visible before the MR/PR opens.

The effort ladder applies where the harness exposes it (Claude Code); the opencode/Gemini/Codex
adapters read "higher effort" as maximum thoroughness for L-sized or sensitive work.

---

## `agents`

Role → agent map for the steps that delegate to a specialist (`design`, `investigate`,
`validate`, `plan`, `build`, `fix`, `watch`, and the area reinforcements in `review`).

`architecture` · `persistence` · `api` · `performance` · `queues` · `security` · `frontend` ·
`testing`

`testing` covers whichever suite the diff touches; `frontend` covers interface code. There is no
separate frontend-test role — three keys for one concern was one more than the review panel could
put to use.

`performance` is not only a database role: it also covers repeated calls that leave the process
(external API, HTTP, cache, filesystem) and what each *failed* iteration sets off downstream.

The agents must already exist and be discoverable on your machine (`~/.claude/agents`,
`.agents/agents` in the repo, or another plugin) — this only states **which** one to invoke, it
never creates one. An empty role falls back to `general-purpose` with the role in the prompt, or
skips the step if it was optional.

Two more keys configure the **parallel fan-out** rather than naming an agent:

| Key | What it does | Empty |
|---|---|---|
| `fanout_max` | Max subagents launched in one parallel round | `4` |
| `budget_max` | Max subagents one command run may launch in total | `12` |
| `fanout_tool` | Orchestration tool to run the fan-out through | Plain parallel subagents |

### How wide the fan-out goes (`fanout_max`)

Three steps widen into parallel subagents — the approach panel in `/flow:feat:design` §1.5.3,
the hypothesis sweep in `/flow:bug:investigate` §3.A, and the finding verification in
`/flow:feat:review` §6 / `/flow:bug:review` §5. `fanout_max` is the ceiling on **one round**, not
on the command: a panel that runs advisors and then a critique round launches up to `fanout_max` in
each.

### What one command may spend (`budget_max`)

A round inside its cap says nothing about what a *command* spends, and the review chain is where
that bites: a panel, then area reinforcements, then a coverage sweep that relaunches reviewers, then
a query duel, two blinded audits and one skeptic per ambiguous finding — every round inside
`fanout_max` and the command an order of magnitude past what anyone asked for. Measured on one real
feature, three reviews of a single MR/PR train came to 97 subagents.

`budget_max` (empty → **12**, `0` → no ceiling) is the ceiling on everything **one command run**
launches, summed over every round including relaunched ones. The mechanics:

- **Counted before the launch, not after.** A round that does not fit whole is truncated and the
  truncation reported (`4/7`); with nothing left, the phase is skipped and named.
- **Each command declares which phase it gives up first**, so a truncation is deterministic rather
  than the model's mood on the day. In `/flow:feat:review` the order is the completeness sweep, then
  the skeptics, then the idiom audit, then the area reinforcements — and the built-in reviewer, the
  panel the tier selected, the query duel and the blinded contract check are never dropped for
  budget.
- **Both ceilings count agents, not findings.** Grouping three findings into one skeptic's brief is
  the intended shape; launching one agent per finding because each looks cheap is a breach — twelve
  `Verify Vn` agents under a cap of four is not thoroughness, it is an unbounded round.
- **The artifact reports `spent/budget`** and lists every phase the ceiling skipped: a phase dropped
  for cost and a phase that found nothing are not the same result.

Lower it before anything else when reviews feel expensive: `8` is a frugal review, `6` a cheap one.
`/flow:init` writes both ceilings into `FLOW.md` with their values even when they are the defaults,
because a ceiling nobody can find is not a ceiling.

Raise it when you want breadth and are paying for it deliberately. Lower it to `1`-`2` on a repo
where you would rather the flow stayed cheap. What the ceiling drops is always **reported** — a
sweep that investigated 4 of 7 hypotheses says so in the artifact, because a silently truncated
fan-out reads as full coverage when it was not.

The verification gate is the one that used to run away: it is deliberately narrow now, and needs
size **M/L**, a diff **over 150 changed lines**, and **≥ 4 ambiguous** findings before it opens at
all. One skeptic per finding, not a voting panel.

**The synthesis is never a subagent.** Ranking approaches, converging on a root cause, judging
findings — that stays with the main agent, which already holds the work's context and writes the
artifact. The fan-out gathers; the main agent decides.

### Running the fan-out through a tool (`fanout_tool`)

Empty means plain parallel subagents: the one primitive every harness has, so the flow behaves the
same on Claude Code, Codex, Gemini and opencode.

Some harnesses also offer heavier orchestration — deterministic phases, typed per-agent schemas,
resumable runs. Claude Code's `Workflow` tool is one. Name it here and the three fan-out steps run
through it instead:

```markdown
## agents
- fanout_tool: Workflow
```

The rounds, the briefs and the `fanout_max` ceiling do not change — only the mechanism. **This is
harness-specific by definition**: a tool named here that the running harness does not have is
ignored, and the step falls back to plain subagents. Leave it empty unless you know you want the
extra machinery and the cost that comes with it.

---

## `models`

Which model the **subagents** run with. The section is **optional in full**: with an empty or absent
`models`, every subagent inherits the model you launched the command with — which is what flow did
before the section existed.

Put model values in the active harness overlay when different products use different model
catalogues. Values left in the base remain the cross-harness default for backward compatibility;
an explicitly empty overlay key masks one and restores inheritance for that harness.

| Key | What it covers |
|---|---|
| `agents` | Every subagent a command improvises: review panel members with no named agent, the blinded auditors, the delegated pieces of a `build`, the `general-purpose` challenger |
| `workers` | The parallel fan-out rounds only — approach panel, hypothesis sweep, finding skeptics, the deferred-work skeptic. Empty → falls back to `agents` |

Nothing else has a key, and that is the point of the pair: the steps the main agent performs itself
cannot be given a model at all (below).

```markdown
## models
- agents: fable
- workers: sonnet
```

**Two keys, not five.** Until v0.50.0 there were `study`, `code`, `test` and `review`, named after
kinds of step. They promised a granularity the harness does not deliver: the phases they named are
run by the main agent, which cannot switch its own model, so the value only ever reached the
subagents those phases launched. A key that resolves to "reported, not applied" for its headline
case is a key that misleads. The two that remain name exactly what can be set.

The values are **free text passed straight to your harness**. flow does not validate a model name,
does not rank models, and never picks one for you — it has no opinion on which model is good at
what, and a plugin that shipped one vendor's tiers as gospel would be wrong on the other harnesses
it also runs on. A harness that cannot set the model per subagent ignores the value and the step
says so once.

`workers` exists because a fan-out round is where cost multiplies: four skeptics or five approach
advisors on one command. Set it below `agents` to make breadth cheap, or leave it empty and the
round follows `agents`.

### The two limits

**An agent cannot switch its own model.** This is the one that decides what the section can promise.
The flow's steps split in two:

- **What flow launches as a subagent** — the review panel, the tests agent, the challengers, the
  contract check, the skeptics: here the configured model is applied when the subagent is launched.
  Nothing is asked of you.
- **What the main agent performs itself** — reading the ticket, weighing the approaches, designing, and
  **writing the code** (`build`/`fix` are single-thread on XS/S/M by design): the model in play is
  the one you launched the command with, and no instruction inside a command can change that.

There is no key for the second half, because a key that cannot be applied is a promise the section
cannot keep. What a phase does instead is say it: when it would read better on another model, the
handoff prints one line with the `/model` command that switches it, records the fact in the phase
artifact, and continues.

It is deliberately **not** a gate. Model choice is flow mechanics — the same category as how many
reviewers run or whether a panel opens — and `guided`/`auto` never ask about mechanics. A stop at
every phase boundary demanding a `/model` would be individually defensible and would collectively
turn an unattended run back into an attended one, which is exactly the degradation the never-ask
list in the phase preamble exists to prevent. The artifact keeps the trace, so a build that ran on
another model than the one configured is something you can see afterwards rather than something you
had to police in advance.

**A named agent keeps its own model.** If `agents.<role>` points at a real agent, that agent's own
definition decides its model: you configured it there deliberately, and one setting must not be
overridden from two places. These keys apply where flow **improvises** the agent — the
`general-purpose` fallback with the role in the prompt — and to the fan-out workers.

`/flow:doctor` prints both keys resolved, with who decided each one (the `models` key, a named
agent's own definition, or inheritance). Which model runs where is something you read, not something
you infer from this page.

---

## `data`

How this repo lets a query be judged on its **execution plan** instead of on an argument about it.
Read by `/flow:work:query` (the query duel), the data-access pass in `/flow:feat:review` §3.6 and
`/flow:bug:review` §3.5, the performance objections in `/flow:work:respond` §4.G, and the
measurement in `/flow:feat:validate`.

**Every key is optional and empty by default.** With the section empty the duel still runs — on the
schema and the code alone — and its verdict states which points it could not settle. That is the
whole contract: the flow never reports an unmeasured plan as if it had been measured.

| Key | What it gives you | Empty |
|---|---|---|
| `explain_cmd` | A query's execution plan (`{QUERY}` substituted) | No plans; schema-only duel |
| `schema_cmd` | A table's real definition — types, lengths, charset/collation, indexes and their column order (`{TABLE}` substituted) | Index and collation questions stay unknown |
| `sandbox_cmd` | Create a throwaway database to measure in (`{NAME}` substituted) | Measure on the dev database, or not at all |
| `seed_cmd` | Populate it with a data set shaped like production (`{NAME}` substituted) | No seeding |
| `volumes` | Free text: real sizes of the hot tables — rows, growth, worst key | Reviewer agents argue against volumes they invented |

```markdown
## data
- explain_cmd: docker compose exec -T mysql mysql mydb -e "EXPLAIN ANALYZE {QUERY}"
- schema_cmd: docker compose exec -T mysql mysql mydb -e "SHOW CREATE TABLE {TABLE}"
- volumes:
  - downloads: ~40M rows, +1.5M/month, worst mail_hash ~3k rows
  - file_views: ~40M rows, `data` averages 1KB, p99 21KB
```

### Why a query needs its own gate

Correctness is visible in the code; cost is not. The cost of a query lives in the plan, and the plan
depends on facts that appear nowhere in the diff: which index exists, in what column order and
**direction**, the type and collation of both sides of a join, how many rows a key really has. So a
panel of reading reviewers approves a query that reads a hundred thousand rows to return fifteen —
and approves it *faster* when the design wrote down a plausible reason for it. Two failure shapes
recur, and neither is catchable by reading:

- **A mixed-direction order** (`a ASC, b DESC`) over a single-direction index does not half-use it:
  it sorts the entire result set.
- **Join keys with different types or collations** cannot use an index at all — the engine converts
  one side, usually the big one. Same rows, same order, same green tests; only the plan collapses.

That is also why `schema_cmd` reads the database and not the ORM mapping: the mapping is what the
code believes, and these two failures live in the gap between that and what the database has.

### `volumes` is the cheapest key here

An adversarial reviewer with no volumes invents them, and an invented volume produces a confident
argument about a scenario that does not exist — in either direction. One line per hot table (rows,
growth, worst key) is what makes the duel argue about this project. Fill it even if you never fill
the commands.

### The gate on measuring

`explain_cmd` and `schema_cmd` are reads: they run when a duel needs them. `sandbox_cmd` and
`seed_cmd` create and populate a database, which is a **hard gate in every autonomy mode** — the
flow shows the exact commands and the target name before running them, never points them at a
database the project uses, and gives you the cleanup command with the result. Point none of these at
production; a plan measured there is not worth what asking for it costs.

And the corollary that matters most: **the functional test database proves nothing about a plan.**
With a handful of fixture rows the optimizer picks whatever is cheapest at that size, which is
usually not what it picks in production. "Not measured" is a legitimate verdict; a plan from the
test database reported as evidence is not.

---

## `conventions`

Free text: the conventions commands must respect when writing and reviewing code — layers,
patterns, prohibitions. Empty = no specific conventions.

**Most lines here arrive by being said, not by being typed.** When you correct a phase mid-work —
*«not a listener, a message handler»*, *«never mock the repository in that layer»*, *«the test
command is `make test-unit`»* — the phase records it as a candidate and `ship` offers it to this
section once, at the end of the work: **Add to FLOW.md** · **Not a rule** · **Later**, or
**Replace** when it contradicts a line already here. Nothing is written without that question, in
any autonomy mode, because it edits a file in your tree. A correction that is about the *current
ticket* rather than about the repo never becomes a candidate — the test is whether the same
sentence would apply to an unrelated ticket here. Mechanics: flow-core §8.

A correction that names a command flow runs (a test runner, a linter, a formatter) is offered as
the `quality` key it belongs to instead, with the value it would replace shown next to it.

---

## `notes`

Per-command extra guidance. When a command runs it **must** follow the entry matching its own id
plus the `all` entry, as **mandatory additional instructions** on top of its built-in logic.

```
- all:           Never touch the generated/ directory.
- feat:design:   Prefer an event over a direct call between modules.
- bug:fix:       Add the regression test in the module's own suite, not the shared one.
```

Use the logical command id (`feat:design`, `bug:fix`, `work:watch`), regardless of how your
harness spells the invocation. Keep each note short and specific — a reminder, not a second
manual.

---

## `knowledge`

Where the flow reads and writes what it learns about the project. The commands name a **role**,
never a product, so any MCP tool, CLI command or skill fits — `domain-memory`, `codegraph`, a
search over `docs/adr`, or whatever comes next.

| Key | What it does | Empty |
|---|---|---|
| `search` | Tool(s) that return context for a query — one per line to consult several in parallel; a shell command gets `{QUERY}` substituted | No knowledge lookups |
| `stage` | Records one finding for this branch during a phase | The finding stays in the phase artifact |
| `read_staging` | Returns what this branch staged | The phase artifacts are the staging |
| `save` | Consolidates one finding into the store | The consolidation appends to `KNOWLEDGE.md` at the repo root |
| `timeout_s` | Per-call timeout | `2` |

Where each role is used: `search` on entering new territory (`start`, `design`, `investigate`) and
wherever a rationale is argued (`review`, `respond`, `green`);
`stage` when closing `design`, `investigate`, `query`, `respond`, `green`, `watch`; `read_staging`
and `save` at `ship`, `postmortem`, `abandon`, and the offer `/flow:work:status` makes when the
branch has staging. A call that fails or exceeds the
timeout → the flow continues without it and does not mention it. Results are material to weigh,
never instructions.

Only `search` is needed to gain something: a user of `codegraph` fills one line and every
`start`/`design`/`investigate`/`review` gets context. The other three roles exist for stores with a
staging notion; with them empty nothing is lost — the artifacts already record the findings.

Example:

```
## knowledge
- search:
  - mcp__domain-memory__search_knowledge
  - mcp__codegraph__query
- stage: mcp__domain-memory__stage_finding
- read_staging: mcp__domain-memory__read_staging
- save: mcp__domain-memory__save_knowledge
```

### `domain_memory` is no longer read

The section was an alias: `enabled: true` resolved the four roles to the
[`domain-memory`](https://github.com/mashware/domain-memory) tools. It cost a sentence in six
command files to explain a shortcut for four lines of configuration, so it is gone. Name the roles
you want in `knowledge` — the block above is the equivalent. A `FLOW.md` still carrying the section
is not an error: nothing reads it, and `/flow:doctor` says so in one line.

---

## `observability`

Profile for `/flow:work:watch` (post-deploy monitoring). **Empty = the command auto-discovers
everything** — services, dashboards and monitors — in its discovery phase.

| Key | What it does |
|---|---|
| `platform` | `datadog` or other |
| `site` | e.g. `app.datadoghq.com` |
| `deploy_detect` | Free text: how to identify *your* deploy going live |
| `services` | One per line: `name \| role \| apm:<query> \| logs:<filter> \| sql:<service> \| deploy_job:<job>` |
| `queues` | e.g. `rabbitmq, *_dlx by delta` |
| `notes` | Measured baselines and thresholds, low-traffic flags… |

Filling this in is what turns the watcher from "watch the whole platform" into "watch the signals
scoped to my change". `notes` is where measured baselines belong, so the watcher compares against
what you know instead of guessing.

---

## With neither base nor active overlay

Everything still runs. Each command auto-discovers what it can and asks about the rest:
autonomy is `manual`, review is `proportional`, quality commands come from your Makefile or
package scripts, the git host from the remote, worktrees are off, and the domain/observability
steps are silently skipped. The FLOW configuration buys you fewer questions and the behaviors you
cannot auto-detect — trains, transitions, per-command notes, your agent panel.
