---
description: Validate tests, edge cases, and integrity before shipping
---

# `/flow:feat:validate`

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

Verify the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. **In a multi-MR/PR work** (`meta.json.mrs` has >1 entry) require `review` in the **current `in_progress` MR/PR's** own `phases_done` (its `mrs[]` entry), not the work-level list — a previous MR/PR's `review` does not count. If missing, send to `/flow:feat:review`.
- If `size` is `XS`, this phase may be skipped (warn and continue with `/flow:feat:ship`).

## 2. Work

Launch **in parallel**:

1. **Testing agent**: use the `agents.testing` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Review the branch changes and complete the test suite where coverage is missing. Focus: the acceptance criteria in `03-design.md` marked `test` that no current test demonstrably asserts (see the §3 mapping), plus edge cases from `03-design.md`, error paths, input validations, emitted domain events. Do not rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance agent** if the feature touches persistence, repositories, templates on hot paths, controllers with real traffic, or calls anything outside the process inside a loop: use the `agents.performance` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Detect N+1, missing indexes, unbounded queries, flush in a loop, per-iteration calls that leave the process (external API, HTTP, cache, filesystem), and heavy synchronous work that should go to a queue. For any call inside a loop that can fail, follow what **each failed iteration** sets off downstream — what it publishes, enqueues, disables or logs — and whether N failures multiply it. Report only actionable findings."

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and note what you use. If there are frontend changes and `quality.frontend_test` is defined, run it as well.

## 3. Criteria coverage (S and larger)

The gate of this phase is not "suite green" — it is "every acceptance criterion in `03-design.md` is demonstrably proven". Build the mapping (`XS` skips this phase entirely, so it does not apply; for `S` and larger it does):

1. Read the enumerated **Acceptance criteria** from `03-design.md`. For each criterion, find the test(s) that prove it — the specific test that would fail if that criterion were violated. A test that merely "touches the area" is not enough; it must assert the criterion's observable result (reuse the literal values from the criterion / contracts).
2. Classify each criterion:
   - **proven-by-test** — a named test demonstrably asserts it. Record the test path.
   - **needs-manual** — not provable by an automated test now (UI, end-to-end flow, visual result). Goes to the assisted loop in §4.
   - **unproven** — neither: no test asserts it and it is not a manual case. This is a gap → the testing agent in §2 adds the missing test; until it exists, the criterion stays `unproven`.
3. A criterion is **not** proven just because the suite is green. If no test actually asserts its result, it is `unproven` until one is added.

## 4. Assisted manual verification (for `needs-manual` criteria)

If `meta.json.worktree` is not null (the work was developed in a worktree and the runnable env lives in the main checkout), offer once before verifying: "to test this branch against the main environment, run `/flow:work:try <meta.branch>` (it switches the main checkout and re-syncs per `git.worktree_resync`), and `/flow:work:try --back` to return afterwards." Suggest it, do not run it yourself and do not force it.

For criteria that no automated test can prove now, verify them **together with the user**, one or a few at a time, keeping the running register — the user runs the flow, you keep the checklist until every criterion is accounted for:

1. For each `needs-manual` criterion, tell the user exactly what to do and what to observe, phrased from its given/when/then (e.g. "Open `/campaigns`, filter by last 7 days → the list should show only campaigns from the last 7 days, newest first").
2. Ask with `AskUserQuestion` — options **Pass** / **Fail** / **Blocked** (cannot test now). Batch up to 4 criteria per question.
3. Record each answer immediately in `07-validation.md` (§6 output, "Criteria coverage"):
   - **Pass** → status `proven-manually`, note the date.
   - **Fail** → status `unproven`; the criterion is not met — this blocks the gate until the implementation is fixed and re-verified.
   - **Blocked** → status `unproven`; record why. A blocked criterion does not pass the gate.
4. Repeat until every `needs-manual` criterion is `proven-manually`, or the user decides to stop (the rest stay `unproven`, which blocks advancing in §7).

## 5. Manual edge cases

If the feature has UI or critical flows:
- If it touches payments: test with the test cards or credentials appropriate for the provider (see `Skill stripe:test-cards` if using Stripe).
- If it touches workers/queues: make sure no jobs are stuck in dead-letter. If there are and they are not yours, do not touch them here.
- If it touches migrations: run `quality.db_update` from `FLOW.md` (if defined). Verify there is no unexpected schema difference with the comparison command the project uses.

## 6. Output

Write `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validation <TICKET>

## Criteria coverage
<one row per acceptance criterion from 03-design.md (S+; "N-A — XS" if the phase was skipped)>

| Criterion | Proof type | Test / confirmation | Status |
|-----------|-----------|---------------------|--------|
| AC1: <short> | test | `tests/Foo/BarTest::testX` | ✅ proven-by-test |
| AC2: <short> | manual | confirmed by user 2026-06-24 | ✅ proven-manually |
| AC3: <short> | manual | — | ❌ unproven (blocked: staging down) |

## Test coverage
- Unit added: N (list)
- Integration added: M
- Functional added: K

## Suite results
- `<quality.test>`: ✅ / ❌ (N tests, X failures)
- `<quality.frontend_test>`: ✅ / ❌ / N-A
- `<quality.static_analysis>`: ✅ / ❌

## Performance
- Analysis findings: …
- Open risks: …

## Edge cases verified
- [x] …
- [ ] …

## Regressions
- Areas checked: …
- No regressions detected / detected: …
```

## 7. Close

- **Do not advance `phase`** if any of these holds: tests are red, regressions are found, or **any acceptance criterion is `unproven`** (no test demonstrably asserts it and it was not manually confirmed). The criterion→test mapping is part of the gate, not just a report — the same "do not advance on red" rule. The user resolves the gap (add the missing test, fix the implementation, or finish the manual verification) and returns to `/flow:feat:validate`.
- If the suite is green **and** every acceptance criterion is `proven-by-test` or `proven-manually`: `phase = "validate"`, add to `phases_done`. **In a multi-MR/PR work**, also add `validate` to the current `in_progress` MR/PR's own `phases_done` (its `mrs[]` entry) — the per-MR/PR marker `/flow:feat:ship §1` gates on. Suggest `/flow:feat:ship`.
- **Autonomy handoff — this one stops in every mode, `auto` included.** `ship` pushes and opens the MR/PR, an outward-facing action and a hard gate in every mode, so do **not** chain into it automatically. Stop here and propose `/flow:feat:ship` with a single `AskUserQuestion` (recommended option by default), invoking it only when the user confirms. This is the deliberate end of the unattended run, not a forgotten handoff.

In `guided`/`auto` this is, together with the brief in `/flow:feat:build §2`, **the only stop of the whole MR/PR** — everything between them ran unattended. So it carries the **full stop header** and the body answers, in this order: what is green, what this MR/PR proves and what it does not, and what shipping it takes. The user has been away for the entire build and review; assume they have read none of it.
