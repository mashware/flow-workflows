# flow-workflows

Guided development workflows for terminal coding agents. Instead of one big "do this task" prompt,
work moves through explicit, reviewable phases — `feat` (idea → design → build → review → ship)
and `bug` (diagnose → root cause → fix → validate → ship → postmortem) — plus post-deploy
monitoring and multi-agent code review. Every phase leaves an artifact on disk, so the work is
resumable, auditable, and hand-editable.

**As hands-off as you want it.** `autonomy.mode` is a dial. On `manual` every phase stops at each
decision and waits for you. On `auto` the flow runs itself — ticket, design, implementation,
review, validation, one phase chaining into the next without you typing a command — resolving the
small decisions with sensible defaults and **writing down every one it took**, so you can audit
afterwards what it chose and why. `guided` sits in between: it decides the low-risk calls, still
asks at the real ones.

What makes that safe is that the autonomy dial never moves the **hard gates**. In *every* mode,
including `auto`, flow stops and asks before: any push or MR/PR, creating a branch on an ambiguous
base, a DB schema change or migration, and shipping a review that came back with high-severity
findings. In `manual`, commits during `build` are yours to authorize too — it leaves the work in your
tree so you can read the diff first. It goes alone; it doesn't go behind your back.

The dial cuts both ways, and that half matters just as much: `guided`/`auto` **never** ask about the
flow's own machinery — whether to launch a review panel, how many reviewers, WIP commits, continuing
to the next MR/PR of a train, or anything already decided and written down. Otherwise `auto` decays
into `manual` one reasonable-looking question at a time. And because those modes stop rarely, **every
stop opens with where you are** — ticket, phase, `MR #3 of 7`, what each MR/PR is waiting on, what
just finished, and the one thing it needs from you — before any prose. You are coming back to a pane
you left; the flow has read everything and you have read none of it.

**Stack-agnostic**: nothing is hardcoded. Each repo is configured with a `FLOW.md` at its root
(tracker, git host, test commands, review agents, observability…). Anything you leave empty is
auto-detected or asked for.

Ships a plugin for **Claude Code** and adapters for **opencode**, **Gemini CLI** and **Codex CLI**.

## Install

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Then configure the repo once:
```
/flow:init        # auto-detects git host, test commands, etc. and writes FLOW.md for you
```
Try without installing: `claude --plugin-dir <path>/flow-workflows/plugins/flow`.

**Other harnesses.** Run `adapters/install.sh <tool>` for opencode / Gemini CLI / Codex CLI — see
[`adapters/README.md`](adapters/README.md). Same commands and logic; only the invocation syntax
differs (`/flow:feat:start` in Claude Code and Gemini, `/flow-feat-start` in opencode/Codex).
⚠️ The adapters are generated faithfully to each tool's documented format **but not yet tested
inside the tool** — a solid first cut; validate as you use them and adjust paths if your harness
version differs (especially Codex, where the prompts location moves between versions).

## The two flows

A feature, end to end. Each phase gates the next and writes its artifact:

```
/flow:feat:start  PROJ-123     # read the ticket, size it, create the branch
/flow:feat:brainstorm          # options, angles, risks (optional, larger features)
/flow:feat:design              # architecture, DB, APIs, risks  → 03-design.md
/flow:feat:plan                # split into small mergeable MRs/PRs (optional)
/flow:feat:build               # implement following the design, keep a log
/flow:feat:review              # mandatory multi-agent code review
/flow:feat:validate            # tests, edge cases, integrity
/flow:feat:ship                # commit, push, MR/PR (+ pre-deploy SQL gate if DB changed)
```

A bug:

```
/flow:bug:start  PROJ-456
/flow:bug:diagnose             # reproduce, pin down what's broken
/flow:bug:investigate          # find the root cause, not the symptom
/flow:bug:fix                  # minimal fix
/flow:bug:validate             # regression test that fails before, passes after
/flow:bug:review
/flow:bug:ship
/flow:bug:postmortem           # lessons + areas to watch (larger incidents)
```

**No ticket?** Run `/flow:feat:start` with no arguments and it drafts the work from the
conversation you just had — title, summary, criteria, the decisions you already closed while
talking — for you to confirm. No tracker required.

**You don't have to memorize the order.** `/flow:work:status` shows every open work item and its
next step, `/flow:work:resume` picks up the work tied to your current branch, and
`/flow:work:daily` gives you a standup across everything. The size classified at `start` (XS/S/M/L)
also prunes phases: an XS change goes `start → build → review → ship`. Type `/flow` (or `/`) for
autocomplete.

**How much of it you drive** is one line in `FLOW.md` — `autonomy.mode`, changeable at any time:

| Mode | Decisions | Advancing to the next phase |
|---|---|---|
| `manual` *(default)* | Stops at every one | **Proposes** the next command as a one-click confirmation — never typed for you, never run unconfirmed |
| `guided` | Resolves the low-risk, unambiguous ones itself and records them; still asks at the real ones | Chains automatically |
| `auto` | Also resolves the rest, with recorded defaults | Chains automatically, without pausing |

The hard gates listed above hold in all three. → [Autonomy reference](docs/CONFIGURATION.md#autonomy)

## Commands

**Feature flow**

| Command | What it does |
|---|---|
| `/flow:feat:start` | Start a new feature: read the tracker, classify size, create the branch and initial artifact |
| `/flow:feat:brainstorm` | Generate options, angles and risks before designing |
| `/flow:feat:design` | Design the technical solution (architecture, DB, APIs, risks) before touching code |
| `/flow:feat:plan` | Split the work into small, independently mergeable MRs/PRs |
| `/flow:feat:build` | Implement following the approved design, keeping a running log |
| `/flow:feat:review` | Mandatory multi-agent code review before shipping |
| `/flow:feat:validate` | Validate tests, edge cases and integrity |
| `/flow:feat:ship` | Commit, push, open the MR/PR, offer to save domain knowledge |

**Bug flow**

| Command | What it does |
|---|---|
| `/flow:bug:start` | Start the incident flow (tracker, size, branch, initial artifact) |
| `/flow:bug:diagnose` | Reproduce the failure and pin down exactly what is broken |
| `/flow:bug:investigate` | Find the root cause, not the symptom |
| `/flow:bug:fix` | Implement the minimal fix and keep a log |
| `/flow:bug:validate` | Regression test + verification that the failure does not return |
| `/flow:bug:review` | Multi-agent code review of the fix |
| `/flow:bug:ship` | Commit, push, MR/PR for the fix |
| `/flow:bug:postmortem` | Lessons learned, areas to monitor, offer to save to domain-memory |

**Work / utilities** — cross-cutting, for both `feat` and `bug`

| Command | What it does |
|---|---|
| `/flow:init` | Wizard that generates this repo's `FLOW.md` (auto-detects, asks the minimum) |
| `/flow:config` | Show the effective `FLOW.md` config: what is set, what is empty (and its fallback), plus validation |
| `/flow:work:green` | **Mergeable loop** — the open MR/PR cannot merge (red pipeline, conflicts, behind base): triage, fix at the root, push. Never green-washes → [docs](docs/WORKFLOWS.md#mergeable-loop--flowworkgreen) |
| `/flow:work:respond` | **Review loop** — triage the MR/PR threads, debate, implement what you agreed, reply. Never resolves threads → [docs](docs/WORKFLOWS.md#review-loop--flowworkrespond) |
| `/flow:work:watch` | **Post-deploy watcher** — monitors observability after a deploy, flags regressions, autopiloted → [docs](docs/WORKFLOWS.md#post-deploy-watcher--flowworkwatch) |
| `/flow:work:daily` | **Work assistant** — Scrum-style standup across local + forge + tracker; ask a question or get the briefing → [docs](docs/WORKFLOWS.md#work-assistant--flowworkdaily) |
| `/flow:work:status` | Summary of all open work items in `.claude/work/` |
| `/flow:work:resume` | Resume the work tied to the current branch and suggest the next step |
| `/flow:work:try` | Point the main checkout at a branch to test it (then `--back`), re-syncing the env per `git.worktree_resync` |
| `/flow:work:clean` | **Housekeeping** — sweep what finished work left behind: merged worktrees, dead branches, unarchived folders. Never deletes on a guess → [docs](docs/WORKFLOWS.md#housekeeping--flowworkclean) |
| `/flow:work:abandon` | Close a work item without shipping (discarded feature, non-bug…) |
| `/flow:save-knowledge` | Consolidate the branch's findings into the `domain-memory` store |
| `/flow:news` | What changed in the plugin since the version you last saw |

## What a work looks like on disk

One folder per work under `.claude/work/`, named `<TICKET>-<slug>` (or just `<slug>` for
ticket-less work) so concurrent works are told apart at a glance:

```
.claude/work/PROJ-123-billing-retry-window/
├── meta.json              # source of truth: phase, size, branch, MR/PRs, related repos
├── panel.json             # live state for an external reader (see below)
├── 01-context.md          # start:      ticket, size, branch, first questions
├── 02-brainstorm.md       # brainstorm: options, angles, risks
├── 03-design.md           # design:     architecture + ADR-light + external contracts
├── 04-mr-plan.md          # plan:       the MR/PR split, order and dependencies
├── 05-implementation.md   # build:      running log, deviations from the design
├── 06-review.md           # review:     findings and what was done about them
├── 07-validation.md       # validate:   tests, edge cases, integrity
├── 08-feedback.md         # respond:    one entry per review round
└── 09-ci.md               # green:      one entry per round of merge blockers
```

A bug writes `02-diagnose.md`, `03-investigation.md`, `04-fix.md`, `05-validation.md`,
`06-review.md` and, for larger incidents, `99-postmortem.md`. `/flow:work:abandon` writes
`99-abandoned.md` and moves the folder to `.claude/work/_archive/`.

Each phase reads the previous artifacts instead of starting from scratch — that's the whole point.
They are **hand-editable**: rewrite `03-design.md` and the next phase respects it. `meta.json` is
the state, and without it commands refuse to continue rather than guess.

### `panel.json` — the work, readable from outside the chat

Every stop the flow makes in the chat is also written to `panel.json`, so a reader that is not the
chat — a terminal pane, a status bar, a dashboard — can show where a work stands. The chat is a
stream; the question you actually have is a state, and with three works in flight *"which MR/PR is
this one on, is it waiting for me, and what's its link"* shouldn't need scrolling or asking:

```
PROJ-123 feat·M ⏵ build                              15h ago   ← drawn from meta.json
Billing retry window

Done   #1 batch read sources         merged
       #2 per-message grouping       in review
         https://gitlab.com/…/merge_requests/127
Now    #3 channel mapping            building
Left   #4 use case · #5 HTTP route · #6 contract

Right now: grouping opens and clicks per message
Next: review → validate → ship

Waiting on you: confirm the MR/PR body before I create it
sibling-repo still needs the endpoint contract
```

The file is a list of lines with **semantic** styles (`title` `dim` `accent` `ok` `warn` `error`),
never colours — the reader owns the palette. Two properties make it trustworthy: it is overwritten
**whole**, so it is never half of an old state and half of a new one; and it is written **before** a
long stretch rather than after it, with an honest `updated_at` — a file written only on success
keeps showing as finished a step that in fact died halfway, whereas a stale timestamp is something
the reader can flag. Writing it is optional: a work without one still resolves from `meta.json`.
Full schema in [`commands/work/README.md`](plugins/flow/commands/work/README.md#paneljson-schema).

## Configuration: `FLOW.md`

A single file at the repo root describes your conventions. **Anything left empty is auto-detected
or asked for** — a repo with no `FLOW.md` still works, just with more questions.

| Section | What it configures |
|---|---|
| `tracker` | Ticket prefix, CLI, view and comment-thread commands, and optional state transitions (in-progress / done / won't-do) |
| `git` | Host and CLI, base branch, branch pattern, MR/PR sections, squash, worktrees, multi-PR trains, pre-deploy SQL gate |
| `autonomy` | How much a phase decides on its own: `manual` · `guided` · `auto` (hard gates always ask) |
| `quality` | Test / lint / static-analysis / DB commands, plus how deep review goes (`review_depth`) and your review panel |
| `agents` | Role → specialist agent map (architecture, persistence, api, security, frontend, testing…) |
| `conventions` | Rules the code must respect (layers, patterns, prohibitions) |
| `notes` | Extra mandatory instructions injected per command |
| `domain_memory` | Whether the [`domain-memory`](https://github.com/mashware/domain-memory) MCP is available |
| `observability` | The profile `/flow:work:watch` monitors after a deploy |

**→ [Full configuration reference](docs/CONFIGURATION.md)** — every key, its default, and the
behaviors worth knowing about (review depth scaling, PR trains, worktrees, tracker transitions).

Run `/flow:init` to generate the file, `/flow:config` to see your effective config, or copy
[`plugins/flow/examples/FLOW.template.md`](plugins/flow/examples/FLOW.template.md) by hand.

`FLOW.md` is **personal config, not team config** — it mixes repo facts with your own preferences
(autonomy, the tools/agents you have installed, review depth, assignee), so **add it to your
`.gitignore`**; `/flow:init` offers to. It holds no secrets. A team that wants to share the
repo-fact subset can commit it deliberately.

## Documentation

| | |
|---|---|
| [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) | Complete `FLOW.md` reference |
| [`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) | The cross-cutting workflows: `green`, `respond`, `watch`, `daily`, cross-repo tasks |
| [`plugins/flow/commands/work/README.md`](plugins/flow/commands/work/README.md) | The plugin's internal guide: principles, `meta.json` schema, size shortcuts, golden rules (`/flow:work:README`) |
| [`plugins/flow/CHANGELOG.md`](plugins/flow/CHANGELOG.md) | What changed, version by version (`/flow:news` shows you just the new part) |
| [`adapters/README.md`](adapters/README.md) | Installing on opencode / Gemini CLI / Codex CLI |

## Structure

```
flow-workflows/
├── .claude-plugin/marketplace.json     # catalog (Claude Code)
├── plugins/flow/                       # Claude Code plugin
│   ├── commands/  (feat/ bug/ work/ + init + config + news + save-knowledge)
│   ├── hooks/     (guard against pushing to the main branch)
│   └── examples/FLOW.template.md
├── docs/                               # configuration and workflow reference
└── adapters/
    ├── install.sh
    ├── opencode/  ·  gemini/  ·  codex/
```

## What it does not ship (on purpose)

To stay agnostic, `flow` **does not bundle concrete agents or a review skill** (those are
language/project specific): you name them in your `FLOW.md` and they must exist on your machine.
It does ship the anti-push-to-`master`/`main` hook, which is generic git. Optional dependencies
that improve the flow when present: the `domain-memory` MCP, your git host CLI, and an issue
tracker CLI. Without them, those specific steps degrade; the rest works.

## License

MIT.
