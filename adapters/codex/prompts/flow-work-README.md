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
- **The stop is also written to disk**: every stop header has a twin in `.claude/work/<work>/panel.json`, a small state file an external reader (a terminal pane, a status bar, a dashboard) can poll to show where a work stands. It exists because the chat is a *stream* and the question the user actually has is a *state*: with three works in flight, "which MR/PR is this one on, is it waiting for me, and what is its link" is not something they should have to scroll for or type at the agent. The panel carries the MR/PR train read from `meta.json.mrs` with the **URLs of the ones still open**, one line of prose on what is running right now, what comes next, an `accent` line when the flow is parked on a decision of theirs, and `warn` lines for blockers — a sibling repo whose `contract_handoff` is `pending`, a red pipeline, a dependency that has not merged. Two properties make it trustworthy rather than decorative. It is **overwritten whole, never patched**, so it can never be half of an old state and half of a new one. And it is written **before** a long stretch rather than after it, with an honest `updated_at`: a file written only on success keeps showing as finished a step that in fact died halfway, whereas a stale timestamp is something the reader can call out. See the `panel.json` schema below.

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

## `panel.json` schema

Sits next to `meta.json` in each work folder. `meta.json` is the *state machine*; `panel.json` is the *view* — what a reader outside the chat needs to answer "where is this one at?" in a glance. It is optional: a work that never writes it still resolves from `meta.json` alone, which is how older works keep displaying.

```json
{
  "updated_at": "2026-08-06T16:45:00+02:00",
  "header": true,
  "lines": [
    {"text": "Expose a thread's tracking state and events", "style": "title"},
    "",
    {"text": "Done   #1 batch read sources         merged", "style": "ok"},
    {"text": "       #2 per-message grouping       in review"},
    {"text": "https://gitlab.com/…/merge_requests/127", "style": "dim", "indent": 7},
    {"text": "Now    #3 channel mapping            building"},
    {"text": "Left   #4 use case · #5 HTTP route · #6 contract", "style": "dim"},
    "",
    "Right now: grouping opens and clicks per message",
    {"text": "Next: review → validate → ship", "style": "dim"},
    "",
    {"text": "Waiting on you: confirm the MR/PR body before I create it", "style": "accent"},
    {"text": "sibling-repo still needs the endpoint contract", "style": "warn"}
  ]
}
```

- **`lines`** — one entry per line. A bare string is a plain line; an object takes `style` and `indent`. An empty string is a blank line. The reader wraps to its width and crops to its height, so these are sentences, not measured columns.
- **`style`** — `normal` · `dim` · `title` · `accent` · `ok` · `warn` · `error`. Semantic names, not colours: the reader owns the palette and stays right if the theme changes.
- **`header`** — `true` (the default) lets the reader draw its own top line with ticket, type, phase and age from `meta.json`. Those four therefore never belong in `lines`. `false` hands full control of every line to the writer.
- **`updated_at`** — local ISO-8601 with offset, taken from the real clock at write time and never carried over from the previous version. It is what lets a reader distinguish a live summary from one whose author died mid-step and flag the difference instead of showing a stale snapshot as current.

**Contents, in this fixed order** so that several works read alike side by side: the work title; the MR/PR train (one line per `meta.json.mrs[]` entry — `#n`, short title, state — with the URL indented under each entry still open, and the block omitted entirely when the work has no `mrs`); `Right now:`; `Next:`; `Waiting on you:` in `accent`, only when the flow is genuinely parked on the user; then `warn` blockers. Around 14 lines is the ceiling.

**Who writes it.** The 18 phase commands, from the shared Reporting preamble — in pre-flight, before every stop, before any long unattended stretch, and at their close. Plus the two `ship` commands the instant an MR/PR URL exists, `plan` when the train is first populated, `resume` (which rebuilds it after a break — the moment it is most likely to be stale), `watch` on every monitoring cycle, and `abandon` with a terminal state before archiving. The read-only commands — `status`, `daily`, `config`, `news` — never write it. `clean` archives the folder with the panel inside it.

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
- `/flow-work-clean [--dry-run]` — the **periodic sweep** of what finished work leaves behind: the worktree it was built in, the local branch, and the `.claude/work/` folder. Those are only cleaned up if you answer yes at the end of `ship`/`abandon`, and in a train that prompt never fires (an intermediate MR/PR does not set `phase: done`), so the residue accumulates. It joins the three inventories, establishes each branch's verdict from **the forge** (two calls, joined locally) with local fallbacks — including a patch-equivalence check for **squash merges**, which `git branch --merged` misses entirely — and acts only on `merged`/`empty`. `unknown` is never a candidate, dirty and unpushed are protected, work folders are **archived, never deleted**, and the remote is never touched. Deletion is the one action that can destroy work existing nowhere else, so **`autonomy.mode` does not authorize it**: `auto` confirms the list like every other mode. `--purge-archive <N>d` is a separate opt-in pass over `_archive/`, restricted to folders already committed to git.
- `/flow-work-resume` — detects the current branch, opens `meta.json`, recaps, and suggests the next step. It also **re-reads the ticket's comment thread** (§2.5) and reports only what is new since `01-context.md` was written — the break is when a sibling repo publishes its contract or the scope gets cut. It appends that to the artifact and never amends the design on its own.
- `/flow-work-watch {TICKET} [30m]` — post-deployment monitoring: observes the observability platform scoped to the change, comparing against a baseline, and alerts on regressions. In Codex, runs ONE cycle and exits; state lives in `monitor.md`. To repeat it, use OS cron + `codex exec "/flow-work-watch {TICKET}"` or the Codex app Automations.
- `/flow-work-abandon` — closes a work item without shipping (discarded feature, false bug, etc.).

## Golden rules

1. **Never skip `review`.** If the previous phase is not in `phases_done`, the command refuses.
2. **If you edit code outside the workflow**, `/flow-work-status` will flag the divergence.
3. **Artifacts are hand-editable**. If you rewrite `03-design.md`, the next step will respect it.
4. **`domain-memory` is optional but recommended** when closing large features or postmortems (requires `domain_memory.enabled: true` in FLOW.md).
