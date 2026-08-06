---
description: Implement the minimal fix and keep a log
---

# `/flow:bug:fix`

Apply the fix. **Minimum viable**: do not take the opportunity to refactor adjacent areas. If you discover more problems, note them but do not touch them here.

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

**Live panel — the same stop, written to disk.** The user typically has several works in flight at once and a panel open per work, so "where is this one at?" is a question they should never have to type at you. Whenever the state such a panel would show changes, overwrite `.claude/work/<work>/panel.json` **whole** (never patch it) with a snapshot built from `meta.json` plus what you know right now:

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

**What goes in, in this order.** (1) The work title. (2) The MR/PR train — one line per `meta.json.mrs[]` entry (`#n`, short title, state), with the **URL indented underneath every entry that is still open**, because chasing you for a link is the single most common thing the user has to ask for; omit the whole block when the work has no `mrs`. (3) `Right now:` — one line of prose on what is actually running, the one fact `meta.json` cannot hold. (4) `Next:` — what follows. (5) `Waiting on you:` in `accent`, **only** when the flow is parked on a decision of theirs, naming that decision. (6) Blockers in `warn`: a sibling repo whose `contract_handoff` is `pending` (from `related_repos`), a red pipeline, a dependency that has not merged. Styles are semantic — `normal` `dim` `title` `accent` `ok` `warn` `error` — the panel owns the palette.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `header: true` means ticket, type, phase and age are already drawn by the panel — never repeat them in `lines`. Keep it under ~14 lines, and write sentences rather than measured columns: the panel wraps to its width and crops to its height. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

- Load `meta.json`.
- If `size` is `XS`: allow starting without `diagnose`/`investigate`, but require a 2-3 line description of the fix.
- If `size` ≥ S: require `diagnose` (and `investigate` for M/L) in `phases_done`.
- Read previous artifacts.

## 2. Fix brief (before touching code)

Before touching any code, write a brief in **plain** (non-technical) language specific to this fix:

```
Fix brief {TICKET}

What stops happening after the fix:
- <observable symptom the user reported, described in terms of what they saw>

What is changed:
- <one line, in business or behavior language, not in terms of files>

What is NOT touched:
- <adjacent areas that might be tempting to refactor>
- <potential regressions that are NOT addressed here>
```

**Ask the user with `AskUserQuestion`** whether this reflects the expected fix — **in every autonomy mode, `auto` included**. This gate is deliberate: with bugs, the temptation to widen the fix is the main source of collateral regressions, and this is the last point to settle the scope before there is a diff.

In `guided`/`auto` this is one of the only two stops of the whole flow (this one and `ship`), so it carries the **full stop header** from the Reporting preamble above it, followed by the brief. Options:
- **Yes, go ahead** → apply the fix.
- **No, something is missing or wrong** → adjust the brief, ask again. Do not touch code until confirmed.

Save the brief at the top of `04-fix.md`. If during implementation the temptation arises to "also fix X while we're at it" (common with bugs), return to §2.3 — fixes that expand into adjacent refactors are the primary way to introduce new regressions while fixing the original one.

## 2.1 Work

- Apply the minimal fix targeting the finding from `03-investigation.md` (or the diagnosis if you skipped investigate).
- If it touches a sensitive area (authentication, payments, sensitive data), consult the `agents.architecture` agent from FLOW.md to confirm the correct layer; if that is empty, check directly against `conventions` from FLOW.md.
- Use `TaskCreate` for fix steps if there are more than 2.
- **Comment discipline**: add a comment only to explain a *why* the code cannot (a non-obvious constraint, the reason for the workaround, a subtle invariant); do not narrate what the code already says, and match the surrounding file's comment density. **Never write the ticket ID or "fix for #N" into a code comment** — that lives in the commit/branch/MR-PR, not the source (a bug fix especially tempts a "// fixes X" breadcrumb that just rots).
- Keep the log updated while editing.

**Commits, gated by `autonomy.mode`** (same contract as `/flow:feat:build §2.2`). After completing each step (or the whole fix if it is a single step), **always report** a summary first: files, lines, suggested validation. Then, per mode:

- **`manual`** — the agent does **not run `git commit` on its own**. Wait for the user's decision: commit the work-in-progress now, wait until they validate it, or continue without committing. Without their explicit confirmation, changes stay in the working tree so the fix can be tested by hand before it is recorded in history.
- **`guided`** — ask **once**, at the first step, and apply that answer for the rest of the fix; record it in `04-fix.md`.
- **`auto`** — commit the WIP yourself (`git add <files> && git commit -m "WIP <TICKET>: <step>" --no-verify`) and continue without asking. Invoking the command in `auto` is the explicit authorization the system rule requires, and it covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode.

## 2.3 Something outside the brief comes up?

If during the fix a temptation arises that **is not in the brief of §2** ("while I'm at it, I'll also fix X", "this rename fits here", "this extra test covers another case"):

**Pause before touching it** and ask the user with `AskUserQuestion`:
- **Yes, add it to the brief** — update the brief in `04-fix.md` and continue.
- **No, leave it out** — note it under "Areas with similar risk" (if it is a risk from the same pattern) or create an "Ideas for separate tickets" section in `04-fix.md`.

Expanded fixes are the primary cause of collateral regressions — the flow pushes you to keep the fix truly minimal.

## 3. Log

`.claude/work/<TICKET>/04-fix.md`:

```markdown
# Fix {TICKET}

## Brief
**What stops happening after the fix**:
- <observable symptom>

**What is changed**:
- <one line of behavior>

**What is NOT touched**:
- <adjacent areas out of scope>

## Fix description
<one sentence: "The fix consists of …">

## Changes by file
- <file> — what changed and why (1 line)

## Areas with similar risk (noted, NOT touched here)
- open a separate ticket if warranted

## Ideas for separate tickets
<things that came up during the fix and were decided NOT to include>

## Relevant commands
- <commands used to install dependencies, etc.>
- …
```

## 4. Immediate quality

Use the `quality` commands from FLOW.md; if they are empty, auto-discover (Makefile, npm/composer scripts) and report what you use:

- `quality.style_fix`
- `quality.static_analysis`
- Run the test that covers the fix: `quality.test_one` (if it does not exist, you will add it in `/flow:bug:validate`).

## 4.1 Is the investigation still valid?

If while applying the fix you discover that the **root cause** was not what `03-investigation.md` pointed to (e.g. the suspected commit was not the culprit, or the broken pattern is elsewhere), **pause and go back to `/flow:bug:investigate`** to update the cause before continuing. A fix that does not target the real reason usually leaves the incident open in a different form. Do not proceed with an investigation you know is incomplete.

## 5. Close

- Update `meta.json`: `phase = "fix"`, add to `phases_done`.
- Suggest next: `/flow:bug:validate` (S/M/L) or `/flow:bug:review` (XS).
- **Autonomy handoff.** Apply the `autonomy.mode` from the preamble: in `manual`, stop here and propose that command with a single `AskUserQuestion` (recommended option by default), invoking it only on confirmation. In `guided`/`auto`, **chain into it automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
