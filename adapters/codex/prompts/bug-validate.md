# `/bug-validate`

Validate that the fix works and the failure doesn't come back.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Load `meta.json`. Require `fix` in `phases_done`.
- If `size` is `XS`, suggest jumping to `/bug-review` unless the user insists.

## 2. Work

**Mandatory regression test**: launch the `agents.testing` agent from FLOW.md (if empty, a general subagent with the testing role) with the assignment:

> Write a test that **fails before** the fix and **passes after**. Read `.claude/work/<TICKET>/02-diagnose.md` (minimal reproduction), `04-fix.md` (what changed). Follow the conventions in `FLOW.md` (section `conventions`). Report the path of the added test.

Then:
1. Run just that test with `quality.test_one` from FLOW.md; it must pass.
2. Run the full suite with `quality.test` to rule out collateral regressions (in the background if it takes a while).
3. If you touched DB: verify the schema has no unexpected differences (use `quality.db_update` or equivalent from FLOW.md if defined).
4. If you touched security or authentication: launch in parallel the `agents.security` agent from FLOW.md on the fix files; if empty, use a general subagent with a security role.

## 3. Adjacent areas

`03-investigation.md` may have "areas with similar risk". Don't fix them here, but check that **at least they don't have the same active symptom** (quick search for the broken pattern).

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
- Other issues detected: <list to open separate tickets, do NOT fix here>
```

## 5. Close

- If a test is red or regressions remain: `phase` stays at `fix`. The user iterates.
- If all green: `phase = "validate"`, add to `phases_done`. Suggest `/bug-review`.
