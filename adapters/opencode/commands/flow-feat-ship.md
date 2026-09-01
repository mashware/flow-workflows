---
description: Commit, push, MR/PR, and offer to save domain knowledge
---

# `/flow-feat-ship`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as indicated in each step. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

Close the feature: commit, push, MR/PR (assigned per `git.assignee`, squash per `git.squash`, sections per `git.request_sections`) and optional offer to consolidate knowledge.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`; for `size` other than `XS`, also require `validate`. **In a multi-MR/PR work** (`meta.json.mrs` has >1 entry) check the **current `in_progress` MR/PR's** own `phases_done` (its `mrs[]` entry), NOT the work-level list — a previous MR/PR's `review`/`validate` does **not** satisfy this gate. This is the guard that stops a train MR/PR from shipping unreviewed just because an earlier sibling was reviewed; the work-level list accumulates and would otherwise pass every later MR/PR for free.
- If not met, refuse and send the user to the missing step (for a multi-MR/PR work, the missing step is `/flow-feat-review` or `/flow-feat-validate` **for this MR/PR**).
- **The review has to be about the tree you are about to push.** `phases_done` says a review happened; it cannot say what it looked at, so alone it passes a review of code that has since changed — and the commits after it get pushed having been read by nobody. Compare `meta.json.reviewed_sha` and `validated_sha` (this MR/PR's `mrs[]` entry in a multi-MR/PR work) with `git rev-parse HEAD`. **Equal** → continue. **Absent** (a work from before the shas were recorded) → one line saying so, continue; absence is not a mismatch. **Different** → read the delta (`git log --oneline <sha>..HEAD`, `git diff --stat <sha>..HEAD`) and judge it by **what it touches**, never by size: only test files (`tests/`, `test/`, `spec/`, `__tests__/`, `*_test.*`, `*Test.*`, `*.test.*`, `*.spec.*`) or this work's folder under `.claude/work/` → append both shas and the file list to `06-review.md` and continue **without asking** (a test written by `validate` after the review is the normal order here, and stopping on it makes this gate noise); **anything else** → stop and ask in **every** `autonomy.mode`, no exceptions: *re-review the delta* (`/flow-feat-review` over `<sha>..HEAD`, the recommended default) · *ship as it stands*, recording in `06-review.md` the two shas and that the user accepted them unreviewed. Never resolve this one silently — `guided`/`auto` are the modes where nobody is watching.
- Check that no TODO or FIXME added in this branch are blocking (`git diff --unified=0 <git.default_base>...HEAD | grep -E '^\+.*(TODO|FIXME)'`). If any, list them and ask whether to continue.

## 2. Draft title and description (without sending anything yet)

**Important**: in this step **nothing** is pushed or created yet. Only draft the MR/PR content to show the user in §3.

### Title

Format: `<TICKET> <what it does for the user, in behavioural language> [patch|minor|major]`.

**Good**: `<TICKET> List tracking opens via API [minor]`
**Bad**: `<TICKET> Add GET /orders/{id}/items endpoint with cursor pagination [minor]`

If `git.squash` is `true`, the squash uses the MR/PR title as the final commit message, so the commit message and title must match.

**Referencing other MRs/PRs of the plan in the body**: never write `#<n>` (the plan order from `meta.json.mrs`). GitHub/GitLab auto-resolve `#N` to whatever real issue/PR carries that number and append its state (e.g. `#5 (closed)`), linking the wrong thing. Reference an already-created MR/PR by its **URL** (`meta.json.mrs[].url`; the platform renders its title + real id) and a not-yet-created one by its **title** in quotes. This does not apply to the `Closes #<N>` issue-link line, where `<N>` is the real issue id.

### Description

**Build the description from the `Brief MR/PR #N` in `05-implementation.md`**, not from the technical design. The brief is already written in business language — that is the right material. If `05-implementation.md` has no brief (older work), draft one now based on what was actually built.

If `git.request_sections` in `FLOW.md` is defined, structure the description with those sections in the indicated order. If empty, use the default template:

```markdown
## What it's for
<2-3 bullets: what problem it solves / what need it covers. Why this MR/PR matters. Business language, NOT technical.>

## What changes for the user / system
<3-5 bullets from the "After this MR/PR..." section of the Brief. What a reviewer without technical context can understand.>

## What it does NOT include
<bullets from the "This MR/PR does NOT include..." section of the Brief. Important so the reviewer knows what to leave out of scope.>

## Steps to test it
<from `07-validation.md` (flow reproduction) and `01-context.md` (acceptance criteria). Numbered, actionable: "1. Log in as X, 2. Go to Y, 3. Verify Z".>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the branch touches the database)
SQL to run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/non-automatic data migrations — all together>
```
⚠️ **Do not deploy until this SQL has been run in production.**

## MR/PR in multi-delivery plan (only if applicable)
<if `meta.json.mrs` has >1 entry: state which one this is (e.g. "MR/PR 2 of 4 in the delivery plan"), then list already-created previous ones by their **URL** and still-pending ones by their **title** in quotes. **Never use `#<n>`** — see the reference rule above. Example: "MR/PR 2 of 4. Previous: <url-of-first-MR>. Pending: «<title of the third>», «<title of the fourth>» (not opened yet).">

---

<details>
<summary>Technical details for reviewers</summary>

- **Modules/layers touched**: <from `05-implementation.md`>
- **Migrations**: <yes/no, online/offline>
- **New domain events**: <list or "none">
- **New / modified endpoints**: <brief list>
- **Relevant design decisions** (see `03-design.md` for full detail): <2-3 key points from the ADR-light>

</details>
```

Rules:
- **The technical block goes in a collapsed `<details>`** — the reviewer opens it if they want, it does not clutter the main view.
- **The `## Pre-deploy` section does NOT go in `<details>`**: it is a deployment brake and must be visible. Only include it if `git.predeploy_gate` is active and the branch touches the DB; otherwise omit it.
- **Do not copy bullets from `03-design.md` literally** into the main body. The design talks about layers, repositories, value objects — the MR/PR describes the behaviour users notice.
- **If the brief's description contradicts what you see in the diff**, the diff wins (and warn the user).

### Collect the pre-deploy SQL (only if `git.predeploy_gate` is active)
Determine whether the branch modifies the database (migration changes, schema/mapping changes, or changes recorded in `03-design.md`/`05-implementation.md`). If `quality.db_diff` is defined in `FLOW.md`, run it to see the pending schema SQL. Collect **all** statements that need to be run manually on the server before deploying and consolidate them into **a single block** — the same one that goes in the `## Pre-deploy` section and in the §4.2 thread. Even if there are multiple changes, it is **one block / one thread**.

## 3. Show the user and wait for confirmation (MANDATORY)

**Never skip this step, not even when the content seems obvious.** The user must see and approve what will be published before anything is created.

Print to the user in this exact format:

```
─── Preview of <git.request_term> ─────────────────────────────────────
Title: <full title, including [patch|minor|major]>
Assigned to: <git.assignee from FLOW.md; if empty: "unassigned">
Squash on merge: <git.squash from FLOW.md>
Target branch: <git.default_base from FLOW.md>
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered exactly as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there is pre-deploy SQL, ask the user to **explicitly confirm the block is complete and correct** — it is what will gate the deployment and what will be run in production.

Then ask the user (heading: "Create <git.request_term>"):

- **Create with this content**: user confirms → invoke §4.
- **Edit before creating**: user specifies what to change (title, a section, both); adjust and return to §3 with the new preview.
- **Cancel**: exit without creating anything. Do not touch `meta.json`. The user can return to `/flow-feat-ship` later.

Do not push or invoke any creation command until the user has responded "Create with this content".

## 4. Commit, push, and MR/PR creation

### 4.0 Anti-deployment lock (before any push)
Verify, and **block** if anything fails:
```bash
git rev-parse --abbrev-ref HEAD                          # must NOT be master/main
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null   # must NOT be the base branch
```
- If HEAD is the main branch (master/main): stop and warn. Do not push from the main branch.
- If the upstream is `<git.default_base>` (branch incorrectly created without `--no-track`): **do not push by resolving the upstream**. Fix with `git branch --unset-upstream` and use `git push -u origin HEAD`, which sets the upstream to the branch's own remote.
- In train mode (`stacked_on` ≠ null): the MR/PR must target that parent branch, not the main base.

### 4.1 Create MR/PR
Only here — with the content approved by the user in §3 — commit, push, and create the MR/PR using the `git.cli` CLI from `FLOW.md`. If a commit+push+MR skill is available in the tool, use it passing the **final title and description**; if not available, do it manually in separate steps. The push must be `git push -u origin HEAD` (own branch), never to the base branch.

If `git.assignee` is not empty in `FLOW.md`, assign to that user. If `git.squash` is `true`, mark squash-before-merge.

**Record the URL the moment it exists**: write it into this MR/PR's `meta.json.mrs` entry and refresh `panel.json` (per the Reporting preamble) right here, before §4.2 and before anything else can fail. The link is the thing the user most often has to come and ask you for, and until it is in those two files it exists only in this turn's scrollback.

### 4.2 Pre-deploy thread (deployment brake)
**Only if `git.predeploy_gate` is active and the branch has pre-deploy SQL** (§2). After creating the MR/PR, open **a single resolvable/blocking thread** with **all** the consolidated SQL, using `git.host`/`git.cli`:
- **GitLab**: `glab api "projects/<repo-url-encoded>/merge_requests/<iid>/discussions" -f body="..."` (creates a resolvable thread).
- **GitHub**: a review conversation that requires resolution before merging ("require conversation resolution" policy).

Thread body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve this thread only after having run it in production."

This is the brake: with the repo's "all threads resolved before merge" policy, the MR/PR cannot be merged or deployed until the SQL is run and the thread **resolved**. **One thread even if there are multiple statements.** Warn the user that it is intentionally left open.

## 5. Domain knowledge (offer)

If `domain_memory.enabled` is `true` in `FLOW.md`:

**Only if there is something non-obvious worth saving** (default-silence rule):

1. **Read the staging accumulated during this branch**: call `mcp__domain-memory__read_staging`. This shows what `/flow-feat-design` (and possibly other phases) already staged. That is the primary material to consolidate.
2. **Review the artifacts** `03-design.md`, `05-implementation.md`, and `06-review.md` for "why" findings (domain decisions, legal constraints, integrations, business motivations) that **were not staged at the time**. The "what" (code, routes) is NOT saved — that lives in the repo.
3. **Combine staging + new findings** into a short list. If the list is empty or contains only obvious things derivable from the code, do not insist.
4. If there are 1+ relevant findings, ask the user whether to consolidate them. If yes, invoke `/flow-save-knowledge` (which already does `read_staging` internally and orchestrates the save; you provide the context of what to consolidate). If no, do not insist.

If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 6. Close

Update `meta.json` based on the scenario:

**A) The MR/PR was created (and merged, if the flow got that far)** (normal case):
- If there are **no** `mrs` or only one: add `ship` to `phases_done` and update `updated_at`. `phase = "done"` **only if the user confirms it was actually merged** — the same question as the multi-delivery case below, asked once, because right after §3 the MR/PR is open and the normal answer is no. Not merged → leave `phase = "ship"`: `/flow-work-green` and `/flow-work-respond` operate on the open MR/PR and `/flow-work-clean` only sweeps what merged, so a work parked at `done` with its MR/PR open sends all three at the wrong target.
- If it is a multi-delivery build: record the current MR/PR's `url` in its `meta.json.mrs` entry. Set its `status` to `merged` **only if the user confirms it was actually merged**; otherwise keep it `in_progress` — **the train does not require the current MR/PR to be merged to proceed**. If there are `pending` entries remaining, leave `phase = "build"` (the cycle repeats for the next one). If all are `merged`/`closed`/`superseded`, `phase = "done"`.

**B) MR/PR closed without merging** (rejected or discarded by reviewers):
- Mark the current entry as `closed` with a `note` explaining the reason.
- Ask the user: retry with another MR/PR (return to `/flow-feat-build` with a different approach), or consider the feature unviable (`/flow-work-abandon`)? Do not make the decision alone.

**C) The plan changed and this MR/PR is dropped**:
- If you are here because the plan was revised: mark the entry as `superseded` with a `note` pointing to the new MR/PR.

In every scenario, refresh `panel.json` from the updated `meta.json`. A shipped-but-open MR/PR is a `wait` line carrying its `link`; it becomes `done` only when the merge is confirmed. When this ship sets `phase = "done"`, say so in the panel in plain words (`mark: "info"` with `style: "ok"`: nothing left here) and drop the `Decision` line — a finished work whose panel still reads "building" is the one misreading that costs the user a whole morning of looking in the wrong place.

**Tracker: move to done.** **Only when this ship sets `phase = "done"`** (single MR/PR merged, or the last of a train — never on an intermediate train MR/PR), and only if `tracker.tool` is not `none`/empty, `tracker.done_cmd` is set, and `meta.json.ticket` is a **real tracker id**. `phase = "done"` already implies the completing MR/PR was confirmed merged, so this fires at genuine completion — not at the archive prompt below (which also runs for works that are done but could equally be shelved). Run `tracker.done_cmd` substituting `{TICKET}` = `meta.json.ticket`. Same contract as `/flow-feat-start §6.5`: **best-effort, idempotent, gated** (in `autonomy.mode: manual` ask once before running; in `guided`/`auto` run automatically). Failure or already-done ticket → warn in one line and continue, never block. **On GitHub/GitLab leave `tracker.done_cmd` empty** — the `Closes #N` in the MR/PR body (§2) already auto-closes the issue on merge, so this step is for trackers that do not transition from git (Jira, Linear).

Summarize for the user: ticket, MR/PR URL, changed files, added tests. In multi-delivery, also indicate remaining entries per `meta.json.mrs`.

**Cross-repo reminder**: if `meta.json.related_repos` has any entry not `done`, call it out explicitly now — this is the moment the other side is usually forgotten. For each such entry: *"you've shipped the `<this-repo>` part; `<repo>` still needs: `<scope>` → go there and run `/flow-feat-start <TICKET>` (or `/flow-bug-start`)"*. flow does not touch or scan the other repo; it only reminds, and this is not a hard gate.

**Cross-repo contract handoff**: pointing at the sibling is not enough when it has to build against a shape decided here. Applies to each `related_repos` entry not `done` with `contract_handoff: "pending"`, when `03-design.md` §"External contracts" is not "none". Why it exists: `03-design.md` lives in git-ignored `.claude/work/`, so the literal contracts — the most expensive artifact of the flow — do not survive the session and never reach the other repo. `scope` does survive, and it is one line of prose. The cheap half crosses and the sibling reinvents routes, payload keys and error codes that were already decided.

1. **Select what crosses.** Only the contracts *that sibling consumes* — the ones whose "Known consumer" names it. If that field is blank, ask the user which ones rather than publishing everything. Copy them **verbatim** from `03-design.md` (same copy-don't-paraphrase rule as `/flow-feat-build` §2.0bis: a paraphrased contract is a new contract). Acceptance criteria, ADRs and "Internal behavioral contracts" do **not** cross — they are this repo's *how*, and in the sibling's ticket they bury the part that matters.
2. **Where.** A comment on the tracker ticket, the anchor flow already assumes both sides share (§3.5 sends the sibling to the *same* ticket) and which the sibling's `start` reads: the feature and bug `start` commands read the comment thread, not only the description, so a block published here is picked up there. Requires `tracker.tool` not `none`/empty and a real `meta.json.ticket`. **Fallback** without a tracker: write the block to a **versioned** file in this repo (`docs/contracts/<TICKET>.md` or wherever `conventions` puts docs — never under `.claude/work/`) and name that path in the reminder.
3. **Preview, always.** Publishing to the tracker is outward-facing and the whole team reads it: show the exact comment text and ask the user to confirm (publish / edit / skip) **in every `autonomy.mode`, no exceptions** — same rule as the mandatory MR/PR preview. Never publish unreviewed prose into a shared tracker.
4. **Record it.** On publish, set that entry's `contract_handoff` to `published → <comment url or file path>`. On skip, leave it `pending` — the reminder fires again next ship, which is intended, not a nag. A failure to post → warn in one line, leave `pending`, never block the ship.

Still "notes and reminds": the contract goes to the tracker or to this repo, never into the sibling's working tree. Not a hard gate — a skipped handoff must never stop a merged MR/PR from closing out.

Ask whether to keep `.claude/work/<TICKET>/` or archive it (move to `.claude/work/_archive/`) — only if `phase = "done"`.

If `phase = "done"` and `meta.json.worktree` is not null, the branch's worktree is no longer needed once the MR/PR is merged: offer to remove it (from the main checkout) with `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Do not remove it if the MR/PR is not yet merged, or without confirmation.

On a **train MR/PR** neither offer fires, by design: `phase` is not `done` yet, and the branch is the base of the next one. That's also why the residue piles up — say so in one line when shipping an intermediate MR/PR whose predecessor has since merged, and point at `/flow-work-clean`, which sweeps the whole backlog at once instead of one prompt per ship. Mention it once per work, not per MR/PR.
