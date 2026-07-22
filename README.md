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
differs per tool (`/flow:feat:start` in Claude Code and Gemini, `/flow-feat-start` in
opencode/Codex).

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
next step, and `/flow:work:resume` picks up the work tied to your current branch. Coming back after
a break? `/flow:work:daily` gives you a Scrum-style standup across everything (local + forge +
tracker). Type `/flow` (or `/`) for autocomplete.

**Autonomy.** By default each phase stops at every decision and, at the end, *proposes* the next
command as a one-click confirmation — you accept to advance, it is never typed for you
(`autonomy.mode: manual` in `FLOW.md`). Set it to `guided` to let a phase resolve low-risk,
unambiguous choices on its own (recording them in the artifact) and chain into the next command
automatically, or `auto` to also auto-resolve the remaining decisions. **Hard gates always stop and ask, in every
mode:** any push or MR/PR, creating a branch on an ambiguous base, DB schema changes/migrations, and
a review with high-severity findings.

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
| `/flow:config` | Show the effective `FLOW.md` config: what is set, what is empty (and its fallback), plus validation |
| `/flow:work:green` | **CI-green loop** (between `ship` and `merge`) — the open MR/PR's pipeline is red; fetch failing jobs, triage, fix at the root, push; never green-washes (see below) |
| `/flow:work:respond` | **Review loop** (between `ship` and `merge`) — triage the open MR/PR threads, debate, implement the agreed changes, reply; never resolves threads (see below) |
| `/flow:work:watch` | **Post-deploy watcher** — monitors observability after a deploy, flags regressions (see below) |
| `/flow:work:daily` | **Work assistant** — a Scrum-style daily standup across all your work (local + forge + tracker); ask it a question or get the full briefing (see below) |
| `/flow:work:status` | Summary of all open work items in `.claude/work/` |
| `/flow:work:resume` | Resume the work tied to the current branch and suggest the next step |
| `/flow:work:try` | Point the main checkout at a branch to test it (then `--back`), re-syncing the env per `git.worktree_resync` |
| `/flow:work:abandon` | Close a work item without shipping (discarded feature, non-bug…) |
| `/flow:save-knowledge` | Consolidate the branch's findings into the `domain-memory` store |

## CI-green loop (`/flow:work:green`)

The window between `ship` and `merge` carries two signals, and each has its own loop. `/flow:work:green`
handles the **machine** one: the open MR/PR's CI pipeline is **red**. It fetches the failing jobs and
their logs (via `gh`/`glab`), **triages** each one (lint/style · test failure · type/build · flaky/infra ·
quality-gate), and fixes it **at the root** — delegating to the flow's sub-agents and reproducing locally
with your `quality.*` commands so it does not burn CI cycles guessing. Pushes and reruns are **hard gates**
you confirm, and it **never green-washes**: no blind reruns, no disabling or skipping a check to force
green (the machine analog of `respond` never resolving a thread — a green must mean the code is actually
correct). Because reviewers often wait for green, this usually runs before `respond`. Repeatable (one run
per red pipeline, logged to `09-ci.md`), for both feat and bug MR/PRs.

## Review loop (`/flow:work:respond`)

`ship` opens the MR/PR, but it is rarely merged untouched — reviewers comment, a discussion starts
on the code, and only after you agree do you know whether to change something, defer it, or hold
your ground. That phase, **between `ship` and `merge`**, is what `/flow:work:respond` runs.

It fetches the open threads (via `gh`/`glab`), **triages** each one (question · nitpick · change
request · design debate · out-of-scope · obsolete), and drafts a response per thread. For the
design debates it argues from the **rationale the flow already recorded** (`03-design.md` ADR-light,
the challenges, `domain-memory`) instead of re-deriving it — that recorded "why" is exactly the
ammunition a good review reply needs. Agreed code changes reuse the `build`/`fix` mechanics (with
the same review gate for non-trivial diffs); replies and pushes are **hard gates** you confirm; and
it **never resolves a thread** — it tells you which are ready and leaves that call to you. It is
repeatable (one run per review round, logged to `08-feedback.md`) and works for both feat and bug
MR/PRs.

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

## Work assistant (`/flow:work:daily`)

Come back the next morning and ask *"what was I working on?"*. `/flow:work:daily` is the Scrum-style
daily standup: it combines **three sources** — your **local** work state (`.claude/work/` + git),
the **forge** (your open MRs/PRs, the ones awaiting your review, red CI, unresolved threads, via
`gh`/`glab`), and the **tracker** (tickets assigned to you, priority changes, via your `tracker.tool`) —
and where those sources *cross* it turns the result into concrete suggested commands: a ticket
assigned to you with no local work → `/flow:feat:start`; a red pipeline → `/flow:work:green`; open
threads → `/flow:work:respond`.

Run it with no arguments for a **three-block briefing** (yesterday · today · blockers) or pass a
**question** (`/flow:work:daily what's left on the payment work?`) to have it answer just that.
Unlike `/flow:work:status` (a technical control table) and `/flow:work:resume` (one branch), it is
cross-cutting and narrative. **Read-only** — its only write is a "last seen" marker (like
`/flow:news`), and every external source is **best-effort**: if a CLI is missing or unauthenticated
it degrades and tells you what it couldn't check, never blocking.

## Cross-repo tasks

flow is per-repo, but tasks often aren't (a backend change plus its consumer, an API plus its
client). `/flow:feat:start` and `/flow:bug:start` ask — only when there's a signal — whether the
task touches other repos and record them in `meta.json.related_repos`; `design`/`plan` refine the
list. When you `ship`, flow reminds you of the part still pending in the sibling repo, and
`/flow:work:daily`, `resume` and `status` keep it visible so the other project doesn't fall off the
map. flow only **notes and reminds** — it never scans or touches the other repo. In ticket-less
mode the affected repos also go into the issue flow drafts, so the scope is recorded in the tracker.

## Configuration: `FLOW.md`

A file at the repo root describes your conventions: issue tracker, git host and CLI, optional
git-worktree mode (`off`/`ask`/`always`) and the `worktree_resync` commands `/flow:work:try` runs,
quality commands (test/lint/static-analysis/DB), role→agent map, code-review panel, per-command
`notes`, whether you use the [`domain-memory`](https://github.com/mashware/domain-memory) MCP, and
the observability profile for the watcher. Run `/flow:config` to see your effective config at a glance. **Anything left empty is auto-detected or asked for** — a
repo with no `FLOW.md` still works, just with more questions. Run `/flow:init` to generate it, or
copy [`plugins/flow/examples/FLOW.template.md`](plugins/flow/examples/FLOW.template.md) by hand.
`FLOW.md` is **personal config, not team config** — it mixes repo facts with your own flow
preferences (autonomy, the tools/agents you have installed, review depth, assignee), so **add it to
your `.gitignore`**; `/flow:init` offers to. It holds no secrets. A team that wants to share the
repo-fact subset can commit it deliberately.

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
