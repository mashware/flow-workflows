---
description: Reproduce the failure and pinpoint exactly what is broken
---

# `/flow-bug-diagnose`

Diagnosis phase: isolate **what** is failing before looking for **why**.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a subagent panel, challengers or a skeptic filter, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

**Reporting — how every stop reads.** When this command stops — a question, a hard gate, or the end of the turn — the user is coming back to a screen they walked away from, often with other works running in other panes. They have **not** read your tool calls, your subagents' reports, or the artifacts you wrote. So every stop **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action you need from them, or "nothing, continuing with X">
```

Take every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #<n> of <N>` and `Plan:` lines when the work has no `mrs`. After the header, **at most ~10 lines of body**, and only what could change a decision the user might take. Everything else goes to the phase artifact, which is where it stays useful.

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion notices never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**A question is asked as a question.** Never end a message with one buried in prose: write it as an explicit numbered choice with the recommended option marked, and wait. In `manual` a question hidden in the text is invisible; in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve to be numbered and waited on, it is not a question — it is a decision you take and record.

**Live panel — the same stop, written to disk.** The user typically has several works in flight at once and a panel open per work, so "where is this one at?" is a question they should never have to type at you. Whenever the state such a panel would show changes, overwrite `.claude/work/<work>/panel.json` **whole** (never patch it) with a snapshot built from `meta.json` plus what you know right now:

```json
{
  "updated_at": "2026-08-06T16:45:00+02:00",
  "phase": "validate",
  "header": true,
  "lines": [
    {"text": "Expose a thread's tracking state and events", "style": "title"},
    "",
    {"text": "#1 batch read sources        MR open", "style": "ok"},
    {"text": "https://gitlab.com/…/merge_requests/9977", "style": "dim", "indent": 3},
    {"text": "#2 per-message grouping      validating"},
    {"text": "#3–#6 channel map · use case · detail · route", "style": "dim"},
    "",
    "Right now: unit suite and the test agent over #2",
    {"text": "Next: ship #2 — needs your confirmation", "style": "dim"},
    "",
    {"text": "Waiting on you: confirm the MR/PR body before I create it", "style": "accent"},
    {"text": "sibling-repo still needs the endpoint contract", "style": "warn"}
  ]
}
```

**What goes in, in this order.** (1) The work title. (2) The MR/PR train — one line per `meta.json.mrs[]` entry, `#n`, short title, and **its real state as the last column**, with the **URL indented underneath every entry that is still open**, because chasing you for a link is the single most common thing the user has to ask for; the ones not started yet collapse into a single `#a–#z` line; omit the block entirely when the work has no `mrs`. **Never group the entries under headings like "done" / "left"**: in a train an MR/PR that has shipped is *open, waiting to merge*, and a heading that calls it done states something false in the one place the user is trusting at a glance. The state column says it; nothing above it needs to. (3) `Right now:` — one line of prose on what is actually running, the one fact `meta.json` cannot hold. (4) `Next:` — what follows. (5) `Waiting on you:` in `accent`, **only** when the flow is parked on a decision of theirs, naming that decision. (6) Blockers in `warn`: a sibling repo whose `contract_handoff` is `pending` (from `related_repos`), a red pipeline, a dependency that has not merged. Styles are semantic — `normal` `dim` `title` `accent` `ok` `warn` `error` — the panel owns the palette.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a panel that reads the phase from it shows the previous one for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, age — and the phase, from `phase` when present — are already drawn by the panel; never repeat them in `lines`. Keep it under ~14 lines, and keep **each line short enough not to wrap** (~55 characters is the safe width): a wrapped line loses its column and its continuation does not inherit `indent`, so it is better to say less than to say it in two ragged lines. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

- Load `meta.json`. If `type` is not `bug`, refuse.
- If `size` is `XS`, suggest skipping to `/flow-bug-fix` and stop.
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled`, call `mcp__domain-memory__search_knowledge` with queries about the **suspected component** (handler, worker, endpoint, module). Prior postmortems in the same area often exist and can save hours — the same root cause may have appeared under a different symptom.

Examples:
- Failed queue → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <path>"`, `"validation <DTO>"`.
- Frontend → `"<component>"`, `"<flow-name>"`.

2-3 queries in parallel. Max wait 2 s; continue if it fails. Record relevant findings in the artifact under "Prior domain knowledge".

## 3. Work

Goal: produce a minimal reproducible case and delimit the affected components.

Steps:

1. **If it's a failed queue / messaging**: invoke the subagent your project has for analyzing dead-letter messages if one exists; if not, inspect the message payload and headers to locate the handler, retry history, and initial cause.
2. **If it's API/HTTP**: identify the endpoint, capture a reproducible curl or request, verify expected vs actual response.
3. **If it's frontend**: identify the component, route, reproduction steps, browser devtools (console, network).
4. **If it's a worker/consumer**: identify the job type, source message, supervisor logs (use `quality.test_one` or the equivalent observability command from FLOW.md filtered by worker type).
5. **If it's DB**: identify the problematic query, execution plan (`EXPLAIN`), input data that triggers the failure.

Use a general-purpose subagent to locate the relevant code. Pass a self-contained prompt with the symptom and initial clues.

## 4. Output

`.claude/work/<TICKET>/02-diagnose.md`:

```markdown
# Diagnosis {TICKET}

## Prior domain knowledge
<findings from the focused search_knowledge, or "no findings">

## Minimal reproduction
<numbered steps that reproduce the failure>

## Expected vs actual behavior
- Expected:
- Actual:

## Implicated components
- Suspected files: (not asserting the cause yet)
- Services: backend / worker / frontend / DB

## Failure data
- Stack trace / log:
- Request / payload:
- Input data that triggers it:

## Initial hypotheses
1. …
2. …
```

## 5. Is the size still correct?

If the diagnosis reveals the failure is trivial (a null check, a typo) and it was classified as M/L out of uncertainty, propose reclassifying to XS/S. Conversely: if what appeared to be XS turns out to affect multiple components, raise the size. Confirm with the user before changing `meta.json.size`.

## 6. Wrap-up

- Update `meta.json`: `phase = "diagnose"`, add to `phases_done`.
- Suggest next step: `/flow-bug-investigate` (M/L) or `/flow-bug-fix` (S if the cause is evident).
- **Autonomy handoff.** In `manual`, stop here and propose that command as a question, invoking it only on confirmation. In `guided`/`auto`, **chain into it automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
