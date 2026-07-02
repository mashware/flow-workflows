---
description: Validate tests, edge cases, and integrity before pushing
---

# `/feat-validate`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Verify that the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. If missing, send to `/feat-review`.
- If `size` is `XS`, this phase can be skipped (warn and continue with `/feat-ship`).

## 2. Work

Launch **in parallel**:

1. **Testing sub-agent**: use the `agents.testing` sub-agent from `FLOW.md`; if empty, use a general-purpose sub-agent with this role. Task: "Review the branch changes and complete the test suite where coverage is missing. Focus: edge cases from `03-design.md`, error paths, input validations, domain events emitted. Don't rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance sub-agent** if the feature touches persistence, repositories, templates on high-traffic routes, or controllers with real traffic: use the `agents.performance` sub-agent from `FLOW.md`; if empty, use a general-purpose sub-agent with this role. Task: "Detect N+1, missing indexes, unbounded queries, flush in a loop, heavy synchronous work that should go to a queue. Report only actionable items."

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and report what you use. If there are frontend changes and `quality.frontend_test` is defined, run it too.

## 3. Manual edge cases

If `meta.json.worktree` is not null (the work was developed in a worktree and the runnable env lives in the main checkout), offer it once before verifying: "to test this branch against the main environment, run `/work-try <meta.branch>` (it switches the main checkout and re-syncs per `git.worktree_resync`), and `/work-try --back` to return afterwards." Suggest it, don't run it yourself and don't force it.

If the feature has a UI or critical flows:
- If it touches payments: test with the test cards or credentials appropriate for the provider (see conventions in `FLOW.md` section `conventions` or a specific skill if one exists).
- If it touches workers/queues: make sure no jobs are stuck in the failure queue. If there are and they're not yours, don't touch them here.
- If it touches migrations: run `quality.db_update` from `FLOW.md` (if defined). Verify there's no unexpected schema difference using the project's schema comparison command.

## 4. Output

Write `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validation <TICKET>

## Test coverage
- Unit added: N (list)
- Integration added: M
- Functional added: K

## Suite results
- `<quality.test>`: ✅ / ❌ (N tests, X failures)
- `<quality.frontend_test>`: ✅ / ❌ / N-A
- `<quality.static_analysis>`: ✅ / ❌

## Performance
- Analysis findings: …
- Open risks: …

## Edge cases verified
- [x] …
- [ ] …

## Regressions
- Areas checked: …
- No regressions found / found: …
```

## 5. Close

- If there are failing tests or regressions, **don't advance `phase`**. The user resolves them and returns to `/feat-validate`.
- If everything is green: `phase = "validate"`, add to `phases_done`. Suggest `/feat-ship`.
