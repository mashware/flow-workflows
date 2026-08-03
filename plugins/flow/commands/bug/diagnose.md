---
description: Reproduce the bug and pinpoint exactly what is broken
---

# `/flow:bug:diagnose`

Diagnosis phase: isolate **what** is failing before looking for **why**.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

- Load `meta.json`. If `type` is not `bug`, refuse.
- If `size` is `XS`, suggest skipping to `/flow:bug:fix` and stop.
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled`, call `mcp__domain-memory__search_knowledge` with queries about the **suspected component** (handler, worker, endpoint, module). Previous postmortems from the same area often save hours: the same root cause may have appeared under a different symptom.

Examples:
- Dead-letter queue → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <path>"`, `"validation <DTO>"`.
- Frontend → `"<component>"`, `"<flow-name>"`.

2-3 queries in parallel. Maximum wait 2 s; continue on failure. Record relevant findings in the artifact under "Prior domain knowledge".

## 3. Work

Goal: produce a minimal reproducible case and delimit the affected components.

Steps:

1. **Dead-letter queue / messaging**: invoke your project's agent for analyzing dead messages, if one exists; otherwise inspect the message payload and headers to locate the handler, retry history, and initial cause.
2. **API/HTTP**: identify the endpoint, collect a reproducible curl or request, verify the expected response vs. the actual one.
3. **Frontend**: identify the component, route, steps to reproduce, browser developer tools (console, network).
4. **Worker/consumer**: identify the job type, source message, supervisor logs (use `quality.test_one` or the observability command from FLOW.md to filter by worker type).
5. **Database**: failing query, execution plan (`EXPLAIN`), input data that triggers the bug.

Use `Agent general-purpose` to locate the relevant code. Pass a self-contained prompt with the symptom and the initial clues.

## 4. Output

`.claude/work/<TICKET>/02-diagnose.md`:

```markdown
# Diagnosis {TICKET}

## Prior domain knowledge
<findings from the focused search_knowledge, or "no findings">

## Minimal reproduction
<numbered steps that reproduce the bug>

## Expected vs actual behavior
- Expected:
- Actual:

## Involved components
- Suspected files: (not asserting the cause yet)
- Services: backend / worker / frontend / DB

## Bug data
- Stack trace / log:
- Request / payload:
- Input data that triggers it:

## Initial hypotheses
1. …
2. …
```

## 5. Is the size still correct?

If the diagnosis reveals the bug is trivial (a null check, a typo) and was classified M/L due to uncertainty, propose reclassifying to XS/S. Conversely, if what looked like XS turns out to affect several components, raise the size. Confirm with `AskUserQuestion` before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "diagnose"`, add to `phases_done`.
- Suggest next: `/flow:bug:investigate` (M/L) or `/flow:bug:fix` (S if the cause is evident).
- **Autonomy handoff.** Apply the `autonomy.mode` from the preamble: in `manual`, stop here and propose that command with a single `AskUserQuestion` (recommended option by default), invoking it only on confirmation. In `guided`/`auto`, **chain into it automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
