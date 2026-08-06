---
description: Commit, push, MR/PR the fix
---

# `/flow:bug:ship`

Close the bug flow: commit, push, MR/PR. Uses the same mechanics as `/flow:feat:ship` with two differences:

1. If `99-postmortem.md` exists, **include the link or the executive summary** in the MR/PR description.
2. The `save-knowledge` offer was already made in `/flow:bug:postmortem` — do not ask again here.

## 0. Pre-flight

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

- Load `meta.json`. Require `review` in `phases_done` (and `validate` if `size` ≥ S, and `postmortem` if `size` is L).
- If not, refuse and redirect to the missing step.

## 1. Draft title and description (without sending anything yet)

**Important**: in this step `commit-push-pr` is **not** invoked yet and nothing is created. Only draft the content to show the user in §2.

### Title

Format: `{PREFIX}{TICKET} Fix <observable symptom, in plain language> [patch]`.

**Good**: `{PREFIX}15310 Fix opens counted twice on retry [patch]`
**Bad**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Fixes are `[patch]` unless they break a contract — in that case reconsider whether it is actually a fix or a versioned feature.

The `{PREFIX}{TICKET}` in the title is for humans / for trackers that link by convention (Jira, Linear). **On GitHub/GitLab a ticket in the title does NOT link the MR/PR to the issue** — that link must live in the body (below).

### Issue link (in the body — fills the tracker's "Development"/linked panel)
A fix is a single MR/PR that completes the issue, and it targets `git.default_base`, so the closing keyword works directly. Add it at the top of the body per `tracker.tool`:
- **`gh` / `glab`**: `Closes #<N>` (`<N>` = numeric issue id from `meta.json.ticket`) — auto-links + auto-closes on merge.
- **`acli` (Jira)**: add nothing — Jira links via the issue key in the branch name and title prefix.
- **`linear`**: `Closes <TICKET>` (Linear id).
- **`none` / empty**: nothing.

**Referencing other issues/MRs/PRs in the body**: the `Closes #<N>` line above uses the **real issue id** and must auto-link. But anywhere else in the body, if you mention another MR/PR, **do not write a bare `#<number>` that is not the real issue** — GitHub/GitLab auto-resolve `#N` to whatever issue/PR carries that number and append its state (e.g. `#5 (closed)`), linking the wrong thing. Reference an existing MR/PR by its **URL**, and one that does not exist yet by its **title** in quotes.

### Description

**Build the description from the Brief in `04-fix.md`**, not from previous technical artifacts. If `04-fix.md` has no Brief (old fix), draft one now from the reported symptom.

Template (in this order):

```markdown
## What stops happening after this fix
<what the user was observing that they will no longer observe. Symptom language, not code language.>

## What is changed (behavior)
<1-2 lines in plain language. NOT files.>

## What has NOT been touched
<bullets from the "What is NOT touched" section of the Brief. Important so the reviewer knows the fix is minimal.>

## Steps to reproduce and test
<from `05-validation.md`:
1. Reproduction of the bug before the fix (no longer applies, but documents the case).
2. How to verify the behavior is correct after the fix.
3. Regression test added and where it is.>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the fix touches the database)
SQL to run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/data corrections — all together>
```
⚠️ **Do not deploy until this SQL has been executed in production.**

## Postmortem (if it exists)
<if `99-postmortem.md` exists: 3-5 bullet executive summary + link to the artifact in the repo or wiki. The executive summary goes here because it is relevant to non-technical stakeholders; the detail is read separately.>

---

<details>
<summary>Technical details for reviewers</summary>

- **Root cause** (from `03-investigation.md` §"Root cause identified"): <one line>.
- **Fix files**: <from `04-fix.md` "Changes by file">.
- **Regression test**: `tests/...` (fails before the fix, passes after).
- **Areas with similar risk** (noted, not fixed here): <from `04-fix.md`>.

</details>
```

Use the sections from `git.request_sections` in FLOW.md if defined; otherwise the template above works as a free-form description.

Rules:
- **The bug reviewer is often a PM or support** in addition to the on-call developer. The description must let them validate that the reported symptom is actually resolved, without looking at code.
- **"What has NOT been touched" is especially important in fixes** — it avoids scope expansion and makes clear the fix is minimal.
- **The `## Pre-deploy` section does NOT go inside `<details>`**: it is a deployment gate and must be visible. Only applies if `git.predeploy_gate` is active and the fix touches DB; otherwise omit it.
- **Postmortem at the top**: if it exists, its summary goes in the main description, not in `<details>`. Postmortems often contain information of value to the business.

### Collect the pre-deploy SQL (only if `git.predeploy_gate` active)
Determine whether the fix modifies the database (migrations, mappings/schema, or changes recorded in the artifacts). If `quality.db_diff` is defined in `FLOW.md`, run it to see the pending schema SQL. Collect **all** statements to run manually before deploying in a **single block** — the same one that goes in the `## Pre-deploy` section and in the §3.2 thread. One single block / one single thread even if there are multiple statements.

## 2. Show to user and wait for confirmation (REQUIRED)

**Never skip this step.** The user needs to see and approve what will be published before anything is created.

Print to the user in this exact format:

```
─── Preview of {request_term} (fix) ────────────────────────────────────────────
Title: <full title, including [patch]>
Assigned to: <git.assignee from FLOW.md; empty = unassigned>
Squash: <git.squash from FLOW.md>
Target branch: <git.default_base>
Issue link: <keyword that will appear in the body, e.g. "Closes #123" / "none — Jira links by title prefix">
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered exactly as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there is pre-deploy SQL, ask the user to **explicitly confirm that the block is complete and correct** — it is what will gate the deployment and what will be executed in production.

Then ask with `AskUserQuestion` (header: "Create {request_term}"):

- **Create {request_term} with this content**: confirms → invoke §3.
- **Edit before creating**: the user indicates what to change; adjust and return to §2.
- **Cancel**: stop without creating anything. Do not touch `meta.json`.

Do not invoke `commit-push-pr` or push until explicit confirmation.

## 3. Commit, push, and MR/PR creation

### 3.0 Anti-deployment lock (before any push)

Same as `/flow:feat:ship` §4.0: `git rev-parse --abbrev-ref HEAD` must not be the main base (master/main), and `@{u}` must not point to `git.default_base`. If the upstream points to the base, `git branch --unset-upstream` and `git push -u origin HEAD`. In train mode the MR/PR points to the parent branch.

### 3.1 Create MR/PR

Only here — with the content approved in §2 — invoke `Skill commit-commands:commit-push-pr` passing it **the final title and description**. The skill must not re-ask for the content; if it does, answer with what was confirmed. If it pushes, it must use `git push -u origin HEAD`, never to the main base.

Assign to `git.assignee` from FLOW.md (if empty, unassigned). Enable squash according to `git.squash`.

**Record the URL the moment it exists**: write it into `meta.json` (the `mrs` entry if there is one) and refresh `panel.json` (per the Reporting preamble) right here, before §3.2 and before anything else can fail. The link is the thing the user most often has to come and ask you for, and until it is in those two files it exists only in this turn's scrollback.

### 3.2 Pre-deploy thread (deployment gate)
**Only if `git.predeploy_gate` is active and the fix has pre-deploy SQL** (§1). After creating the MR/PR, open **a single resolvable/blocking thread** with all the consolidated SQL, using the host from `git.host`/`git.cli` (GitLab: `glab api ".../merge_requests/<iid>/discussions"`; GitHub: review conversation with required resolution). Body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve only after running it in production".

With a "all threads resolved before merge" policy, the MR/PR cannot be merged or deployed until the SQL is executed and the thread is resolved. **One single thread even if there are multiple statements.** Notify the user that it is intentionally left open.

## 4. Close

- Update `meta.json`: `phase = "done"`, add `ship` to `phases_done`. Refresh `panel.json` from it: say in plain words that the fix is shipped (`ok`) and drop the `Waiting on you:` line — a finished work whose panel still reads "fixing" is the one misreading that costs the user a whole morning of looking in the wrong place.
- **Tracker: move to done.** When `phase` reaches `done` and `tracker.tool` is not `none`/empty, `tracker.done_cmd` is set, and `meta.json.ticket` is a **real tracker id**: run `tracker.done_cmd` substituting `{TICKET}` = `meta.json.ticket`. Same contract as `/flow:bug:start §4.5`: **best-effort, idempotent, gated** (ask once in `autonomy.mode: manual`; automatic in `guided`/`auto`); failure or already-done ticket → warn and continue, never block. **Leave `tracker.done_cmd` empty on GitHub/GitLab** — `Closes #N` already auto-closes on merge; this is for Jira/Linear-style trackers.
- Summarize: ticket, MR/PR URL, regression test added.
- **Cross-repo reminder**: if `meta.json.related_repos` has any entry not `done`, call it out now — for each: *"you've shipped the `<this-repo>` part; `<repo>` still needs: `<scope>` → go there and run `/flow:bug:start <TICKET>` (or `/flow:feat:start`)"*. flow does not touch the other repo; it only reminds, and this is not a hard gate.
- **Cross-repo contract handoff**: for each such entry with `contract_handoff: "pending"` — the fix changed a surface that sibling consumes — hand the new shape over the same way as `/flow:feat:ship` §6.3 (publish the **literal** shape to the tracker ticket, mandatory preview in every autonomy mode, then record `published → <location>`; fallback to a versioned file when there is no tracker). A bug flow has no §"External contracts" to copy from, so take the literal from the fix itself: the actual key, code, route or event the code now emits — read it off the code, do not describe it from memory. A silently changed contract is worse than a new one: the sibling has working code built on the old shape and no reason to suspect it moved.
- Ask whether to archive `.claude/work/<TICKET>/` to `.claude/work/_archive/`.
- If `meta.json.worktree` is not null, offer to remove the worktree once the MR/PR is merged: `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Not before merge, not without confirmation.
