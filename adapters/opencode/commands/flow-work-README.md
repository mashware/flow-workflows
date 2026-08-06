---
description: Guide to the /flow-feat-* and /flow-bug-* flow system
---

# `/flow-feat-*` and `/flow-bug-*` flow system

This system **orchestrates** the sub-agents and skills that already exist in the project (it does not replace them). Its job is to persist context between phases, prevent each step from starting from scratch, and enforce a mandatory code review before closing.

## Per-repo configuration: `FLOW.md`

Place a `FLOW.md` file at the repo root to adapt the plugin to your conventions. Define the ticket tracker, branch and MR/PR conventions, quality commands, coding conventions, the domain-memory MCP, and the observability profile. All commands read this file in their step 0.

You can start from the template at `flow/examples/FLOW.template.md`.

If the file does not exist or a key is empty, each command auto-discovers the value or falls back to the default behavior described in its corresponding section.

## Principles

- **One folder per ticket**: `.claude/work/{TICKET}/` contains `meta.json` and the markdown artifacts.
- **Numbered artifacts**: each phase writes a `NN-phase.md` that the next step reads.
- **`meta.json` is the source of truth** for state (current phase, size, branch). Without it, commands refuse to proceed.
- **Size drives the flow**: in `/flow-feat-start` and `/flow-bug-start` the work is classified XS/S/M/L and skipping phases is suggested for small changes.
- **Branch with explicit base and no upstream pointing to the base**: creating a branch once caused an accidental deployment, so `/flow-feat-start` §5 and `/flow-bug-start` §4 enforce two rules. (1) **Explicit base**: never `git checkout -b` from "wherever I am" — the base is `git.default_base` from FLOW.md (normal case) or a confirmed parent branch (train mode, noted in `meta.json.stacked_on`). If the current branch is not the base, confirm the base before creating. (2) **`--no-track` required**: with `branch.autoSetupMerge=true`, creating from the base without `--no-track` leaves the upstream on the remote base; a push that resolves the upstream ends up on the base and can trigger a deployment. The first push is always `git push -u origin HEAD` (own branch), and `/flow-feat-ship` §4.0 / `/flow-bug-ship` §3.0 block if HEAD is the base branch or the upstream points to it.
- **Small, focused, loosely coupled MR/PRs**: the default goal is to close the feature in the smallest possible MR/PRs, each with a clear purpose, independently mergeable when possible. Coupling between MR/PRs only when unavoidable; when it is, justify it in `04-mr-plan.md` and record the merge order. A huge MR/PR "because it can't be split" signals that `/flow-feat-plan` was not thought through — go back to that phase before continuing.
- **Understand before starting**: if after reading the ticket, `domain-memory`, and the code there are still open questions that affect the design (which cases it covers, what happens with certain roles/plans, what it does if user X, which metric/event counts as "success"), **ask the user** before closing `/flow-feat-start` or `/flow-feat-brainstorm`. Making up answers that the user will have to correct later is worse than asking upfront. Ask all at once, not one by one.
- **Reuse before creating**: in `/flow-feat-design`, before proposing new entities, columns, repositories, services, or events, verify whether something equivalent already exists in the affected module or neighboring modules. Every new piece in `03-design.md` implicitly means "I found nothing that works." If duplicating knowingly, justify it.
- **Solve the project's real problem, not the generic one (fit + YAGNI)**: before adding any defensive mechanism (validation, guard, retry, lock, fallback, cache, idempotency, queue, feature flag), answer **two questions with evidence**:
  - **(a) Does it fit? Can this scenario actually occur given how this project works?** Evidence comes from `domain-memory` and the code, **not** from generic book patterns or "it could happen that…". If the current system already prevents that scenario, the protection **is unnecessary**.
  - **(b) Do we need it now, for what the ticket asks?** If it solves a hypothetical future problem instead of today's, **don't add it** (YAGNI). Future ideas are noted as "idea for a separate ticket", not built.

  The default bias in design is to **remove, not add**.
- **Size is revisable**: the XS/S/M/L classification is made in `/flow-feat-start` or `/flow-bug-start` with partial information. Any later phase that sees a clear mismatch should **propose reclassification to the user** before proceeding, and update `meta.json.size`.
- **If implementation invalidates the design, go back to design**: during `/flow-feat-build` it is normal to discover new things. If the accumulated deviations in `05-implementation.md` are 2+ significant ones, or one that changes a decision in the design's ADR-light, **pause the build and go back to `/flow-feat-design`** to update the document before continuing.
- **Challenge design/investigation before executing**: at the end of `/flow-feat-design` and `/flow-bug-investigate`, launch a *challenger* (a general-purpose sub-agent with a sharp prompt). Its **first and dominant** angle is **"Fit and necessity"** — it looks for what **can be removed**. The other angles (fragile assumptions, simplification, production operation) look for what is missing. The result is noted in the artifact itself under "Challenges". **High-severity** findings without a response block progress; the user decides whether to reopen, cut scope, or accept and document.
- **Business brief before writing code**: just before starting to edit files (in `/flow-feat-build` and `/flow-bug-fix`), write 3-5 bullets **in business language** (not technical) explaining what the user/system will be able to do after this task, and what is **NOT** included. Ask for confirmation before the first commit.
- **MR/PR communicates functionality, not implementation**: the MR/PR title and description (in `/flow-feat-ship` and `/flow-bug-ship`) come from the **Brief** of the corresponding artifact, not from the technical design. Technical details go in a collapsed section at the end.
- **Mandatory MR/PR preview before creating**: in `/flow-feat-ship` and `/flow-bug-ship`, before invoking creation, print the full block to the user and ask for confirmation. **No exceptions, even when the content seems obvious.**
- **Anchoring to design contracts**: (1) `/flow-feat-design` §"External contracts": external surfaces as literal shape. (2) `/flow-feat-build` §2.0bis: copy verbatim before typing. (3) `/flow-feat-review` §5: a deliberately biased sub-agent that only compares shape.
- **Commits follow the autonomy mode**: during `/flow-feat-build` and `/flow-bug-fix`, the step's changes are **always reported before anything is recorded**; the mode decides who says "commit". `manual` — the agent **does not run `git commit` on its own**, you decide per step (commit now, validate locally first, or continue without committing). `guided` — asked once at the first step, then applied for the rest. `auto` — the agent commits each step's WIP and keeps going. The system rule *"never commit unless the user explicitly asks"* is honoured, not bypassed: **setting `autonomy.mode: auto` and typing the command is the explicit authorization**, the same reasoning that makes the commits in `/flow-feat-ship` / `/flow-bug-ship` authorized. It covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode.
- **A named next command is not a handoff**: every phase command ends with an explicit **autonomy handoff** — in `manual` it stops and proposes the next command as a question; in `guided`/`auto` it **chains into it in the same turn**. It is written into each closing section, not only in the shared preamble, because a closing line that merely names the next command is a specific instruction to stop, and the specific instruction wins. Deliberate exceptions: `ship` is never chained into (it pushes and opens the MR/PR — a hard gate in every mode), and neither is anything downstream of a red gate (blockers in review, red tests in validate, unresolved `high` findings in design).
- **Mandatory code review**: `/flow-feat-ship` cannot proceed nor can `/flow-bug-postmortem` be closed without going through the corresponding review command.
- **Existing sub-agents**: the commands invoke the sub-agents and skills available in the project for design, API building, testing, performance analysis, etc. Work is not duplicated — it is delegated to what already exists.
- **Parallel multi-agent fan-out (optional, only where it pays)**: three phases offer launching sub-agents in parallel, **conditional on `size` M/L + user confirmation** — never forced, never on XS/S. (1) `/flow-feat-brainstorm` §3.A: approach panel. (2) `/flow-bug-investigate` §3.A: hypothesis sweep. (3) `/flow-feat-review` §6 and `/flow-bug-review` §5: adversarial verification of findings.
- **`domain-memory` (full cycle)**: if `domain_memory.enabled` is `true` in FLOW.md, the `domain-memory` MCP is used at four moments throughout the flow. If at any point the MCP does not respond within 2 s or fails, continue without context and do not mention it to the user. If `enabled` is `false` or absent, skip all domain-memory steps without notice.
  - **`search_knowledge`** when entering new territory: `/flow-feat-start` and `/flow-bug-start` (ticket keywords), `/flow-feat-brainstorm` (concept/pattern), `/flow-feat-design` (module + integrations), `/flow-bug-diagnose` (affected component), `/flow-bug-investigate` (hypothetical cause).
  - **`stage_finding`** during the process: when closing `/flow-feat-design` and `/flow-bug-investigate`, if non-obvious domain decisions emerged, propose staging them to the user. Silent by default.
  - **`read_staging`** before saving: `/flow-feat-ship` and `/flow-bug-postmortem` read what was accumulated in staging for that branch before proposing the final save.
  - **`save_knowledge`** when closing: `/flow-feat-ship` and `/flow-bug-postmortem` offer to consolidate. Only the "why" is saved (decisions, constraints, motivations); the "what" (code, routes) lives in the repo.
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
  "mrs": [
    {
      "n": 1,
      "title": "…",
      "size": "S",
      "status": "pending" | "in_progress" | "merged" | "closed" | "superseded",
      "phases_done": ["build", "review", "validate"],
      "wave": 1,
      "depends_on": [],
      "lines_est": 120,
      "files_est": 6,
      "url": "https://...",
      "note": "reason if closed/superseded; empty otherwise"
    }
  ],
  "related_repos": [
    { "repo": "sibling-project", "scope": "what's needed there", "status": "pending" | "in_progress" | "done", "contract_handoff": "none" | "pending" | "published → <location>" }
  ],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "free field the user can edit"
}
```

`related_repos` records the **other repos a task touches** (flow is per-repo, so without this the work in a sibling project is forgotten). Captured at `/flow-feat-start` / `/flow-bug-start` §cross-repo, refined at `design`/`plan`, reminded at `ship`, and shown by `daily`/`resume`/`status`. flow only notes and reminds — it never scans or touches the other repo. `[]` for a single-repo task.

`contract_handoff` tracks whether that sibling was told **what shape to build against** — a different question from `status` (whether its work is done). `none` — it consumes no contract declared here. `pending` — it consumes one and the literal has not been handed over. `published → <location>` — the literal contracts were published where that side reads them (normally the tracker ticket; `/flow-feat-ship` §6). It earns its place because `scope` is one line of prose while the contract is a literal shape: a sibling that knows *that* it must expose an endpoint but not the exact payload, error codes or route will invent them, and the invention only surfaces at integration. Picked up by the sibling's own `/flow-feat-start` §3.6.

## `panel.json` schema

Sits next to `meta.json` in each work folder. `meta.json` is the *state machine*; `panel.json` is the *view* — what a reader outside the chat needs to answer "where is this one at?" in a glance. It is optional: a work that never writes it still resolves from `meta.json` alone, which is how older works keep displaying.

```json
{
  "updated_at": "2026-08-06T16:45:00+02:00",
  "phase": "validate",
  "header": true,
  "lines": [
    {"text": "Expose a thread's tracking state and events", "style": "title"},
    "",
    {"ref": "#1", "text": "batch read sources", "mark": "wait", "link": "https://gitlab.com/…/merge_requests/9977"},
    {"ref": "#2", "text": "per-event and per-recipient counters", "mark": "current"},
    {"ref": "#3–#6", "text": "channel map · use case · document detail · route", "mark": "pending"},
    "",
    {"ref": "Now", "text": "unit suite and the test agent over #2", "mark": "info"},
    {"ref": "Next", "text": "ship #2", "mark": "info"},
    {"ref": "Decision", "text": "confirm the MR/PR body before I create it", "mark": "wait"},
    "",
    {"text": "sibling-repo still needs the endpoint contract", "mark": "block"}
  ]
}
```

- **`lines`** — one entry per line. A bare string is a plain line; an object takes `text`, `ref`, `mark`, `link`, `style` and `indent`. An empty string is a blank line — and also an **alignment block separator**: `ref` column widths are computed per block, so the MR/PR train aligns with the train and the labels below align with each other, neither dragging the other wide. The reader wraps to its width and aligns continuations under the text.
- **`mark`** — what the line *is*, leaving the drawing to the reader: `done` · `current` · `pending` · `wait` (shipped or asked, now waiting on someone else) · `block` · `info`. Marked lines form an aligned column of symbol, `ref` and text. Setting `style` too overrides the mark's colour, which is normally wrong — the exception is a line whose colour *is* the information, like a monitoring cycle's verdict.
- **`ref`** — the label in that column. Not necessarily a number: `#1`, `#3–#6`, but equally `Now`, `Next`, `Decision`.
- **`link`** — the URL as a **field, never pasted into `text`**. The reader shortens it to its MR/PR number, makes it clickable, and pins it right or hangs it underneath.
- **`stale_after_minutes`** — raises the staleness threshold above its 30-minute default for a stretch known to run long (a CI poll, a full suite), so a slow step is not reported as a dead agent.
- **`style`** — `normal` · `dim` · `title` · `accent` · `ok` · `warn` · `error`. Semantic names, not colours: the reader owns the palette and stays right if the theme changes.
- **`header`** — `true` (the default) lets the reader draw its own top line with ticket, type, phase and age. Those four therefore never belong in `lines`. `false` hands full control of every line to the writer.
- **`phase`** — the phase being executed **right now**. It exists because `meta.json.phase` only advances when a phase *closes*, so for as long as a phase runs it still names the previous one, and a header drawn from it reads `build` while the body says "validating". The reader prefers this field when present and falls back to `meta.json` when absent.
- **`updated_at`** — local ISO-8601 with offset, taken from the real clock at write time and never carried over from the previous version. It is what lets a reader distinguish a live summary from one whose author died mid-step and flag the difference instead of showing a stale snapshot as current.

**Contents, in this fixed order** so that several works read alike side by side: the work title; the MR/PR train (one entry per `meta.json.mrs[]` — `ref` `#n`, short title, the `mark` for its real state, `link` when it has a URL — with the not-yet-started ones collapsed into one `#a–#z` `pending` line, and the block omitted entirely when the work has no `mrs`); then a block of `Now`, `Next` and, only when the flow is genuinely parked on the user, `Decision` marked `wait`; then the `block` blockers. Around 14 lines is the ceiling.

**No headings over the train.** Grouping the entries under `Done` / `Now` / `Left` is the obvious layout and it is wrong here: in a train an MR/PR that has shipped is *open, waiting to merge*, so `Done  #1 …  MR open` contradicts itself in the one place the user is trusting at a glance. `mark` says it per entry — `wait` for shipped and waiting, `current` for the one being worked, `done` only for merged.

**Who writes it.** The 18 phase commands, from the shared Reporting preamble — in pre-flight, before every stop, before any long unattended stretch, and at their close. Plus the two `ship` commands the instant an MR/PR URL exists, `plan` when the train is first populated, `resume` (which rebuilds it after a break — the moment it is most likely to be stale), `watch` on every monitoring cycle, and `abandon` with a terminal state before archiving. The read-only commands — `status`, `daily`, `config`, `news` — never write it. `clean` archives the folder with the panel inside it.

## Shortcuts by size

| Size | Features                                                                  | Bugs                                                            |
|------|---------------------------------------------------------------------------|-----------------------------------------------------------------|
| XS   | start → build → review → ship                                             | start → fix → review → ship                                     |
| S    | start → design (condensed) → build → review → validate → ship             | start → diagnose → fix → review → validate → ship               |
| M    | start → brainstorm → design → **plan** → build → review → validate → ship | full flow                                                       |
| L    | full flow (includes **plan**)                                             | full flow                                                       |

`/flow-feat-plan` is skipped for XS/S (always 1 MR/PR). For M/L it is required and records the `mrs` array in `meta.json`.

## Full `/flow-feat-*` flow

`/flow-feat-start {TICKET}` → `/flow-feat-brainstorm` → `/flow-feat-design` → `/flow-feat-plan` → `/flow-feat-build` → `/flow-feat-review` → `/flow-feat-validate` → `/flow-feat-ship`

For M/L with multiple MR/PRs, the `build → review → validate → ship` block repeats for each MR/PR in the plan. The `meta.json.mrs` array tracks the state. **Each MR/PR earns its own `build`/`review`/`validate`**, recorded in its `mrs[]` entry's `phases_done` — so `/flow-feat-review`, `/flow-feat-validate` and `/flow-feat-ship` gate on *this* MR/PR's progress, not the work-level `phases_done`. This is deliberate: without it, once the first MR/PR completed review/validate the work-level list would satisfy `ship`'s gate for every later MR/PR, letting a train MR/PR ship unreviewed just because an earlier sibling was reviewed.

## Full `/flow-bug-*` flow

`/flow-bug-start {TICKET}` → `/flow-bug-diagnose` → `/flow-bug-investigate` → `/flow-bug-fix` → `/flow-bug-validate` → `/flow-bug-review` → `/flow-bug-postmortem` → `/flow-bug-ship`

## Cross-cutting commands

- `/flow-work-daily [question]` — your **work assistant**, the Scrum-style daily standup. Read-only, cross-cutting. Combines three sources — **local** (`.claude/work/` + git), **forge** (your open MRs/PRs, reviews awaiting you, red CI, MRs/PRs that cannot merge, unresolved threads via `git.cli`), and **tracker** (tickets assigned to you, priority changes via `tracker.tool`) — and where they cross, suggests concrete commands (ticket without local work → `/flow-feat-start`; red CI or a conflicted branch → `/flow-work-green`; open threads → `/flow-work-respond`). No argument → a *yesterday · today · blockers* briefing; a question → answers just that. Every external source is best-effort (degrades with a one-line note, never blocks); the only write is a "last seen" marker, like `/flow-news`. Complements `status` (technical table) and `resume` (one branch).
- `/flow-work-status` — shows all work items in `.claude/work/`, current phase, and divergence with git.
- `/flow-work-clean [--dry-run]` — the **periodic sweep** of what finished work leaves behind: the worktree it was built in, the local branch, and the `.claude/work/` folder. Those are only cleaned up if you answer yes at the end of `ship`/`abandon`, and in a train that prompt never fires (an intermediate MR/PR does not set `phase: done`), so the residue accumulates. It joins the three inventories, establishes each branch's verdict from **the forge** (two calls, joined locally) with local fallbacks — including a patch-equivalence check for **squash merges**, which `git branch --merged` misses entirely — and acts only on `merged`/`empty`. `unknown` is never a candidate, dirty and unpushed are protected, work folders are **archived, never deleted**, and the remote is never touched. Deletion is the one action that can destroy work existing nowhere else, so **`autonomy.mode` does not authorize it**: `auto` confirms the list like every other mode. `--purge-archive <N>d` is a separate opt-in pass over `_archive/`, restricted to folders already committed to git.
- `/flow-work-resume` — detects the current branch, opens `meta.json`, recaps the state, and suggests the next step. It also **re-reads the ticket's comment thread** (§2.5) and reports only what is new since `01-context.md` was written — the break is when a sibling repo publishes its contract or the scope gets cut. It appends that to the artifact and never amends the design on its own.
- `/flow-work-watch {TICKET} [30m]` — post-deployment monitoring: observes the observability platform (per FLOW.md `observability`) scoped to the change. Runs one cycle, saves the state to `monitor.md`, and stops. For continuous monitoring, set up an OS cron job with `opencode run -p "/flow-work-watch {TICKET}"` every 5 minutes.

## Golden rules

1. **Never skip `review`.** If the previous phase is not in `phases_done`, the command refuses.
2. **If you edit code outside the flow**, `/flow-work-status` warns you of the divergence.
3. **Artifacts are hand-editable**. If you rewrite `03-design.md`, the next step will respect it.
4. **`domain-memory` is optional but recommended** when closing large features or postmortems (requires `domain_memory.enabled: true` in FLOW.md).
