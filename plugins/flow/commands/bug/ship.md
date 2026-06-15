---
description: Commit, push, MR/PR the fix
---

# `/flow:bug:ship`

Close the bug flow: commit, push, MR/PR. Uses the same mechanics as `/flow:feat:ship` with two differences:

1. If `99-postmortem.md` exists, **include the link or the executive summary** in the MR/PR description.
2. The `save-knowledge` offer was already made in `/flow:bug:postmortem` — do not ask again here.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user.

- Load `meta.json`. Require `review` in `phases_done` (and `validate` if `size` ≥ S, and `postmortem` if `size` is L).
- If not, refuse and redirect to the missing step.

## 1. Draft title and description (without sending anything yet)

**Important**: in this step `commit-push-pr` is **not** invoked yet and nothing is created. Only draft the content to show the user in §2.

### Title

Format: `{PREFIX}{TICKET} Fix <observable symptom, in plain language> [patch]`.

**Good**: `{PREFIX}15310 Fix opens counted twice on retry [patch]`
**Bad**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Fixes are `[patch]` unless they break a contract — in that case reconsider whether it is actually a fix or a versioned feature.

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

### 3.2 Pre-deploy thread (deployment gate)
**Only if `git.predeploy_gate` is active and the fix has pre-deploy SQL** (§1). After creating the MR/PR, open **a single resolvable/blocking thread** with all the consolidated SQL, using the host from `git.host`/`git.cli` (GitLab: `glab api ".../merge_requests/<iid>/discussions"`; GitHub: review conversation with required resolution). Body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve only after running it in production".

With a "all threads resolved before merge" policy, the MR/PR cannot be merged or deployed until the SQL is executed and the thread is resolved. **One single thread even if there are multiple statements.** Notify the user that it is intentionally left open.

## 4. Close

- Update `meta.json`: `phase = "done"`, add `ship` to `phases_done`.
- Summarize: ticket, MR/PR URL, regression test added.
- Ask whether to archive `.claude/work/<TICKET>/` to `.claude/work/_archive/`.
