---
description: Commit, push, MR/PR for the fix
---

# `/flow-bug-ship`

Close the bug flow: commit, push, MR/PR. Uses the same mechanics as `/flow-feat-ship` with two differences:

1. If `99-postmortem.md` exists, **include the link or executive summary** in the MR/PR description.
2. The `save-knowledge` offer was already made in `/flow-bug-postmortem` — do not ask again here.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`. Require `review` in `phases_done` (and `validate` if `size` ≥ S, and `postmortem` if `size` is L).
- If not, refuse and point to the missing step.

## 1. Draft title and description (without pushing anything yet)

**Important**: in this step do **not** invoke commit, push, or create anything. Only draft the content to show the user in §2.

### Title

Format: `{PREFIX}{TICKET} Fix <observable symptom, in plain language> [patch]`.

**Good**: `{PREFIX}15310 Fix opens counted twice on retry [patch]`
**Bad**: `{PREFIX}15310 Fix tracking pixel double-counting on retry in PixelOpenedHandler [patch]`

Fixes are `[patch]` unless they break a contract — in that case, reconsider whether this is truly a fix or a versioned feature.

### Description

**Build the description from the Brief in `04-fix.md`**, not from the previous technical artifacts. If `04-fix.md` has no Brief (older fix), draft it now from the reported symptom.

Template (in this order):

```markdown
## What stops happening after this fix
<what the user observed that they will no longer observe. Symptom language, not code language.>

## What changes (behavior)
<1-2 lines in plain language. NOT file names.>

## What has NOT been touched
<bullets from the "What is NOT touched" section of the Brief. Important so the reviewer knows the fix is minimal.>

## Steps to reproduce and verify
<from `05-validation.md`:
1. Reproduction of the bug before the fix (no longer applies, but documents the case).
2. How to verify the behavior is correct after the fix.
3. Regression test added and where it is.>

## Pre-deploy (ONLY if `git.predeploy_gate` is active and the fix touches the database)
SQL to run **manually on the server BEFORE deploying**, all statements in a single block:
```sql
<DDL/indexes/columns/data corrections — all together>
```
⚠️ **Do not deploy until this SQL has been run in production.**

## Postmortem (if it exists)
<if `99-postmortem.md` exists: 3-5 bullet executive summary + link to the artifact in the repo or wiki. The executive summary goes here because it matters to non-technical stakeholders; the detail is read separately.>

---

<details>
<summary>Technical details for reviewers</summary>

- **Root cause** (from `03-investigation.md` §"Root cause identified"): <one line>.
- **Fix files**: <from `04-fix.md` "Changes by file">.
- **Regression test**: `tests/...` (fails before the fix, passes after).
- **Areas with similar risk** (noted, not fixed here): <from `04-fix.md`>.

</details>
```

Use the sections from `git.request_sections` in FLOW.md if defined; otherwise the template above serves as a free-form description.

Rules:
- **The reviewer of a bug is often a PM or support person** as well as the on-call developer. The description must let them validate that the reported symptom is actually resolved, without reading code.
- **"What has NOT been touched" is especially important in fixes** — it prevents scope creep and makes clear that the fix is minimal.
- **The `## Pre-deploy` section must NOT go inside `<details>`**: it is a deployment gate and must be visible. Only applies if `git.predeploy_gate` is active and the fix touches the DB; otherwise omit it.
- **Postmortem at the top**: if it exists, its summary goes in the main description, not in `<details>`.

### Collect the pre-deploy SQL (only if `git.predeploy_gate` is active)
Determine whether the fix modifies the database (migrations, mappings/schema, or changes recorded in the artifacts). If `quality.db_diff` is defined in `FLOW.md`, run it to see the pending schema SQL. Collect **all** statements to run manually before deploying in **a single block** — the same one that goes in the `## Pre-deploy` section and in the §3.2 thread. One block / one thread even if there are multiple statements.

## 2. Show to the user and wait for confirmation (REQUIRED)

**Never skip this step.** The user needs to see and approve what will be published before anything is created.

Print to the user in this exact format:

```
─── {request_term} preview (fix) ───────────────────────────────
Title: <full title, including [patch]>
Assigned to: <git.assignee from FLOW.md; empty = unassigned>
Squash: <git.squash from FLOW.md>
Target branch: <git.default_base>
Pre-deploy (manual SQL): <"yes — N statements, a blocking thread will be opened" / "not applicable">

Description:
<full description rendered exactly as it will appear in the MR/PR>
─────────────────────────────────────────────────────────────────
```

If there is pre-deploy SQL, ask the user to **explicitly confirm that the block is complete and correct** — this is what will gate the deployment and what will be run in production.

Then ask the user (heading: "Create {request_term}"):

- **Create {request_term} with this content**: confirm → invoke §3.
- **Edit before creating**: the user indicates what to change; adjust and return to §2.
- **Cancel**: stop without creating anything. Do not touch `meta.json`.

Do not invoke commit or push until explicit confirmation.

## 3. Commit, push, and create the MR/PR

### 3.0 Anti-deployment lock (before any push)

Same as `/flow-feat-ship` §4.0: `git rev-parse --abbrev-ref HEAD` must not be the main base branch (master/main), and `@{u}` must not point to `git.default_base`. If the upstream points to the base, run `git branch --unset-upstream` and `git push -u origin HEAD`. In train mode the MR/PR points to the parent branch.

### 3.1 Create MR/PR

Only here — with the content approved in §2 — commit, push, and create the MR/PR using the `git.cli` CLI from `FLOW.md`. If a commit+push+MR skill is available in the tool, use it passing the **final title and description**; if not available, do it manually. The push must be `git push -u origin HEAD`, never to the main base.

Assign to `git.assignee` from FLOW.md (if empty, leave unassigned). Enable squash per `git.squash`.

### 3.2 Pre-deploy thread (deployment gate)
**Only if `git.predeploy_gate` is active and the fix has pre-deploy SQL** (§1). After creating the MR/PR, open **a single resolvable/blocking thread** with all the consolidated SQL, using the host from `git.host`/`git.cli` (GitLab: `glab api ".../merge_requests/<iid>/discussions"`; GitHub: review conversation with required resolution). Body: the SQL block under "Pre-deploy: run this SQL on the server BEFORE deploying" + "Resolve only after running it in production".

With a "all threads resolved before merge" policy, the MR/PR cannot be merged or deployed until the SQL is run and the thread is resolved. **One thread even if there are multiple statements.** Warn the user that it is left open intentionally.

## 4. Close

- Update `meta.json`: `phase = "done"`, add `ship` to `phases_done`.
- Summarize: ticket, MR/PR URL, regression test added.
- **Cross-repo reminder**: if `meta.json.related_repos` has any entry not `done`, call it out now — for each: *"you've shipped the `<this-repo>` part; `<repo>` still needs: `<scope>` → go there and run `/flow-bug-start <TICKET>` (or `/flow-feat-start`)"*. flow does not touch the other repo; it only reminds, and this is not a hard gate.
- Ask if they want to archive `.claude/work/<TICKET>/` to `.claude/work/_archive/`.
- If `meta.json.worktree` is not null, offer to remove the worktree once the MR/PR is merged: `git worktree remove <worktree>` (`--force` only if it still has changes the user confirms discarding). Not before merge, not without confirmation.
