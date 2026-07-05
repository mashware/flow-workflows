---
description: Commit, push, MR/PR, and offer to save domain knowledge
---

# `/feat:ship`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Closes the feature: commit, push, MR/PR (assigned per `git.assignee`, squash per `git.squash`, sections per `git.request_sections`) and an optional offer to consolidate knowledge.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. For `size` other than `XS`, also require `validate`.
- If not met, refuse and send the user to the missing step.
- Check that there are no TODO or FIXME items added on this branch that are blockers (`git diff --unified=0 <git.default_base>...HEAD | grep -E '^\+.*(TODO|FIXME)'`). If any, list them and ask whether to continue.

## 2. Draft title and description (without sending anything yet)

**Important**: in this step **do not** invoke any push command or create anything yet. Only draft the MR/PR content to show the user in §3.

### Title

Format: `<TICKET> <what it does for the user, in behavioral language> [patch|minor|major]`.

**Good**: `<TICKET> List opens for a tracked email via API [minor]`
**Bad**: `<TICKET> Add GET /orders/{id}/items endpoint with cursor pagination [minor]`

If `git.squash` is `true`, the squash leaves the MR/PR title as the final commit message, so commit message and title coincide.

The `<TICKET>` in the title is for humans and for trackers that link by convention (Jira, Linear). **On GitHub/GitLab a ticket in the title does NOT link the MR/PR to the issue** (it only cross-references in the timeline) — the formal link lives in the body, see below.

### Issue link (in the body — this is what fills the tracker's "Development"/linked panel)
The link must go in the **body**, and how depends on `tracker.tool`. Decide first whether **this** MR/PR is the one that *completes* the issue: it completes it when, after it, `meta.json.mrs` has **no** remaining `pending`/`in_progress` entries (or there is a single MR/PR). Otherwise it is an **intermediate** train MR/PR.

- **`gh` / `glab`**: add a link line at the top of the body.
  - Completing MR/PR → `Closes #<N>` (auto-links + auto-closes the issue on merge to the default branch).
  - Intermediate MR/PR → `Part of #<N>` (references without closing; keeps the issue open for the rest of the train).
  - `<N>` = the numeric issue id from `meta.json.ticket`.
  - **GitHub train caveat**: for a stacked MR/PR (target = parent branch, not the default branch) GitHub **ignores** `Closes`/`Part of` for panel/auto-close purposes — the Development-panel link comes from the **linked branch** created in `/feat:start §5.5`. Keep the `Part of #<N>` line anyway for human context, and rely on the branch link for the panel.
- **`acli` (Jira)**: **add nothing** — Jira's Git integration links via the issue key already present in the branch name and the title prefix.
- **`linear`**: add `Closes <TICKET>` (Linear id, e.g. `ENG-123`) on the completing MR/PR; nothing on intermediates.
- **`none` / empty**: nothing to link.

### Description

**Build the description from the `Brief MR/PR #N` in `05-implementation.md`**, not from the technical design. The brief is already written in business language — that is the right material. If `05-implementation.md` has no Brief (older work), draft one now based on what was actually built.

If `git.request_sections` in `FLOW.md` is defined, structure the description with those sections in the indicated order. If empty, use the default template:

```markdown
## Purpose
<2-3 bullets: what problem it solves / what need it covers. Why this MR/PR matters. Business language, NOT technical.>

## What changes for the user / system
<3-5 bullets taken from the "After this MR/PR..." in the Brief. What a reviewer without technical context can understand.>

## What is NOT included
<bullets taken from "This MR/PR does NOT include..." in the Brief. Important so the reviewer knows what to leave out of scope.>

## Steps to test it
<taken from `07-validation.md` (flow reproduction) and `01-context.md` (acceptance criteria). Numbered, actionable: "1. Log in as X, 2. Go to Y, 3. Verify Z".>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the branch touches the database)
SQL to run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/data migrations that are not automatic — all together>
```
⚠️ **Do not deploy until this SQL has been executed in production.**

## MR/PR in multi-delivery plan (only if applicable)
<if `meta.json.mrs` has >1 entry: "MR/PR 2/4 of the delivery plan — see #1 (link) and pending #3, #4". Include links to already-merged previous ones.>

---

<details>
<summary>Technical details for reviewers</summary>

- **Modules/layers touched**: <from `05-implementation.md`>
- **Migrations**: <yes/no, online/offline>
- **New domain events**: <list or "none">
- **New / modified endpoints**: <short list>
- **Relevant design decisions** (see `03-design.md` for full detail): <2-3 key points from the ADR-light>

</details>
```

Rules:
- **The technical block goes in a collapsed `<details>`** — the reviewer opens it if they want, it does not clutter the main reading.
- **The `## Pre-deploy` section does NOT go in `<details>`**: it is a deployment gate, it must be visible. Only applies if `git.predeploy_gate` is active and the branch touches the DB; if not, omit it.
- **Do not copy bullets from `03-design.md` literally** into the main body. The design talks about layers, repositories, value objects — the MR/PR talks about behavior the user notices.
- **If the brief description contradicts what you see in the diff**, the diff wins (and warn the user: either the brief was wrong, or the build deviated).

### Collect the pre-deploy SQL (only if `git.predeploy_gate` active)
Determine whether the branch modifies the database (changes in migrations, mappings/schema, or changes recorded in `03-design.md`/`05-implementation.md`). If `quality.db_diff` is defined in `FLOW.md`, run it to see the pending schema SQL. Collect **all** statements that must be run manually on the server before deploying and consolidate them into **one single block** — the same one that goes in the `## Pre-deploy` section and in the §4.2 thread. Even if there are multiple modifications, it is **one block / one thread**.

## 3. Show the user and wait for confirmation (MANDATORY)

**Never skip this step, even when the content seems obvious.** The user needs to see and approve what will be published before anything is created.

Print to the user in this exact format:

```
─── Preview of <git.request_term> ─────────────────────────────────────
Title: <full title, including [patch|minor|major]>
Assigned to: <git.assignee from FLOW.md; if empty: "unassigned">
Squash on merge: <git.squash from FLOW.md>
Target branch: <git.default_base from FLOW.md, or the parent branch in train mode>
Issue link: <keyword that will appear in the body, e.g. "Closes #123" / "Part of #123 (intermediate train PR)" / "none — Jira links by title prefix">
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered exactly as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there is pre-deploy SQL, ask the user to **explicitly confirm that the block is complete and correct** — it is what will stop the deployment and what will be executed in production.

Then ask with `AskUserQuestion` (header: "Create <git.request_term>"):

- **Create with this content**: user confirms → invoke §4.
- **Edit before creating**: user indicates what to change (title, some section, both); adjust and return to §3 with the new preview.
- **Cancel**: stop without creating anything. Do not touch `meta.json`. The user can return to `/feat:ship` later.

Do not push or invoke any creation command until the user has responded "Create with this content".

## 4. Commit, push, and MR/PR creation

### 4.0 Anti-deploy lock (before any push)
Verify, and **block** if anything fails:
```bash
git rev-parse --abbrev-ref HEAD                          # must NOT be master/main
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null   # must NOT be the base branch
```
- If HEAD is the main branch (master/main): stop and warn. Do not push from the main branch.
- If the upstream is `<git.default_base>` (branch created without `--no-track`): **do not push resolving the upstream**. Fix with `git branch --unset-upstream` and use `git push -u origin HEAD`, which sets the upstream to the branch itself.
- In train mode (`stacked_on` ≠ null): the MR/PR must point to that parent branch, not to the main base.

### 4.1 Create MR/PR
Only here — with the content approved by the user in §3 — invoke `Skill commit-commands:commit-push-pr` passing **the final title and description**. The skill must not re-ask for the content; if it does, answer with what was confirmed. If it pushes, it must be `git push -u origin HEAD` (own branch), never to the base branch.

If `git.assignee` is not empty in `FLOW.md`, assign to that user. If `git.squash` is `true`, enable squash-before-merge.

If the `commit-push-pr` skill is not available, commit and push manually and create the MR/PR with the `git.cli` CLI from `FLOW.md` — always with the content already confirmed in §3.

### 4.2 Pre-deploy thread (deployment gate)
**Only if `git.predeploy_gate` is active and the branch has pre-deploy SQL** (§2). After creating the MR/PR, open **a single resolvable/blocking thread** with **all** the consolidated SQL, using the `git.host`/`git.cli` host:
- **GitLab**: `glab api "projects/<repo-url-encoded>/merge_requests/<iid>/discussions" -f body="..."` (creates a resolvable thread).
- **GitHub**: a review conversation that requires resolution before merging ("require conversation resolution" policy).

Thread body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve this thread only after having executed it in production."

This is the gate: with the repo policy of "all threads resolved before merge", the MR/PR cannot be merged or deployed until the SQL is executed and the thread is **resolved**. **One single thread even if there are multiple statements.** Inform the user that it is left open on purpose.

## 5. Domain knowledge (offer)

If `domain_memory.enabled` is `true` in `FLOW.md`:

**Only if there is something non-obvious worth saving** (silence-by-default rule):

1. **Read the staging accumulated during the branch**: call `mcp__domain-memory__read_staging`. This shows you what `/feat:design` (and possibly other phases) already staged. That is the main material to consolidate.
2. **Review the artifacts** `03-design.md`, `05-implementation.md`, and `06-review.md` for findings of the "why" type (domain decisions, legal constraints, integrations, business motivations) that **were not staged at the time**. The "what" (code, paths) is NOT saved — that is in the repo.
3. **Combine staging + new findings** into a short list. If the list is empty or only has things obviously derivable from the code, do not insist.
4. If there are 1+ relevant findings, ask the user if they want to consolidate them. If yes, invoke `Skill save-knowledge` (this skill already does `read_staging` internally and orchestrates the save; you provide the context of what to consolidate). If no, do not insist.

If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 6. Close

### 6.1 Update `meta.json` per scenario

**A) The MR/PR was created (and merged, if the flow reached that)** (normal case):
- If there are **no** `mrs` or there was only 1: once merged, `phase = "done"`, add `ship` to `phases_done`, update `updated_at`.
- If it is a multi-delivery build: record the current MR/PR's `url` in its `meta.json.mrs` entry. Set its `status` to `merged` **only if the user confirms it was actually merged**; otherwise keep it `in_progress` — **the train does not require the current MR/PR to be merged to proceed**. If there are still `pending` entries, leave `phase = "build"` and go to §6.2 (train continuation). If all entries are `merged`/`closed`/`superseded`, `phase = "done"`.

**B) The MR/PR was closed without merge** (rejected, discarded by reviewers):
- Mark the current entry as `closed` with a `note` explaining the reason.
- Ask the user: retry with a different MR/PR approach (return to `/feat:build` with a different approach), or consider the feature unviable (`/work:abandon`)? Do not decide alone.

**C) The plan changed and this MR/PR is no longer needed**:
- If coming here because the plan was rethought: mark the entry as `superseded` with `note` pointing to the new MR/PR.

### 6.2 Train continuation (only if `meta.json.mrs` still has `pending` entries)

The whole point of a train is to build the next MR/PR **without waiting for the current one to merge**. So do not stop here to wait for the merge — resolve `git.train_chain` from FLOW.md (`ask` | `always` | `wait`; **empty → derive from `autonomy.mode`**: `manual` → `ask`, `guided`/`auto` → `always`) and act:

- **`wait`**: do not continue now. Leave `phase = "build"` and tell the user to run `/feat:build` once the current MR/PR is merged. This legacy "wait for merge" behavior happens **only** when explicitly configured.
- **`ask`**: ask with `AskUserQuestion` — "Continue now with the next MR/PR (#\<n+1\> «\<title\>»), stacked on this branch?". If **no** → stop and recommend `/feat:build`. If **yes** → continue as in `always`.
- **`always`**: continue automatically; record the decision in the artifact, do not prompt.

To continue (both `ask`→yes and `always`):
1. Create the next branch **stacked on the current branch**, following `/feat:start §5` rules (explicit base = the current branch, `--no-track`, worktree per `git.worktree`) and, for `tracker.tool: gh`, the linked-branch step `/feat:start §5.5` (base = the current branch). Record `stacked_on` = current branch in `meta.json`.
2. Leave `phase = "build"` (`/feat:build §1` will pick the next `pending` MR/PR and mark it `in_progress`).
3. Chain into `/feat:build`.

This continuation is **not** a hard gate: creating a stacked branch on an explicit, unambiguous parent is safe, and the next real hard gate — creating MR/PR #\<n+1\> in its own `/feat:ship` — will still stop and ask. Never hold the train back solely to wait for a merge unless `train_chain: wait`.

### 6.3 Summary and cleanup

Summarize to the user: ticket, MR/PR URL, changed files, added tests. In multi-delivery, also indicate remaining entries per `meta.json.mrs`.

Ask if they want to keep the `.claude/work/<TICKET>/` folder or archive it (move to `.claude/work/_archive/`) — only if `phase = "done"`.

If `phase = "done"` and `meta.json.worktree` is not null, the branch's worktree is no longer needed once the MR/PR is merged: offer to remove it (from the main checkout) with `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Do not remove it if the MR/PR is not yet merged, or without confirmation.
