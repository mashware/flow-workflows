# flow-workflows

Guided development workflows for terminal coding agents. Instead of one big "do this task" prompt,
work moves through explicit, reviewable phases — `feat` (idea → design → build → review → ship)
and `bug` (diagnose → root cause → fix → validate → ship → postmortem) — plus post-deploy
monitoring and multi-agent code review. Every phase leaves an artifact under
`.claude/work/<TICKET>/`, so the work is resumable and auditable.

**Stack-agnostic**: nothing is hardcoded. Each repo is configured with a `FLOW.md` at its root
(tracker, git host, test commands, review agents, observability…). Anything you leave empty is
auto-detected or asked for.

Ships a plugin for **Claude Code** and adapters for **opencode**, **Gemini CLI** and **Codex CLI**.

## Install (Claude Code)

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Then configure the repo once:
```
/flow:init        # auto-detects git host, test commands, etc. and writes FLOW.md for you
```
Try without installing: `claude --plugin-dir <path>/flow-workflows/plugins/flow`.

For **opencode / Gemini CLI / Codex CLI**, run `adapters/install.sh <tool>` — see
[`adapters/README.md`](adapters/README.md). Same commands and logic; only the invocation syntax
differs per tool (`/flow:feat:start` in Claude Code, `/feat-start` in opencode/Codex,
`/feat:start` in Gemini).

## Starting a workflow

A feature, end to end (run the phases in order; each one gates the next and writes its artifact):

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

You don't have to memorize the order — `/flow:work:status` shows every open work item and its
next step, and `/flow:work:resume` picks up the work tied to your current branch. Type `/flow` (or
`/`) for autocomplete.

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

**Work / utilities**

| Command | What it does |
|---|---|
| `/flow:init` | Wizard that generates this repo's `FLOW.md` (auto-detects, asks the minimum) |
| `/flow:work:watch` | **Post-deploy watcher** — monitors observability after a deploy, flags regressions (see below) |
| `/flow:work:status` | Summary of all open work items in `.claude/work/` |
| `/flow:work:resume` | Resume the work tied to the current branch and suggest the next step |
| `/flow:work:abandon` | Close a work item without shipping (discarded feature, non-bug…) |
| `/flow:save-knowledge` | Consolidate the branch's findings into the `domain-memory` store |

## Post-deploy watcher (`/flow:work:watch`)

After you ship, run `/flow:work:watch PROJ-123 30m` and it babysits the deploy: it waits for the
release to go live, sets a baseline, and then monitors the **signals scoped to your change**
(error logs, APM latency/error-rate, slow SQL, queues/dead-letters, monitors) for a window,
comparing against baseline and alerting the moment something regresses. It runs autopiloted — it
schedules its own cycles and you can walk away; if something goes red it interrupts and points you
at the evidence (and offers `/flow:bug:start`).

Before it starts it shows you a **monitoring plan** (which signals, which queries, which
thresholds) so you can confirm or adjust. What it watches comes from the `observability` profile
in `FLOW.md`; if that's empty it auto-discovers the services, dashboards and monitors. State lives
in `monitor.md`, so on harnesses without in-session scheduling it also works driven by cron.

## Configuration: `FLOW.md`

A file at the repo root describes your conventions: issue tracker, git host and CLI, optional
git-worktree mode (`off`/`ask`/`always`, plus optional project "try this branch" helpers),
quality commands (test/lint/static-analysis/DB), role→agent map, code-review panel, per-command
`notes`, whether you use the [`domain-memory`](https://github.com/mashware/domain-memory) MCP, and
the observability profile for the watcher. **Anything left empty is auto-detected or asked for** — a
repo with no `FLOW.md` still works, just with more questions. Run `/flow:init` to generate it, or
copy [`plugins/flow/examples/FLOW.template.md`](plugins/flow/examples/FLOW.template.md) by hand.

## Structure

```
flow-workflows/
├── .claude-plugin/marketplace.json     # catalog (Claude Code)
├── plugins/flow/                       # Claude Code plugin
│   ├── commands/  (feat/ bug/ work/ + init + save-knowledge)
│   ├── hooks/     (guard against pushing to the main branch)
│   └── examples/FLOW.template.md
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

## Note

The opencode/Gemini/Codex adapters are generated faithfully to each tool's documented format
**but not yet tested inside the tool**. They are a solid first cut; validate them as you use them
and adjust paths if your harness version differs (especially Codex, where the prompts location
changes between versions — see `adapters/codex/README.md`).

## License

MIT.
