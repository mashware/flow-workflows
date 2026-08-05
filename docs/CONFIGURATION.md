# Configuring flow: `FLOW.md`

`FLOW.md` is a single markdown file at your repo root that tells the `/flow:*` commands about
your conventions: how tickets are named and read, how branches and MR/PRs are made, which
commands run your tests, how much review a change earns, which agents to delegate to, and what
to watch after a deploy. Every command reads it in its step 0.

**Anything you leave empty is auto-detected or asked for.** A repo with no `FLOW.md` still works,
just with more questions and fewer shortcuts. Nothing here is required.

Four things surround this file, each with one job — if the template and this document ever
disagree, the template wins:

| | Role |
|---|---|
| [`plugins/flow/examples/FLOW.template.md`](../plugins/flow/examples/FLOW.template.md) | The **skeleton to copy**, and the canonical list of keys |
| This document | What each key **means**, its default, and when it's worth setting |
| `/flow:config` | Your **effective** config: what is set, what is empty (and its fallback), plus validation |
| `/flow:init` | **Generates** the file for you, auto-detecting what it can |

## Getting a `FLOW.md`

```
/flow:init        # auto-detects git host, test commands, tracker… and asks the minimum
```

Or copy the template by hand and delete what does not apply.

**Then add `FLOW.md` to your `.gitignore`** — `/flow:init` offers to do it. This file is
**personal config, not team config**: it mixes repo facts (tracker, quality commands) with your
own preferences (autonomy mode, the agents and MCPs *you* have installed, review depth, your
assignee name). The same file on a teammate's machine may point at agents that aren't there. It
holds no secrets — those stay in your credential store. A team that wants to share only the
repo-fact subset can commit it deliberately.

## Sections at a glance

| Section | What it configures | Empty means |
|---|---|---|
| [`tracker`](#tracker) | How tickets are identified, read, and transitioned | No tracker: work runs ticket-less or you paste the ticket |
| [`git`](#git) | Branches, MR/PRs, worktrees, PR trains, pre-deploy gate | Inferred from the remote; conservative defaults |
| [`autonomy`](#autonomy) | How much a phase decides on its own | `manual` — stops at every decision |
| [`quality`](#quality) | Test/lint/analysis commands and how deep review goes | Auto-discovered; review is `proportional` |
| [`agents`](#agents) | Role → specialist agent map | `general-purpose` with the role in the prompt |
| [`conventions`](#conventions) | Rules the code must respect | No specific conventions |
| [`notes`](#notes) | Extra mandatory instructions per command | No extra guidance |
| [`domain_memory`](#domain_memory) | The `domain-memory` MCP | Domain steps are skipped silently |
| [`observability`](#observability) | What `/flow:work:watch` monitors | Auto-discovered at watch time |

---

## `tracker`

How tickets are identified and read.

| Key | What it does | Empty |
|---|---|---|
| `prefix` | Ticket prefix, e.g. `PROJ-` | No prefix / free-form ticket |
| `tool` | `acli` (Jira) · `gh` · `glab` · `linear` · `none` | `none` |
| `view_cmd` | Command to read a ticket; `{TICKET}` is substituted | Asks you to paste the ticket |
| `assignee` | Tracker account for the `{ASSIGNEE}` token | Falls back to `git.assignee` |
| `start_cmd` | Run when a work **starts** — move to *in progress*, assign | No transition on start |
| `done_cmd` | Run when a work **ships and merges** (`phase` reaches `done`) | No transition |
| `abandon_cmd` | Run on `/flow:work:abandon` — move to *cancelled / won't do* | No transition |

```
- tool:      acli
- view_cmd:  acli jira workitem view {TICKET}
- start_cmd: acli jira workitem transition {TICKET} "In Progress" && acli jira workitem assign {TICKET} {ASSIGNEE}
```

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
| `host` | `gitlab` · `github` — sets terminology and default CLI | Inferred from the remote |
| `cli` | `glab` · `gh` | Inferred from `host` |
| `request_term` | `MR` · `PR` — how requests are named in text | Inferred from `host` |
| `default_base` | Base for new branches, e.g. `origin/main` | Asked when ambiguous |
| `branch_pattern` | e.g. `{PREFIX}{TICKET}-{slug}` (slug in English kebab-case) | Sensible default |
| `assignee` | User to assign the MR/PR to | Not assigned |
| `squash` | `true` · `false` (squash before merge) | Forge default |
| `request_sections` | MR/PR description sections, one per line | Free-form body |
| `predeploy_gate` | `true` if schema SQL is run manually before deploying | No pre-deploy gate |
| `train_chain` | `ask` · `always` · `wait` — multi-PR train behavior | Derived from `autonomy.mode` |
| `worktree` | `off` · `ask` · `always` | `off` — branches switch in place |
| `worktree_path` | Path template; `{branch}`, `{repo}` substituted | `.worktrees/{branch}` |
| `worktree_resync` | Commands `/flow:work:try` runs after switching | Git switch only, no env re-sync |

### Multi-PR trains (`train_chain`)

On M/L work, `/flow:feat:plan` splits the feature into several small MR/PRs and `build → review
→ validate → ship` repeats per MR/PR. Each one is stacked on the previous branch, and
**the train never waits for the previous MR/PR to merge** — waiting is what makes people give up
and open one huge PR instead. `train_chain` decides what happens at the end of `ship` when MR/PRs
are still pending:

| Value | At the end of `ship` |
|---|---|
| `ask` | Asks "continue with the next MR/PR?" and, on yes, creates the next stacked branch and chains into `build` |
| `always` | Chains into the next MR/PR's `build` automatically, no prompt (recorded) |
| `wait` | Stops and recommends continuing only once the current MR/PR is merged |

Empty derives it from autonomy: `manual` → `ask`; `guided`/`auto` → `always`.

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
- **continuing to the next MR/PR of a train** when `train_chain` resolves to `always` — and in
  particular never offering to *wait for the merge*, which only `train_chain: wait` asks for
- **size confirmation** — the estimate is recorded and `brainstorm`/`plan` reclassify it later
- **anything already decided and recorded** in the artifacts or `meta.json.notes`. Only new
  evidence contradicting the premise reopens a settled decision, and then the evidence leads

Whatever a phase decided on its own is written into that phase's artifact, so `guided`/`auto`
stay auditable after the fact.

**How a stop reads.** Independent of the mode, every stop opens with a fixed header — ticket, size,
phase, `MR #n of N`, the plan state from `meta.json.mrs`, one line of what just finished and one
line of what is needed from you — and then at most ~10 lines of body. The rest goes to the phase
artifact. Two things stay out of the chat entirely: the agent narrating its own process or
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
| `frontend_test` | `make test-frontend` |

Three more keys configure review rather than commands:

| Key | What it does | Empty |
|---|---|---|
| `review_depth` | `proportional` · `full` — how much of the panel runs, and at what effort | `proportional` |
| `review_skill` | Orchestrating skill for the review panel | No skill; see `reviewers` |
| `reviewers` | Agents that run in parallel as a panel, one per line | Only the built-in `code-review` |

### How much review runs (`review_depth`)

`/flow:feat:review` and `/flow:bug:review` are mandatory, but a one-line change does not deserve
the same treatment as a payments refactor. `proportional` scales the panel by **size and risk**:

| Size | `proportional` |
|---|---|
| XS | Built-in `code-review` at medium effort, no panel |
| S | Built-in at high effort; the panel runs **only** if the diff touches a sensitive surface |
| M | Built-in at high effort + full panel |
| L | Built-in at xhigh effort + full panel |

A **sensitive surface** — authentication/authorization, secrets, payments/billing,
personal/sensitive data, a public API or contract shape, a DB migration/schema change — raises
the built-in reviewer one effort tier (medium → high → xhigh → max) *and* forces the full panel.
Risk buys depth, not just size.

`full` always runs the built-in reviewer at xhigh plus the whole panel, whatever the size.

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
`frontend_test` · `testing`

`performance` is not only a database role: it also covers repeated calls that leave the process
(external API, HTTP, cache, filesystem) and what each *failed* iteration sets off downstream.

The agents must already exist and be discoverable on your machine (`~/.claude/agents`,
`.agents/agents` in the repo, or another plugin) — this only states **which** one to invoke, it
never creates one. An empty role falls back to `general-purpose` with the role in the prompt, or
skips the step if it was optional.

---

## `conventions`

Free text: the conventions commands must respect when writing and reviewing code — layers,
patterns, prohibitions. Empty = no specific conventions.

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

## `domain_memory`

| Key | What it does |
|---|---|
| `enabled` | `true` if the [`domain-memory`](https://github.com/mashware/domain-memory) MCP is installed and running |

With it on, flow searches domain knowledge when entering new territory (`start`, `brainstorm`,
`design`, `diagnose`, `investigate`), stages non-obvious findings when closing `design` and
`investigate`, and offers to consolidate them at `ship`/`postmortem`. Empty or `false` = every
domain step is skipped silently; if the MCP doesn't answer in 2 s, flow continues without it and
doesn't mention it.

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

## With no `FLOW.md` at all

Everything still runs. Each command auto-discovers what it can and asks about the rest:
autonomy is `manual`, review is `proportional`, quality commands come from your Makefile or
package scripts, the git host from the remote, worktrees are off, and the domain/observability
steps are silently skipped. `FLOW.md` buys you fewer questions and the behaviors you can't
auto-detect — trains, transitions, per-command notes, your agent panel.
