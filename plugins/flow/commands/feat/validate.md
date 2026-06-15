---
description: Validate tests, edge cases, and integrity before shipping
---

# `/feat:validate`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Verify the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. If missing, send to `/feat:review`.
- If `size` is `XS`, this phase may be skipped (warn and continue with `/feat:ship`).

## 2. Work

Launch **in parallel**:

1. **Testing agent**: use the `agents.testing` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Review the branch changes and complete the test suite where coverage is missing. Focus: edge cases from `03-design.md`, error paths, input validations, emitted domain events. Do not rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance agent** if the feature touches persistence, repositories, templates on hot paths, or controllers with real traffic: use the `agents.performance` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Detect N+1, missing indexes, unbounded queries, flush in a loop, heavy synchronous work that should go to a queue. Report only actionable findings."

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and note what you use. If there are frontend changes and `quality.frontend_test` is defined, run it as well.

## 3. Manual edge cases

If the feature has UI or critical flows:
- If it touches payments: test with the test cards or credentials appropriate for the provider (see `Skill stripe:test-cards` if using Stripe).
- If it touches workers/queues: make sure no jobs are stuck in dead-letter. If there are and they are not yours, do not touch them here.
- If it touches migrations: run `quality.db_update` from `FLOW.md` (if defined). Verify there is no unexpected schema difference with the comparison command the project uses.

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
- No regressions detected / detected: …
```

## 5. Close

- If any tests are red or regressions are found, **do not advance `phase`**. The user resolves them and returns to `/feat:validate`.
- If everything is green: `phase = "validate"`, add to `phases_done`. Suggest `/feat:ship`.
