# `/bug-ship`

Close the bug workflow: commit, push, MR/PR. Uses the same mechanics as `/feat-ship` with two differences:

1. If `99-postmortem.md` exists, **include the link or executive summary** in the MR/PR description.
2. The offer to save knowledge was already made in `/bug-postmortem` — it's not asked again here.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Load `meta.json`. Require `review` in `phases_done` (and `validate` if `size` ≥ S, and `postmortem` if `size` is L).
- If not met, refuse and send to the missing step.

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

Same as `/feat-ship` §4.0: HEAD must not be the main branch (master/main), and the upstream must not point to `git.default_base`. If the upstream points to the base, `git branch --unset-upstream` and `git push -u origin HEAD`. In train mode the MR/PR targets the parent branch.

### 3.1 Create MR/PR

Only here — with the content approved in §2 — commit with `git commit`, push with `git push -u origin HEAD` (branch's own remote, never to the main base), and create the MR/PR with the `git.cli` CLI from `FLOW.md` using the finalized title and description.

Assign to `git.assignee` from FLOW.md (if empty, unassigned). Enable squash per `git.squash`.

### 3.2 Pre-deploy thread (deployment brake)
**Only if `git.predeploy_gate` is active and the fix has pre-deploy SQL** (§1). After creating the MR/PR, open **a single resolvable/blocking thread** with all the consolidated SQL. Body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve only after running it in production". **One thread even if there are multiple statements.**

## 4. Close

- Update `meta.json`: `phase = "done"`, add `ship` to `phases_done`.
- Summarize: ticket, MR/PR URL, regression test added.
- Ask whether they want to archive `.claude/work/<TICKET>/` to `.claude/work/_archive/`.
- If `meta.json.worktree` is not null, offer to remove the worktree once the MR/PR is merged: `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Not before merge, not without confirmation.
