---
description: Regression test and verification that the failure does not recur
---

# `/flow-bug-validate`

Validate that the fix works and that the failure does not come back.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`. Require `fix` in `phases_done`.
- If `size` is `XS`, suggest skipping to `/flow-bug-review` unless the user insists.
- If the fix was developed in a worktree (`meta.json.worktree` not null), offer it once so the user can test this branch against the main environment: "run `/flow-work-try <meta.branch>` (switches the main checkout and re-syncs per `git.worktree_resync`); `/flow-work-try --back` to return." Suggest it, don't run it yourself.

## 2. Work

**Mandatory regression test**: launch the `agents.testing` subagent from FLOW.md (if empty, a general-purpose subagent with the role of writing tests) with the task:

> Write a test that **fails before** the fix and **passes after**. Read `.claude/work/<TICKET>/02-diagnose.md` (minimal reproduction), `04-fix.md` (what changed). Follow the conventions from `FLOW.md` (section `conventions`). Report the path of the added test.

Then:
1. Run only that test with `quality.test_one` from FLOW.md; it must pass.
2. Run the full suite with `quality.test` to rule out collateral regressions (in the background if it takes long).
3. If you touched the DB: verify the schema has no unexpected differences (use `quality.db_update` or its FLOW.md equivalent if defined).
4. If you touched security or authentication: launch the `agents.security` subagent from FLOW.md in parallel on the fix files; if empty, use a general-purpose subagent with a security role in the prompt.

## 3. Adjacent areas

`03-investigation.md` may list "areas with similar risk". Don't fix them here, but verify that **at least they don't have the same active symptom** (quick search for the broken pattern).

## 4. Output

`.claude/work/<TICKET>/05-validation.md`:

```markdown
# Validation {TICKET}

## Regression test
- Path: `tests/...`
- Fails before the fix: ✅
- Passes after the fix: ✅

## Full suite
- `<quality.test>`: ✅ / ❌ (X failures)
- `<quality.static_analysis>`: ✅ / ❌

## Adjacent areas
- Searches performed:
- Other issues detected: <list to open separate tickets, NOT fix here>
```

## 5. Wrap-up

- If test is red or regressions found: `phase` stays at `fix`. The user iterates.
- If green: `phase = "validate"`, add to `phases_done`. Suggest `/flow-bug-review`.
