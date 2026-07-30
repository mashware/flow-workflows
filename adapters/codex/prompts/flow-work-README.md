# `/flow-work-README`

Shows the guide for the `/flow-feat-*` and `/flow-bug-*` workflow system for this Codex adapter.

---

# `/flow-feat-*` and `/flow-bug-*` workflow system

This system **orchestrates** the subagents and skills that already exist in the project (it doesn't replace them). Its job is to persist context between phases, prevent each step from starting from scratch, and enforce a code-reviewed ending.

## Per-repo configuration: `FLOW.md`

Place a `FLOW.md` file at the repo root to adapt the plugin to your conventions. It defines the ticket tracker, branch and MR/PR conventions, quality commands, code conventions, the domain-memory MCP, and the observability profile. All commands read this file in their step 0.

You can start from the template at `../../plugins/flow/examples/FLOW.template.md`.

If the file doesn't exist or a key is empty, each command auto-discovers the value or uses the default behavior described in its corresponding section.

## Principles

- **One folder per ticket**: `.claude/work/{TICKET}/` contains `meta.json` and the markdown artifacts.
- **Numbered artifacts**: each phase writes a `NN-phase.md` that the next step reads.
- **`meta.json` is the source of truth** for state (current phase, size, branch). Without it, commands refuse to continue.
- **Size drives the flow**: in `/flow-feat-start` and `/flow-bug-start` the work is classified XS/S/M/L and phases are suggested to skip for small changes.
- **Branch with explicit base and no upstream to the base**: creating a branch already caused an accidental deployment, so `/flow-feat-start` §5 and `/flow-bug-start` §3 enforce two rules.
- **MR/PR communicates functionality, not implementation**: the title and description come from the **Brief** of the corresponding artifact, not from the technical design.
- **Mandatory MR/PR preview before creating**: in `/flow-feat-ship` and `/flow-bug-ship`, before invoking creation, the full block is printed to the user and confirmation is requested.
- **Commits follow the autonomy mode**: during `/flow-feat-build` and `/flow-bug-fix`, the step's changes are **always reported before anything is recorded**; the mode decides who says "commit". `manual` — the agent **does not run `git commit` on its own**, you decide per step (commit now, validate locally first, or continue without committing). `guided` — asked once at the first step, then applied for the rest. `auto` — the agent commits each step's WIP and keeps going. The system rule *"never commit unless the user explicitly asks"* is honoured, not bypassed: **setting `autonomy.mode: auto` and typing the command is the explicit authorization**, the same reasoning that makes the commits in `/flow-feat-ship` / `/flow-bug-ship` authorized. It covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode.
- **A named next command is not a handoff**: every phase command ends with an explicit **autonomy handoff** — in `manual` it stops and proposes the next command as a question; in `guided`/`auto` it **chains into it in the same turn**. It is written into each closing section, not only in the shared preamble, because a closing line that merely names the next command is a specific instruction to stop, and the specific instruction wins. Deliberate exceptions: `ship` is never chained into (it pushes and opens the MR/PR — a hard gate in every mode), and neither is anything downstream of a red gate (blockers in review, red tests in validate, unresolved `high` findings in design).
- **Mandatory code review**: `/flow-feat-ship` cannot proceed and `/flow-bug-postmortem` cannot close without passing through `/*-review`.

## `meta.json` schema

```json
{
  "ticket": "{PREFIX}XXXXX",
  "type": "feat" | "bug",
  "title": "Tracker text or short description",
  "branch": "{PREFIX}XXXXX-slug",
  "size": "XS" | "S" | "M" | "L",
  "phase": "context" | "brainstorm" | "design" | "plan" | "build" | "review" | "validate" | "ship" | "diagnose" | "investigate" | "fix" | "postmortem" | "done" | "abandoned",
  "phases_done": ["context", ...],
  "mrs": [...],
  "related_repos": [
    { "repo": "sibling-project", "scope": "what's needed there", "status": "pending" | "in_progress" | "done", "contract_handoff": "none" | "pending" | "published → <location>" }
  ],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "free field"
}
```

`related_repos` records the **other repos a task touches** (flow is per-repo, so without this the work in a sibling project is forgotten). Captured at `/flow-feat-start` / `/flow-bug-start` §cross-repo, refined at `design`/`plan`, reminded at `ship`, and shown by `daily`/`resume`/`status`. flow only notes and reminds — it never scans or touches the other repo. `[]` for a single-repo task.

`contract_handoff` tracks whether that sibling was told **what shape to build against** — a different question from `status` (whether its work is done). `none` — it consumes no contract declared here. `pending` — it consumes one and the literal hasn't been handed over. `published → <location>` — the literal contracts were published where that side reads them (normally the tracker ticket; `/flow-feat-ship` §6). It earns its place because `scope` is one line of prose while the contract is a literal shape: a sibling that knows *that* it must expose an endpoint but not the exact payload, error codes or route will invent them, and the invention only surfaces at integration. Picked up by the sibling's own `/flow-feat-start` §3.6.

Each `mrs[]` entry carries its own `phases_done` (e.g. `["build", "review", "validate"]`). **In a multi-MR/PR work each MR/PR earns its own `build`/`review`/`validate`**, recorded in that entry — so `/flow-feat-review`, `/flow-feat-validate` and `/flow-feat-ship` gate on *this* MR/PR's progress, not the work-level `phases_done`. This is deliberate: without it, once the first MR/PR completed review/validate the work-level list would satisfy `ship`'s gate for every later MR/PR, letting a train MR/PR ship unreviewed just because an earlier sibling was reviewed.

## Shortcuts by size

| Size | Features                                                          | Bugs                                               |
|------|-------------------------------------------------------------------|----------------------------------------------------|
| XS   | start → build → review → ship                                     | start → fix → review → ship                        |
| S    | start → design (short) → build → review → validate → ship         | start → diagnose → fix → review → validate → ship  |
| M    | start → brainstorm → design → **plan** → build → review → validate → ship | full flow                               |
| L    | full flow (includes **plan**)                                     | full flow                                          |

## Full `/flow-feat-*` flow

`/flow-feat-start {TICKET}` → `/flow-feat-brainstorm` → `/flow-feat-design` → `/flow-feat-plan` → `/flow-feat-build` → `/flow-feat-review` → `/flow-feat-validate` → `/flow-feat-ship`

## Full `/flow-bug-*` flow

`/flow-bug-start {TICKET}` → `/flow-bug-diagnose` → `/flow-bug-investigate` → `/flow-bug-fix` → `/flow-bug-validate` → `/flow-bug-review` → `/flow-bug-postmortem` → `/flow-bug-ship`

## Cross-cutting commands

- `/flow-work-daily [question]` — your **work assistant**, the Scrum-style daily standup. Read-only, cross-cutting. Combines three sources — **local** (`.claude/work/` + git), **forge** (your open MRs/PRs, reviews awaiting you, red CI, MRs/PRs that cannot merge, unresolved threads via `git.cli`), and **tracker** (tickets assigned to you, priority changes via `tracker.tool`) — and where they cross, suggests concrete commands (ticket without local work → `/flow-feat-start`; red CI or a conflicted branch → `/flow-work-green`; open threads → `/flow-work-respond`). No argument → a *yesterday · today · blockers* briefing; a question → answers just that. Every external source is best-effort (degrades with a one-line note, never blocks); the only write is a "last seen" marker, like `/flow-news`. Complements `status` (technical table) and `resume` (one branch).
- `/flow-work-status` — shows all work items in `.claude/work/`, current phase and divergence with git.
- `/flow-work-resume` — detects the current branch, opens `meta.json`, recaps, and suggests the next step.
- `/flow-work-watch {TICKET} [30m]` — post-deployment monitoring: observes the observability platform scoped to the change, comparing against a baseline, and alerts on regressions. In Codex, runs ONE cycle and exits; state lives in `monitor.md`. To repeat it, use OS cron + `codex exec "/flow-work-watch {TICKET}"` or the Codex app Automations.
- `/flow-work-abandon` — closes a work item without shipping (discarded feature, false bug, etc.).

## Golden rules

1. **Never skip `review`.** If the previous phase is not in `phases_done`, the command refuses.
2. **If you edit code outside the workflow**, `/flow-work-status` will flag the divergence.
3. **Artifacts are hand-editable**. If you rewrite `03-design.md`, the next step will respect it.
4. **`domain-memory` is optional but recommended** when closing large features or postmortems (requires `domain_memory.enabled: true` in FLOW.md).
