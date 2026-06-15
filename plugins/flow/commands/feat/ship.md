---
description: Commit, push, MR/PR, and offer to save domain knowledge
---

# `/feat:ship`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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
Target branch: <git.default_base from FLOW.md>
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

Update `meta.json` per scenario:

**A) The MR/PR was merged correctly** (normal case):
- If there are **no** `mrs` or there was only 1: `phase = "done"`, add `ship` to `phases_done`, update `updated_at`.
- If it is a multi-delivery build: mark the current MR/PR as `merged` (with the final `url`) in `meta.json.mrs`. If there are still `pending` entries, leave `phase = "build"` (the cycle repeats for the next one). If all are `merged`/`closed`/`superseded`, `phase = "done"`.

**B) The MR/PR was closed without merge** (rejected, discarded by reviewers):
- Mark the current entry as `closed` with a `note` explaining the reason.
- Ask the user: retry with a different MR/PR approach (return to `/feat:build` with a different approach), or consider the feature unviable (`/work:abandon`)? Do not decide alone.

**C) The plan changed and this MR/PR is no longer needed**:
- If coming here because the plan was rethought: mark the entry as `superseded` with `note` pointing to the new MR/PR.

Summarize to the user: ticket, MR/PR URL, changed files, added tests. In multi-delivery, also indicate remaining entries per `meta.json.mrs`.

Ask if they want to keep the `.claude/work/<TICKET>/` folder or archive it (move to `.claude/work/_archive/`) — only if `phase = "done"`.
