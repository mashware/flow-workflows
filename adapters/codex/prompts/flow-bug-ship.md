# `/flow-bug-ship`

Close the bug workflow: commit, push, MR/PR. Uses the same mechanics as `/flow-feat-ship` with two differences:

1. If `99-postmortem.md` exists, **include the link or executive summary** in the MR/PR description.
2. The offer to save knowledge was already made in `/flow-bug-postmortem` — it's not asked again here.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

**Product altitude — the effect, not the implementation.** The body is written in the language of what changed for whoever uses this software: what the product does now that it did not, what was breaking and for whom, what is still not covered. Not what you built. Code identifiers — classes, files, methods, error codes — earn a line only when the user has to *decide* about one, when they asked something technical, or when they named it first; the mechanics belong to the phase artifact, which is where they stay useful. Ten lines about `AttachmentUploader` say nothing to someone who has not read the diff; "attachments over 25 MB no longer break the send — they upload separately and the mail carries a link" says all of it. When an identifier is genuinely unavoidable, the Zero-context rule below applies to it.

**Short lines, not prose.** One or two lines of headline, then two to five bullets, one idea each. No chained subordinate clauses, no "for context", no restating what an earlier stop already said. The ~10-line limit above is a ceiling, not a target: ten lines of prose obey it and are still a wall of text. This governs the report you write unprompted — when the user asks a technical question, answer it in full.

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

- Load `meta.json`. Require `review` in `phases_done` (and `validate` if `size` ≥ S, and `postmortem` if `size` is M or L — the same sizes `/flow-bug-review` routes to postmortem, so what it suggests and what this requires are one rule).
- If not met, refuse and send to the missing step.
- **The review has to be about the tree you are about to push.** Compare `meta.json.reviewed_sha` and `validated_sha` with `git rev-parse HEAD`. **Equal** → continue. **Absent** → one line, continue. **Different** → read the delta (`git log --oneline <sha>..HEAD`) and judge it by **what it touches**: only test files or this work's folder under `.claude/work/` → note both shas in `06-review.md` and continue; **anything else** → stop and ask in **every** mode: *re-review the delta* (`/flow-bug-review` over `<sha>..HEAD`) · *ship as it stands*, recording that the user accepted them unreviewed. A fix whose last commits nobody read is the shape of the second incident.

## 1. Draft title and description (without sending anything yet)

**Important**: in this step **no** commit or push is invoked yet. Only draft the content to show the user in §2.

### Title

Format: `{PREFIX}{TICKET} Fix <observable symptom, in plain language> [patch]`.

**Good**: `{PREFIX}15310 Fix opens counted twice on retry [patch]`
**Bad**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Fixes are `[patch]` unless they break a contract.

### Description

**Build the description from the Brief in `04-fix.md`**, not from the previous technical artifacts. If `04-fix.md` has no Brief (old fix), draft one now from the reported symptom.

Template (in this order):

```markdown
## What stops happening after this fix
<what the user was observing that they will no longer see. Symptom language, not code language.>

## What changes (behavior)
<1-2 lines in plain language. NOT file names.>

## What has NOT been touched
<bullets from the "What is NOT touched" of the Brief. Important so the reviewer knows the fix is minimal.>

## Steps to reproduce and test
<from `05-validation.md`:
1. Reproduction of the failure before the fix (no longer applies, but documents the case).
2. How to verify the behavior is correct after the fix.
3. Regression test added and where it is.>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the fix touches the database)
SQL that must be run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/data corrections — all together>
```
⚠️ **Do not deploy until this SQL has been run in production.**

## Postmortem (if it exists)
<if `99-postmortem.md` exists: executive summary of 3-5 bullets + link to the artifact in the repo or wiki.>

---

<details>
<summary>Technical details for reviewers</summary>

- **Root cause** (from `03-investigation.md` §"Root cause identified"): <one line>.
- **Fix files**: <from `04-fix.md` "Changes per file">.
- **Regression test**: `tests/...` (fails before the fix, passes after).
- **Areas with similar risk** (noted, not fixed here): <from `04-fix.md`>.

</details>
```

Use the sections from `git.request_sections` in FLOW.md if defined; if not, the template above works.

Rules:
- **The reviewer of the bug is often a PM or support person** in addition to the developer. The description must help them validate that the reported symptom is actually resolved.
- **"What has NOT been touched" is especially important in fixes** — it makes clear the fix is minimal.
- **The `## Pre-deploy` section does NOT go in `<details>`**.
- **Postmortem at the top**: if it exists, its summary goes in the main description, not in `<details>`.

### Collect the pre-deploy SQL (only if `git.predeploy_gate` is active)
If `quality.db_diff` is defined in `FLOW.md`, run it. Collect **all** statements in **a single block**.

## 2. Show the user and wait for confirmation (MANDATORY)

**This step is never skipped.**

Print to the user in this exact format:

```
─── Preview of the {request_term} (fix) ────────────────────────────────────
Title: <full title, including [patch]>
Assigned to: <git.assignee from FLOW.md; empty = unassigned>
Squash: <git.squash from FLOW.md>
Target branch: <git.default_base>
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there's pre-deploy SQL, ask the user to **expressly confirm the block is complete and correct**.

Then ask the user (header: "Create {request_term}"):

- **Create {request_term} with this content**: confirms → invoke §3.
- **Edit before creating**: user specifies what to change; adjust and return to §2.
- **Cancel**: stop without creating anything.

Do not invoke push until explicit confirmation.

## 3. Commit, push, and create the MR/PR

### 3.0 Anti-deployment lock (before any push)

Same as `/flow-feat-ship` §4.0: HEAD must not be the main branch (master/main), and the upstream must not point to `git.default_base`. If the upstream points to the base, `git branch --unset-upstream` and `git push -u origin HEAD`. In train mode the MR/PR targets the parent branch.

### 3.1 Create MR/PR

Only here — with the content approved in §2 — commit with `git commit`, push with `git push -u origin HEAD` (branch's own remote, never to the main base), and create the MR/PR with the `git.cli` CLI from `FLOW.md` using the finalized title and description.

Assign to `git.assignee` from FLOW.md (if empty, unassigned). Enable squash per `git.squash`.

**Record the URL the moment it exists**: write it into `meta.json` (the `mrs` entry if there is one) and refresh `panel.json` (per the Reporting preamble) right here, before the pre-deploy thread step and before anything else can fail. The link is the thing the user most often has to come and ask you for, and until it is in those two files it exists only in this turn's scrollback.

### 3.2 Pre-deploy thread (deployment brake)
**Only if `git.predeploy_gate` is active and the fix has pre-deploy SQL** (§1). After creating the MR/PR, open **a single resolvable/blocking thread** with all the consolidated SQL. Body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve only after running it in production". **One thread even if there are multiple statements.**

## 4. Close

- Update `meta.json`: add `ship` to `phases_done`, update `updated_at`. **`phase` becomes `done` only once the MR/PR is confirmed merged** — creating it is not finishing it. Right after §3.1 the MR/PR is open, so ask the user once whether it has already been merged: **no** (the normal answer) → leave `phase = "ship"`; **yes** → `phase = "done"`. Shipped and merged are different states and three commands read the difference: `/flow-work-green` and `/flow-work-respond` work on the open MR/PR, and `/flow-work-clean` only sweeps what merged.
- Refresh `panel.json` from it: while the MR/PR is open its line is `wait` with the `link` — shipped, waiting on a reviewer, the user's next move is elsewhere. Once merged it is `done`, and only then does the panel say in plain words that there is nothing left here (`mark: "info"`, `style: "ok"`); drop the `Decision` line either way. A finished work whose panel still reads "fixing" is the one misreading that costs the user a whole morning of looking in the wrong place — and so is a work the panel calls finished while its MR/PR waits for review.
- **Tracker: move to done.** **Only when this ship set `phase = "done"`** (the MR/PR was confirmed merged just above) and `tracker.tool` is not `none`/empty, `tracker.done_cmd` is set, and `meta.json.ticket` is a **real tracker id**: run `tracker.done_cmd` substituting `{TICKET}` = `meta.json.ticket`. Never on an open MR/PR — a ticket moved to Done while the fix still awaits review tells the whole team the work landed, and it is the tracker, not the flow, that they read. If the answer above was "not merged", skip this silently; the transition belongs to whoever confirms the merge (`/flow-work-clean` reports the branch as merged, and re-running this close is legitimate). Same contract as `/flow-bug-start §4.5`: **best-effort, idempotent, gated** (ask once in `autonomy.mode: manual`; automatic in `guided`/`auto`); failure or already-done ticket → warn and continue, never block. **Leave `tracker.done_cmd` empty on GitHub/GitLab** — `Closes #N` already auto-closes on merge; this is for Jira/Linear-style trackers.
- Summarize: ticket, MR/PR URL, regression test added.
- **Cross-repo reminder**: if `meta.json.related_repos` has any entry not `done`, call it out now — for each: *"you've shipped the `<this-repo>` part; `<repo>` still needs: `<scope>` → go there and run `/flow-bug-start <TICKET>` (or `/flow-feat-start`)"*. flow does not touch the other repo; it only reminds, and this is not a hard gate.
- **Cross-repo contract handoff**: for each such entry with `contract_handoff: "pending"` — the fix changed a surface that sibling consumes — hand the new shape over as in `/flow-feat-ship` §6 (publish the **literal** shape to the tracker ticket, mandatory preview in every autonomy mode, then record `published → <location>`; fallback to a versioned file when there's no tracker). A bug flow has no §"External contracts" to copy from, so take the literal from the fix itself: the actual key, code, route or event the code now emits — read it off the code, don't describe it from memory. A silently changed contract is worse than a new one: the sibling has working code built on the old shape and no reason to suspect it moved.
- Ask whether they want to archive `.claude/work/<TICKET>/` to `.claude/work/_archive/`.
- If `meta.json.worktree` is not null, offer to remove the worktree once the MR/PR is merged: `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Not before merge, not without confirmation.
