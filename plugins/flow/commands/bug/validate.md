---
description: Regression test and verification that the bug does not return
---

# `/flow:bug:validate`

Validate that the fix works and that the bug does not return.

## 1. Pre-flight

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context. **Models key for this command: `test`.**

- Read `meta.json` and `00-summary.md`; open in full only `03-investigation.md` (§3 areas with similar risk) — the testing agent reads `02-diagnose.md` and `04-fix.md` itself. (flow-core §5)
- Require `fix` in `phases_done`.
- `size` `XS` → suggest skipping to `/flow:bug:review` unless the user insists.
- Fix developed in a worktree (`meta.json.worktree` not null) → offer once, do not run it yourself: "run `/flow:work:try <meta.branch>` (switches the main checkout and re-syncs per `git.worktree_resync`); `/flow:work:try --back` to return."

## 2. Work

**Mandatory regression test**: launch the `agents.testing` agent from FLOW.md (empty → `Agent general-purpose` with a test-writing role):

> Write a test that **fails** before the fix and **passes** after. Read `.claude/work/<TICKET>/02-diagnose.md` (minimal reproduction), `04-fix.md` (what was changed). Follow the conventions in `FLOW.md` (section `conventions`). Report the path of the added test.

Then:
1. Run only that test with `quality.test_one` from FLOW.md; it must pass.
2. Run the full suite with `quality.test` to rule out collateral regressions (in the background if slow).
3. DB touched → verify the schema has no unexpected differences (`quality.db_update` or the FLOW.md equivalent, if defined).
4. Security or authentication touched → launch the `agents.security` agent from FLOW.md in parallel over the fix files (empty → `Agent general-purpose` with a security role).

## 3. Adjacent areas

"Areas with similar risk" from `03-investigation.md`: do not fix them here, but verify that **at least they do not have the same active symptom** (quick search for the broken pattern).

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
- Searches done:
- Other bugs detected: <list to open separate tickets, do NOT fix here>
```

## 5. Close

- Red test or regressions → `phase` stays at `fix`; the user iterates. A red gate stops in every mode.
- Green → `phase = "validate"`, add to `phases_done`; in the same write record `validated_sha` = `git rev-parse HEAD` — the tree the regression test passed on, which `/flow:bug:ship §0` reads. Suggest `/flow:bug:review`.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- **Autonomy handoff** (green only; `autonomy.mode`, flow-core §2): `manual` → propose `/flow:bug:review` with a single `AskUserQuestion`, invoke it only on confirmation; `guided`/`auto` → chain into it in this same turn.
