---
name: flow-core
description: Shared rules every /flow command relies on — reading FLOW.md, model keys, autonomy modes and hard gates, how a stop reads, the live panel.json and the 00-summary.md handoff. Load once per session before running any /flow command.
---

# flow-core — the rules shared by every `/flow` command

Every `/flow:*` command assumes these rules. They are stated once, here, so a command file only
carries what is specific to its phase. Read this once per session; a command that says "load
`flow-core`" means this file.

## 0. `FLOW.md` — the repo's configuration

- Read `FLOW.md` at the repo root (tracker, git, autonomy, quality, agents, models, data,
  conventions, notes, domain_memory, observability). Missing file or empty key → the default or
  the auto-discovery each step names. Never stop because a key is empty.
- `domain_memory.enabled: true` → use the `domain-memory` MCP where a step says so. If it fails or
  takes longer than 2 s, continue without it, silently.
- `notes.<command>` (or `notes.all`) → mandatory extra instructions for that command.
- Key names and defaults: the template shipped with the plugin (`examples/FLOW.template.md`).

## 1. Models — which model runs a step

Each command names its `models` key (`study` · `code` · `test` · `review`; fan-out rounds use
`models.workers`, falling back to the command's key). Empty key or no section → run with the model
you were launched with and say nothing.

When set:
- Pass it to every subagent this command launches, **except** an agent named in `agents.<role>`,
  which keeps the model its own definition sets.
- You cannot switch your own model. If the configured value differs from the one you run on, say
  it in one line at the handoff (`this step is configured for <value>, you are on <current>` →
  `/model <value>`), record it in the phase artifact, and continue. Never a question, never a gate.
- A harness that cannot set a model per subagent: note it once, continue with the inherited one.

## 2. Autonomy — `autonomy.mode`

`manual` (default) · `guided` · `auto`. Read it once and apply it throughout the command.

| Mode | Decisions | End of the command |
|---|---|---|
| `manual` | Stop at every decision point | Propose the next command with one `AskUserQuestion` (recommended step as default). Invoke it only on confirmation. Never make the user type it. |
| `guided` | Resolve low-risk, unambiguous ones with the recommended default and **record** the choice in the phase artifact. Ask at genuine decision points. | Chain into the recommended next command automatically. |
| `auto` | As `guided`, plus resolve the remaining decision points with sensible, recorded defaults. | Chain without pausing. |

**Hard gates — stop and ask in every mode, no exceptions:**
1. Any push or MR/PR creation (all of `ship`).
2. Creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch).
3. DB schema changes or migrations.
4. A `review` that surfaced high-severity findings — never chain into `ship` on those.
5. The business brief written before touching code (`build`, `fix`).

`respond` and `green` add their own gates (posting a reply, re-running a pipeline, integrating the
base) — see the command.

Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo,
(b) ambiguous and not resolved by ticket + domain-memory, or (c) a hard gate. Otherwise take the
sensible default and record it.

**Never a question in `guided`/`auto` — decide, record, continue:**
- (a) **Flow mechanics** — whether to launch a panel, challengers, skeptics or a fan-out, how wide, how many reviewers, inline vs subagent. Each step's recommended default *is* the answer.
- (b) **WIP commits** on the work branch.
- (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`.
- (d) **Size confirmation** — take the proposed size, record it, move on.
- (e) **Anything already decided and recorded** in the work's artifacts or `meta.json.notes`. Reopen only when new evidence contradicts the premise — then lead with the evidence.

Asking these anyway is how an unattended run degrades into a manual one.

## 3. Reporting — how every stop reads

The user comes back to a screen they walked away from, often with other works in other panes.
They have read none of your tool calls, subagent reports or artifacts. So every stop — a question,
a hard gate, the end of the turn — **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action needed, or "nothing, continuing with X">
```

- Every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #` and `Plan:` lines when the work has no `mrs`.
- **Body: at most ~10 lines**, only what could change a decision. Everything else goes to the phase artifact.
- **Product altitude.** Say what changed for whoever uses the software, not what you built. A code identifier earns a line only when the user must decide about it, asked something technical, or named it first.
- **Short lines.** One or two lines of headline, then two to five bullets, one idea each. No "for context", no restating an earlier stop. When the user asks a technical question, answer it in full.
- **Out of the chat, into the artifact:** your own process, your mistakes, corrections to subagent reports, bookkeeping. Subagent completion or idle notifications never earn a turn of their own.
- **Zero-context rule.** First mention of an identifier carries 4–6 words of what it is. Never cite a section number without naming what it is. No jargon the user has not used first.
- **If it is a question, it is `AskUserQuestion`.** Never end a message with a question in prose. If it does not deserve the menu, it is a decision you take and record.

## 4. Live panel — `panel.json`

Whenever the state a panel would show changes, overwrite `.claude/work/<work>/panel.json`
**whole** (never patch) from `meta.json` plus what you know right now:

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

- **`mark` says what a line is**; the reader draws it. `done` · `current` (at most one) · `pending` · `wait` (waiting on someone else: an open MR/PR, a user decision) · `block` · `info`. Marked lines form an aligned column: symbol, `ref`, text, link pinned right. Do not set `style` on a marked line — except `mark: "info"` + `style: ok|warn|error` when the colour *is* the information (a monitoring verdict).
- **`ref` need not be a number**: `#1`, `#3–#6`, `Now`, `Next`, `Decision`. Column width is per block; blocks are separated by blank lines — use them so the MR/PR train and the labels below do not drag each other wide.
- **`link` is a field, never a URL inside `text`.**
- **Order:** (1) work title (`style: title`, no mark); (2) the MR/PR train, one entry per `meta.json.mrs[]` with `ref` `#n`, short title, real-state `mark`, `link` when there is a URL — not-started entries collapse into one `#a–#z` `pending` line; omit the block without `mrs`; (3) `Now` — what is running, the one fact `meta.json` cannot hold; (4) `Next`; (5) `Decision`, `mark: wait`, **only** when parked on the user; (6) blockers, `mark: block` (a sibling repo with `contract_handoff: pending`, a red pipeline, an unmerged dependency).
- **When:** (a) in pre-flight, as soon as `meta.json` is loaded; (b) immediately **before** every stop header; (c) **before** any long stretch (fan-out, full suite, CI poll) — never after, so a step that dies halfway is not shown as finished. When the stretch will outlast the ~30 min staleness warning, set `stale_after_minutes` to what it will really take; (d) wherever `## Close` updates `meta.json`.
- **Rules:** `phase` is the phase you are **running now** (not `meta.json.phase`, which advances only at Close). `header: true` means ticket, type, phase and age are drawn by the reader — do not repeat them in `lines`. Keep it under ~14 lines. Every fact from `meta.json` and the artifacts — an invented MR/PR state is worse than a blank panel. `updated_at` from the real clock (`date -Iseconds`), never carried over. Write in the language of the work's artifacts. No work folder (lightweight `respond`/`green`) → nothing to write.

## 5. Work summary — `00-summary.md`

Each phase reads what the previous ones wrote. Reading every artifact whole on every phase is the
single largest token cost of a work, so every work carries a short handoff:

- `.claude/work/<work>/00-summary.md`, **≤ 15 lines**, overwritten whole at every `## Close`:
  what the work is (one line), size and current MR/PR, the decisions that stand (one line each),
  the contracts declared or received (names and where the literal shape lives), what is pending,
  what the next phase must open in full.
- **Pre-flight of every phase reads `meta.json` and `00-summary.md` first.** Open a full artifact
  only when the step needs it: `build` opens `03-design.md` (contracts, verbatim) and the current
  MR/PR of `04-mr-plan.md`; `review` opens the design's contracts and the implementation log;
  `ship` opens the brief and the review verdict. A summary that does not answer the question you
  have is the cue to open the artifact — never a licence to guess.
- Missing summary (a work started before this rule) → read the artifacts as before, write the
  summary at your Close.
