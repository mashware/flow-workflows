---
description: Implement the minimal fix and keep a log
---

# `/flow-bug-fix`

Apply the fix. **Minimum viable**: do not use this as an opportunity to refactor adjacent areas. If you discover more problems, note them but don't touch them here.

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

- Load `meta.json`.
- If `size` is `XS`: allow starting without `diagnose`/`investigate`, but require a 2-3 line description of the fix.
- If `size` ≥ S: require `diagnose` (and `investigate` for M/L) in `phases_done`.
- Read prior artifacts.

## 2. Fix brief (before touching code)

Before touching any code, write a brief in **plain language** (non-technical) specific to this fix:

```
Fix brief {TICKET}

What stops happening after the fix:
- <observable symptom the user reported, described in terms of what they saw>

What changes:
- <one line, in business or behavioral terms, not file names>

What is NOT touched:
- <adjacent areas that might tempt a refactor>
- <potential regressions that are NOT addressed here>
```

**Ask the user** whether this reflects the expected fix — **in every autonomy mode, `auto` included** (a deliberate gate: the last point where the scope can be fixed before there is a diff to argue with):
- **Yes, go ahead** → apply the fix.
- **No, something is missing or wrong** → adjust the brief, ask again. Do not touch code until confirmed.

Save the brief at the top of `04-fix.md`. If during implementation the temptation arises to "while we're here, also fix X" (common with bugs), return to §2.3 — fixes that expand into adjacent refactors are the main path to introducing new regressions while fixing the old one.

## 2.1 Work

- Apply the minimal fix targeting the finding in `03-investigation.md` (or the diagnosis if you skipped investigate).
- If touching a sensitive area (authentication, payments, sensitive data), consult the `agents.architecture` subagent from FLOW.md to confirm the correct layer; if empty, cross-check directly against `conventions` in FLOW.md.
- **Comment discipline**: comment only a non-obvious *why*; never narrate what the code says; match the file's comment density. **Never put the ticket ID or "fix for #N" in a code comment** — that lives in the commit/branch/MR-PR, not the source.
- Keep the log updated while editing.

**Commits follow the mode** (same contract as `/flow-feat-build` §2.2). After each step (or the whole fix if it is one step), **always report** the summary first: files, lines, suggested validation. Then, per mode: **`manual`** — the agent **does not run `git commit` on its own**; wait for the user's decision (commit the work-in-progress now, wait until they validate, or continue without committing), so the fix can be tested by hand before it is recorded in history. **`guided`** — ask **once**, at the first step, and apply that answer for the rest of the fix; record it in `04-fix.md`. **`auto`** — commit the WIP yourself (`git add <files> && git commit -m "WIP <TICKET>: <step>" --no-verify`) and continue without asking; invoking the command in `auto` is the explicit authorization, and it covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode.

## 2.3 Does something arise outside the brief?

If during the fix something tempts you that **is not in the §2 brief** ("while we're here, fix X too", "this rename fits here", "this extra test covers another case"):

**Pause before touching it** and ask the user:
- **Yes, add it to the brief** — update the brief in `04-fix.md` and continue.
- **No, leave it out** — note it under "Areas with similar risk" (if it's a risk from the same pattern) or create an "Ideas for separate tickets" section in `04-fix.md`.

Scope-expanding fixes are the main cause of collateral regressions — the flow pushes you to keep the fix genuinely minimal.

## 3. Log

`.claude/work/<TICKET>/04-fix.md`:

```markdown
# Fix {TICKET}

## Brief
**What stops happening after the fix**:
- <observable symptom>

**What changes**:
- <one line of behavior>

**What is NOT touched**:
- <adjacent areas out of scope>

## Fix description
<one sentence: "The fix consists of …">

## Changes by file
- <file> — what changed and why (1 line)

## Areas with similar risk (noted, NOT touched here)
- open a separate ticket if appropriate

## Ideas for separate tickets
<things that came up during the fix and were decided NOT to include>

## Relevant commands
- <commands used to install dependencies, etc.>
- …
```

## 4. Immediate quality

Use the commands from `quality` in FLOW.md; if empty, auto-discover (Makefile, npm/composer scripts) and report what you use:

- `quality.style_fix`
- `quality.static_analysis`
- Run the test that covers the fix: `quality.test_one` (if it doesn't exist, you'll add it in `/flow-bug-validate`).

## 4.1 Is the investigation still valid?

If while applying the fix you discover that the **root cause** wasn't what `03-investigation.md` pointed to (e.g. the suspected commit wasn't the culprit, or the broken pattern is somewhere else), **pause and return to `/flow-bug-investigate`** to update the cause before continuing. A fix that doesn't target the real "why" usually leaves the issue open in another form. Do not advance with an investigation you know is incomplete.

## 5. Wrap-up

- Update `meta.json`: `phase = "fix"`, add to `phases_done`.
- Suggest next step: `/flow-bug-validate` (S/M/L) or `/flow-bug-review` (XS).
- **Autonomy handoff.** In `manual`, stop here and propose that command as a question, invoking it only on confirmation. In `guided`/`auto`, **chain into it automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
