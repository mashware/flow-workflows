# `/flow-feat-ship`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

Closes the feature: commit, push, MR/PR (assigned per `git.assignee`, squashed per `git.squash`, sections per `git.request_sections`) and optional offer to consolidate knowledge.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`; for `size` other than `XS`, also require `validate`. **In a multi-MR/PR work** (`meta.json.mrs` has >1 entry) check the **current `in_progress` MR/PR's** own `phases_done` (its `mrs[]` entry), NOT the work-level list — a previous MR/PR's `review`/`validate` does **not** satisfy this gate. This is the guard that stops a train MR/PR from shipping unreviewed just because an earlier sibling was reviewed; the work-level list accumulates and would otherwise pass every later MR/PR for free.
- If not met, refuse and send the user to the missing step (for a multi-MR/PR work, the missing step is `/flow-feat-review` or `/flow-feat-validate` **for this MR/PR**).
- Check there are no blocking TODO or FIXME added on this branch (`git diff --unified=0 <git.default_base>...HEAD | grep -E '^\+.*(TODO|FIXME)'`). If any exist, list them and ask whether to continue.

## 2. Draft title and description (without sending anything yet)

**Important**: in this step **nothing** is pushed or created yet. Only draft the MR/PR content to show the user in §3.

### Title

Format: `<TICKET> <what it does for the user, in behavior language> [patch|minor|major]`.

**Good**: `<TICKET> List opens for a tracking by API [minor]`
**Bad**: `<TICKET> Add GET /orders/{id}/items endpoint with cursor pagination [minor]`

If `git.squash` is `true`, the squash leaves the MR/PR title as the final commit message, so the commit message and title are identical.

**Referencing other MRs/PRs of the plan in the body**: never write `#<n>` (the plan order from `meta.json.mrs`). GitHub/GitLab auto-resolve `#N` to whatever real issue/PR carries that number and append its state (e.g. `#5 (closed)`), linking the wrong thing. Reference an already-created MR/PR by its **URL** (`meta.json.mrs[].url`; the platform renders its title + real id) and a not-yet-created one by its **title** in quotes. This does not apply to the `Closes #<N>` issue-link line, where `<N>` is the real issue id.

### Description

**Build the description from the `Brief MR/PR #N` in `05-implementation.md`**, not from the technical design. If `05-implementation.md` has no Brief (old work), draft one now based on what was actually built.

If `git.request_sections` in `FLOW.md` is defined, structure the description with those sections in the indicated order. If empty, use the default template:

```markdown
## What it's for
<2-3 bullets: what problem it solves / what need it covers. Why this MR/PR matters. Business language, NOT technical.>

## What changes for the user / system
<3-5 bullets from the "After this MR/PR..." of the Brief.>

## What is NOT included
<bullets from the "This MR/PR does NOT include..." of the Brief.>

## Steps to test it
<from `07-validation.md` and `01-context.md`. Numbered, actionable.>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the branch touches the database)
SQL that must be run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/non-automatic data migrations — all together>
```
⚠️ **Do not deploy until this SQL has been run in production.**

## MR/PR in a multi-delivery plan (only if applicable)
<if `meta.json.mrs` has >1 entry: state which one this is (e.g. "MR/PR 2 of 4 in the delivery plan"), then list already-created previous ones by their **URL** and still-pending ones by their **title** in quotes. **Never use `#<n>`** — see the reference rule above. Example: "MR/PR 2 of 4. Previous: <url-of-first-MR>. Pending: «<title of the third>», «<title of the fourth>» (not opened yet).">

---

<details>
<summary>Technical details for reviewers</summary>

- **Touched modules/layers**: <from `05-implementation.md`>
- **Migrations**: <yes/no, live/non-live>
- **New domain events**: <list or "none">
- **New / modified endpoints**: <brief list>
- **Relevant design decisions** (see `03-design.md` for full detail): <2-3 key points from the ADR-light>

</details>
```

Rules:
- **The technical block goes in a collapsed `<details>`**.
- **The `## Pre-deploy` section does NOT go in `<details>`**: it's a deployment brake, it must be visible.
- **Don't copy bullets from `03-design.md` literally** into the main body.
- **If the brief description contradicts what you see in the diff**, the diff wins (and flag it to the user).

### Collect the pre-deploy SQL (only if `git.predeploy_gate` is active)
If `quality.db_diff` is defined in `FLOW.md`, run it to see the pending schema SQL. Collect **all** statements to run manually in **a single block**.

## 3. Show the user and wait for confirmation (MANDATORY)

**This step is never skipped, even when the content seems obvious.**

Print to the user in this exact format:

```
─── Preview of the <git.request_term> ─────────────────────────────────────
Title: <full title, including [patch|minor|major]>
Assigned to: <git.assignee from FLOW.md; if empty: "unassigned">
Squash on merge: <git.squash from FLOW.md>
Target branch: <git.default_base from FLOW.md>
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there's pre-deploy SQL, ask the user to **expressly confirm the block is complete and correct**.

Then ask the user (header: "Create <git.request_term>"):

- **Create with this content**: user confirms → invoke §4.
- **Edit before creating**: user specifies what to change; adjust and return to §3.
- **Cancel**: stop without creating anything.

Do not push or invoke any creation command until the user has responded "Create with this content".

## 4. Commit, push, and create the MR/PR

### 4.0 Anti-deployment lock (before any push)
```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
```
- If HEAD is the main branch (master/main): stop and warn.
- If the upstream is `<git.default_base>`: **do not push resolving upstream**. Fix with `git branch --unset-upstream` and use `git push -u origin HEAD`.
- In train mode (`stacked_on` ≠ null): the MR/PR must target that parent branch.

### 4.1 Create MR/PR
Only here — with the content approved by the user in §3 — commit and push with `git push -u origin HEAD` (branch's own remote, never to the base branch) and create the MR/PR with the `git.cli` CLI from `FLOW.md` using the finalized title and description.

If `git.assignee` is not empty in `FLOW.md`, assign to that user. If `git.squash` is `true`, mark squash-before-merge.

**Record the URL the moment it exists**: write it into this MR/PR's `meta.json.mrs` entry and refresh `panel.json` (per the Reporting preamble) right here, before §4.2 and before anything else can fail. The link is the thing the user most often has to come and ask you for, and until it is in those two files it exists only in this turn's scrollback.

### 4.2 Pre-deploy thread (deployment brake)
**Only if `git.predeploy_gate` is active and the branch has pre-deploy SQL** (§2). After creating the MR/PR, open **a single resolvable/blocking thread** with **all** the consolidated SQL:
- **GitLab**: `glab api "projects/<repo-url-encoded>/merge_requests/<iid>/discussions" -f body="..."`.
- **GitHub**: a review conversation that requires resolution before merging.

Thread body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve this thread only after running it in production." **One thread even if there are multiple statements.**

## 5. Domain knowledge (offer)

If `domain_memory.enabled` is `true` in `FLOW.md`:

**Only if there's something non-obvious worth saving** (silence by default):

1. Read the staging accumulated during the branch: call `mcp__domain-memory__read_staging`.
2. Review the `03-design.md`, `05-implementation.md`, and `06-review.md` artifacts for "why" findings that weren't staged.
3. Combine staging + new findings into a short list. If the list is empty or contains only obvious things, don't insist.
4. If there are 1+ relevant findings, ask the user whether they want to consolidate them. If yes, invoke the `/flow-save-knowledge` workflow. If no, don't insist.

If `domain_memory.enabled` is `false` or empty, skip without comment.

## 6. Close

Update `meta.json` based on the scenario:

**A) The MR/PR was merged successfully**:
- If there are **no** `mrs` or there was only 1: `phase = "done"`, add `ship` to `phases_done`, update `updated_at`.
- If multi-delivery build: mark the current MR/PR as `merged` (with final `url`) in `meta.json.mrs`. If there are still `pending` entries, leave `phase = "build"`. If all are `merged`/`closed`/`superseded`, `phase = "done"`.

**B) The MR/PR was closed without merging**: mark the current entry as `closed` with `note`. Ask the user whether to retry or abandon with `/flow-work-abandon`.

**C) The plan changed and this MR/PR is out of scope**: mark the entry as `superseded` with `note` pointing to the new MR/PR.

In every scenario, refresh `panel.json` from the updated `meta.json`. When this ship sets `phase = "done"`, say so in the panel in plain words (`ok`: nothing left here) and drop the `Waiting on you:` line — a finished work whose panel still reads "building" is the one misreading that costs the user a whole morning of looking in the wrong place.

**Tracker: move to done.** Only when this ship sets `phase = "done"` (single MR/PR merged, or the last of a train — never on an intermediate train MR/PR), and only if `tracker.tool` is not `none`/empty, `tracker.done_cmd` is set, and `meta.json.ticket` is a **real tracker id**. `phase = "done"` already implies the completing MR/PR was confirmed merged, so this fires at genuine completion — not at the archive prompt later in this section. Run `tracker.done_cmd` substituting `{TICKET}` = `meta.json.ticket`. Same contract as `/flow-feat-start §6.5`: **best-effort, idempotent, gated** (in `autonomy.mode: manual` ask once before running; in `guided`/`auto` run automatically); failure or already-done ticket → warn in one line and continue, never block. **On GitHub/GitLab leave `tracker.done_cmd` empty** — the `Closes #N` in the MR/PR body (§2) already auto-closes the issue on merge, so this step is for trackers that do not transition from git (Jira, Linear).

**Cross-repo reminder**: if `meta.json.related_repos` has any entry not `done`, call it out explicitly now — this is the moment the other side is usually forgotten. For each such entry: *"you've shipped the `<this-repo>` part; `<repo>` still needs: `<scope>` → go there and run `/flow-feat-start <TICKET>` (or `/flow-bug-start`)"*. flow does not touch or scan the other repo; it only reminds, and this is not a hard gate.

**Cross-repo contract handoff**: pointing at the sibling isn't enough when it has to build against a shape decided here. Applies to each `related_repos` entry not `done` with `contract_handoff: "pending"`, when `03-design.md` §"External contracts" isn't "none". Why it exists: `03-design.md` lives in git-ignored `.claude/work/`, so the literal contracts — the most expensive artifact of the flow — don't survive the session and never reach the other repo. `scope` does survive, and it's one line of prose. The cheap half crosses and the sibling reinvents routes, payload keys and error codes that were already decided.

1. **Select what crosses.** Only the contracts *that sibling consumes* — the ones whose "Known consumer" names it. If that field is blank, ask the user which ones rather than publishing everything. Copy them **verbatim** from `03-design.md` (same copy-don't-paraphrase rule as `/flow-feat-build` §2.0bis: a paraphrased contract is a new contract). Acceptance criteria, ADRs and "Internal behavioral contracts" do **not** cross — they're this repo's *how*, and in the sibling's ticket they bury the part that matters.
2. **Where.** A comment on the tracker ticket, the anchor flow already assumes both sides share (§3.5 sends the sibling to the *same* ticket) and which the sibling's `start` reads: the feature and bug `start` commands read the comment thread, not only the description, so a block published here is picked up there. Requires `tracker.tool` not `none`/empty and a real `meta.json.ticket`. **Fallback** without a tracker: write the block to a **versioned** file in this repo (`docs/contracts/<TICKET>.md` or wherever `conventions` puts docs — never under `.claude/work/`) and name that path in the reminder.
3. **Preview, always.** Publishing to the tracker is outward-facing and the whole team reads it: show the exact comment text and ask the user to confirm (publish / edit / skip) **in every `autonomy.mode`, no exceptions** — same rule as the mandatory MR/PR preview. Never publish unreviewed prose into a shared tracker.
4. **Record it.** On publish, set that entry's `contract_handoff` to `published → <comment url or file path>`. On skip, leave it `pending` — the reminder fires again next ship, which is intended, not a nag. A failure to post → warn in one line, leave `pending`, never block the ship.

Still "notes and reminds": the contract goes to the tracker or to this repo, never into the sibling's working tree. Not a hard gate — a skipped handoff must never stop a merged MR/PR from closing out.

Summarize for the user: ticket, MR/PR URL, changed files, tests added. Ask whether they want to keep the `.claude/work/<TICKET>/` folder or archive it — only if `phase = "done"`.

If `phase = "done"` and `meta.json.worktree` is not null, the branch's worktree is no longer needed once the MR/PR is merged: offer to remove it (from the main checkout) with `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Do not remove it before the MR/PR is merged, or without confirmation.

On a **train MR/PR** neither offer fires, by design: `phase` is not `done` yet, and the branch is the base of the next one. That's also why the residue piles up — say so in one line when shipping an intermediate MR/PR whose predecessor has since merged, and point at `/flow-work-clean`, which sweeps the whole backlog at once instead of one prompt per ship. Mention it once per work, not per MR/PR.
