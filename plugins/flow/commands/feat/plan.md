---
description: Split the work into small, independently mergeable MRs/PRs before implementing
---

# `/flow:feat:plan`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a panel, challengers, a skeptic filter or a `Workflow`, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

**Reporting — how every stop reads.** When this command stops — a question, a hard gate, or the end of the turn — the user is coming back to a screen they walked away from, often with other works running in other panes. They have **not** read your tool calls, your subagents' reports, or the artifacts you wrote. So every stop **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action you need from them, or "nothing, continuing with X">
```

Take every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #<n> of <N>` and `Plan:` lines when the work has no `mrs`. After the header, **at most ~10 lines of body**, and only what could change a decision the user might take. Everything else goes to the phase artifact, which is where it stays useful.

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion or idle notifications never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**If it is a question, it is `AskUserQuestion`.** Never end a message with a question in prose: in `manual` it hides among the text, and in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve the menu, it is not a question — it is a decision you take and record.

**Live panel — the same stop, written to disk.** The user typically has several works in flight at once and a panel open per work, so "where is this one at?" is a question they should never have to type at you. Whenever the state such a panel would show changes, overwrite `.claude/work/<work>/panel.json` **whole** (never patch it) with a snapshot built from `meta.json` plus what you know right now:

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

**`mark` says what a line *is*; the panel decides how to draw it.** `done` (merged, finished) · `current` (what is running right now — at most one) · `pending` (not started) · `wait` (shipped or asked, now waiting on someone else — an open MR/PR, a decision of the user's) · `block` (something is stopping this) · `info` (plain statement of fact). Lines carrying a `mark` form an aligned column: symbol, then `ref`, then the text, with the link pinned right. **Do not also set `style` on a marked line** — `style` overrides the mark's colour, and the colour is how the mark reads. The one exception is a line whose colour *is* the information (a monitoring cycle's verdict): there, `mark: "info"` plus `style: ok|warn|error` is the point.

**`ref` need not be a number.** `#1`, `#3–#6`, but equally `Now`, `Next`, `Decision`. Column width is computed **per block**, and blocks are separated by blank lines — so the MR/PR train aligns with the train and the labels below align with each other, without dragging one another wide. Use blank lines deliberately: they are what keeps two groups from distorting each other.

**`link` is a field, never text inside `text`.** The panel shortens it to its MR/PR number and pins it to the right of the line, or hangs it underneath when it does not fit. Pasting a raw URL into `text` gets you a 60-character line that wraps.

**What goes in, in this order.** (1) The work title (`style: title`, no mark). (2) The MR/PR train — one entry per `meta.json.mrs[]`, `ref` `#n`, a short title, the `mark` for its real state, and `link` for the ones that have a URL; entries not started yet collapse into a single `#a–#z` `pending` line; omit the block when the work has no `mrs`. (3) `Now` — what is actually running, the one fact `meta.json` cannot hold. (4) `Next`. (5) `Decision`, marked `wait`, **only** when the flow is parked on the user, naming the decision. (6) Blockers marked `block`: a sibling repo whose `contract_handoff` is `pending`, a red pipeline, a dependency that has not merged.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. When that stretch is expected to outlast the panel's staleness warning (~30 min), set **`stale_after_minutes`** to what it will really take, so a long CI poll is not reported as a dead agent. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a header drawn from it shows the previous phase for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, phase and age are drawn by the panel — never repeat them in `lines`. Keep it under ~14 lines; the panel wraps a long line and aligns the continuation under its text, so length is a matter of saying less, not of measuring columns. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

Delivery planning phase. **No code is written.** Decides how to split the feature into MRs/PRs that can live on their own on the main branch even if the subsequent ones never land.

## 1. Pre-flight

- Load `meta.json` by current branch. If it does not exist, send the user to `/flow:feat:start`.
- Require `design` in `phases_done`. If missing, send to `/flow:feat:design` and stop.
- Read `01-context.md`, `02-brainstorm.md` (if it exists), and `03-design.md`.
- **If `size` is `XS` or `S`**: warn that this phase does not apply (always 1 MR/PR), mark `plan` as skipped in `phases_done` with value `"plan:skipped"`, and suggest `/flow:feat:build`. Stop.

## 2. Work

Load the project convention skills (see `FLOW.md` section `conventions`).

**Before splitting, apply a YAGNI filter to the design**: the plan only divides work that `03-design.md` has already validated as necessary. If when splitting you see a MR/PR (or part of one) dedicated to a **hypothetical future problem** or to protecting against a scenario that **cannot happen in this project**, do not turn it into a deliverable: mark it as "out of scope — idea for a separate ticket" and notify the user. Do not split or plan what is not going to be built today. If this reveals that the design let in unnecessary pieces, return to `/flow:feat:design` to trim them before planning.

Launch a subagent with this brief (self-contained):

> Read `.claude/work/<TICKET>/03-design.md`. Propose how to split the implementation into **independently mergeable MRs/PRs**: each one must be able to live on its own on the main branch without breaking anything even if the subsequent ones never land. Think about feature flags, temporary dead code, schema backwards-compatibility, multi-step online migrations, stable event contracts. **Do not create MRs/PRs dedicated to hypothetical future problems or to defenses against scenarios the project already prevents — split only what is necessary for what the ticket asks for today (YAGNI).**
>
> Then build the **dependency graph** (which MR/PR needs another one merged or deployed before it can start) and **sort it topologically into execution waves**: wave 1 = everything with no unmet dependency (can start immediately, in parallel); wave 2 = everything unlocked once wave 1 is in; and so on. **Number the MRs/PRs following that wave order** — the lowest numbers to wave 1, then wave 2, etc. — so that **every MR/PR's dependencies have a strictly lower number than itself** (`#1` is always a legitimate starting point, never "start at #5"). Within a wave (parallel, no dependency between them) the order is free; number them consecutively. **The number is the execution order, not a grouping by feature area** — do not number by "Part A / Part B" and then reorder in prose.
>
> Return a table with: **`n`** (final number = execution order), **`wave`**, **`depends_on`** (list of the `n` it needs merged first; empty if it can start immediately), what it includes, standalone-mergeable (yes/no + how it is guaranteed), what it unlocks for the next one, risk if it stays alone on the main branch indefinitely, **`lines_est`** (approximate lines, sum of added + modified) and **`files_est`** (approximate files it touches). Estimates are **soft** — they serve as a thermometer during build, not as a contract. If the correct answer is "1 single MR/PR", justify it and return that. Under 600 words.

If the feature touches payments, authentication, or sensitive data, launch **in parallel** the `agents.security` agent from `FLOW.md` (or `Agent general-purpose` if empty) with the brief: "For each proposed MR/PR in the delivery plan, identify whether it opens a security exposure window while the subsequent ones are not yet merged (e.g. new endpoint without the final check, column without final constraint). Only actionable findings."

## 3. Output

Consolidate in `.claude/work/<TICKET>/04-mr-plan.md`:

```markdown
# Delivery plan <TICKET>

## Summary
- Number of MRs/PRs: N
- Split justification (1-2 lines):

## Execution order (waves)
The number of each MR/PR **is** its execution order: a lower number never depends on a higher one, so `#1` is always a valid starting point.
- **Wave 1** (start now, in parallel): #1, #2
- **Wave 2** (after #1 is merged/deployed): #3, #4
- **Wave 3** (after #3): #5

MRs/PRs in the same wave with no dependency between them can be built in parallel (or as a train). There is no "start at #5" — if something can start first, it is numbered first.

## MRs/PRs

### #1: <short title>
- **Wave**: N — **depends on**: #a, #b (or "nothing — can start immediately").
- **Includes**: bullets of what changes.
- **Standalone-mergeable**: yes / no — how it is guaranteed (flag, nullable column, unused code, etc.).
- **Unlocks**: what the next one can do.
- **Risk if it stays alone on the main branch**: …
- **Estimated size**: XS / S / M.
- **`lines_est`**: ~N lines (added + modified).
- **`files_est`**: ~N files.

### #2: …

## Dependencies between MRs/PRs
<simple graph in bullets: #3 depends on migration from #1, etc. This graph is what produced the waves and the numbering above — keep them consistent.>

## Plan risks
- Online migrations:
- Compatibility with deployed clients:
- New domain events:
- Introduced feature flags (and when to remove them):

## Decision: one or several MRs/PRs?
<if 1: justification. If several: why this split and not another>
```

If the plan proposes 1 single MR/PR, keep the artifact the same with that single entry and justification. Do not force artificial splitting.

## 4. Register in `meta.json`

Add to `meta.json` the `mrs` array with the agreed plan:

```json
"mrs": [
  { "n": 1, "title": "…", "size": "S", "status": "pending", "phases_done": [], "wave": 1, "depends_on": [], "lines_est": 120, "files_est": 6 },
  { "n": 2, "title": "…", "size": "M", "status": "pending", "phases_done": [], "wave": 2, "depends_on": [1], "lines_est": 350, "files_est": 14 }
]
```

`n` follows the execution order (topological): `depends_on` only ever references a **lower** `n`, and `wave` groups MRs/PRs that can run in parallel. `/flow:feat:build §1` reads `depends_on` to pick the next **startable** MR/PR and to tell the user which ones can go in parallel; keep both fields accurate whenever the plan is edited or renumbered.

Each entry starts with an empty **`phases_done`**: it tracks the phases (`build`/`review`/`validate`) completed **for that MR/PR specifically**, so the gates in `/flow:feat:review §1`, `/flow:feat:validate §1` and `/flow:feat:ship §1` judge *this* MR/PR — a sibling's review never satisfies a new MR/PR's gate. Leave it `[]` for every seeded entry.

Estimates are **indicative**, not contractual. `/flow:feat:build` uses them as a thermometer: if real work exceeds `lines_est` by +50% or `files_est + 2`, it triggers the "cut or continue" question (see §C in build).

Valid statuses:

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started. |
| `in_progress` | Build/review/validate for this MR/PR is in progress. |
| `merged` | MR/PR merged to the main branch. |
| `closed` | MR/PR closed without merge (rejected, discarded). Requires `note` with reason. |
| `superseded` | Replaced by a later MR/PR (the plan was rethought). Requires `note` pointing to the replacement. |

`/flow:feat:build` moves `pending` → `in_progress`. `/flow:feat:ship` moves `in_progress` → `merged` when it confirms the merge, or to `closed` if discarded. If after a build the splitting needs to be rethought, return to `/flow:feat:plan`, mark the old entry as `superseded`, and add the new ones.

### Cross-repo entries

If a slice of the plan lands in **another repo**, it is not one of *this* repo's `mrs` — record it in `meta.json.related_repos` (`{ "repo", "scope", "status": "pending" }`) instead, so `/flow:feat:ship` reminds you to open the work there. Keep `mrs` to the MRs/PRs of this repo.

## 5. Is the size still correct?

If when splitting you find that there is really just 1 small MR/PR (≤ 50 lines, no migrations), reclassify to `S` and notify. Conversely, if 5+ large MRs/PRs come out, consider upgrading to `L`. Confirm with `AskUserQuestion` before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "plan"`, add `plan` to `phases_done`.
- Refresh `panel.json`. This is the phase that gives the panel its train: from here on it carries one line per `mrs[]` entry, and "how many are left" stops being something the user has to ask for. Nothing is merged or open yet, so every entry reads as pending under `Left`.
- **Show the plan the way it will be executed**, not just as a list. The user has to be able to see, without decoding two columns, what runs at the same time and what waits for what. So print the wave line first, then the table:

  ```
  Wave 1: #1 ∥ #2  (in parallel, start now) → Wave 2: #3 → Wave 3: #4 ∥ #5 ∥ #6 ∥ #7
  ```

  `∥` = no dependency between them, they can be built in parallel or as a train; `→` = the next wave waits for the previous one to merge. Then the table with `#`, wave, `depends_on`, title and estimate. One line for the split rationale. Nothing else — the risks and the discarded alternatives are in the artifact for whoever wants them.
- If they request changes, edit the artifact and `meta.json.mrs` before advancing.
- Suggest `/flow:feat:build` to start the first MR/PR.
- **Autonomy handoff.** Approving the split is a genuine decision point, so in `manual` and `guided` ask for it before advancing. In `auto`, record the plan as accepted in `04-mr-plan.md` and **chain into `/flow:feat:build` automatically** in this same turn. In `manual`, propose it with a single `AskUserQuestion` instead of leaving it as a written suggestion.
