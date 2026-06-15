# `/feat-ship`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user.

Closes the feature: commit, push, MR/PR (assigned per `git.assignee`, squashed per `git.squash`, sections per `git.request_sections`) and optional offer to consolidate knowledge.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. For `size` other than `XS`, also require `validate`.
- If not met, refuse and send the user to the missing step.
- Check there are no blocking TODO or FIXME added on this branch (`git diff --unified=0 <git.default_base>...HEAD | grep -E '^\+.*(TODO|FIXME)'`). If any exist, list them and ask whether to continue.

## 2. Draft title and description (without sending anything yet)

**Important**: in this step **nothing** is pushed or created yet. Only draft the MR/PR content to show the user in §3.

### Title

Format: `<TICKET> <what it does for the user, in behavior language> [patch|minor|major]`.

**Good**: `<TICKET> List opens for a tracking by API [minor]`
**Bad**: `<TICKET> Add GET /orders/{id}/items endpoint with cursor pagination [minor]`

If `git.squash` is `true`, the squash leaves the MR/PR title as the final commit message, so the commit message and title are identical.

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
<if `meta.json.mrs` has >1 entry: "MR/PR 2/4 of the delivery plan — see #1 (link) and remaining pending #3, #4".>

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
4. If there are 1+ relevant findings, ask the user whether they want to consolidate them. If yes, invoke the `/save-knowledge` workflow. If no, don't insist.

If `domain_memory.enabled` is `false` or empty, skip without comment.

## 6. Close

Update `meta.json` based on the scenario:

**A) The MR/PR was merged successfully**:
- If there are **no** `mrs` or there was only 1: `phase = "done"`, add `ship` to `phases_done`, update `updated_at`.
- If multi-delivery build: mark the current MR/PR as `merged` (with final `url`) in `meta.json.mrs`. If there are still `pending` entries, leave `phase = "build"`. If all are `merged`/`closed`/`superseded`, `phase = "done"`.

**B) The MR/PR was closed without merging**: mark the current entry as `closed` with `note`. Ask the user whether to retry or abandon with `/work-abandon`.

**C) The plan changed and this MR/PR is out of scope**: mark the entry as `superseded` with `note` pointing to the new MR/PR.

Summarize for the user: ticket, MR/PR URL, changed files, tests added. Ask whether they want to keep the `.claude/work/<TICKET>/` folder or archive it — only if `phase = "done"`.
