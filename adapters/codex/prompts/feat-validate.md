# `/feat-validate`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Verifies the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. If not, send to `/feat-review`.
- If `size` is `XS`, this phase may be skipped (warn and continue with `/feat-ship`).

## 2. Work

Launch in **parallel**:

1. **Testing agent**: use the `agents.testing` agent from `FLOW.md`; if empty, use a general subagent with this role. Assignment: "Review the branch changes and complete the test suite where coverage is missing. Focus: edge cases from `03-design.md`, error paths, input validation, emitted domain events. Do not rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance agent** if the feature touches persistence, repositories, templates on hot paths, or controllers with real traffic: use the `agents.performance` agent from `FLOW.md`; if empty, use a general subagent. Assignment: "Detect N+1, missing indexes, unbounded queries, flush in a loop, heavy synchronous work that should go to a queue. Report only actionable findings."

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and flag what you're using. If there are frontend changes and `quality.frontend_test` is defined, run it too.

## 3. Manual edge cases

If the feature has a user interface or critical flows:
- If it touches payments: test with the appropriate test cards or credentials for the provider (see the `stripe:test-cards` skill if using Stripe).
- If it touches workers/queues: make sure no jobs are stuck in the failure queue. If there are and they're not yours, don't touch them here.
- If it touches migrations: run `quality.db_update` from `FLOW.md` (if defined). Verify there's no unexpected schema difference.

## 4. Output

Write `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validation <TICKET>

## Test coverage
- Unit tests added: N (list)
- Integration tests added: M
- Functional tests added: K

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
- No regressions detected / Detected: …
```

## 5. Close

- If tests are red or regressions remain, **do not advance `phase`**. The user resolves them and returns to `/feat-validate`.
- If all green: `phase = "validate"`, add to `phases_done`. Suggest `/feat-ship`.
