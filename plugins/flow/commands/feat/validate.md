---
description: Validate tests, edge cases, and integrity before shipping
---

# `/flow:feat:validate`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Verify the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Load `meta.json`. Require `review` in `phases_done`. If missing, send to `/flow:feat:review`.
- If `size` is `XS`, this phase may be skipped (warn and continue with `/flow:feat:ship`).

## 2. Work

Launch **in parallel**:

1. **Testing agent**: use the `agents.testing` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Review the branch changes and complete the test suite where coverage is missing. Focus: the acceptance criteria in `03-design.md` marked `test` that no current test demonstrably asserts (see the §3 mapping), plus edge cases from `03-design.md`, error paths, input validations, emitted domain events. Do not rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance agent** if the feature touches persistence, repositories, templates on hot paths, or controllers with real traffic: use the `agents.performance` agent from `FLOW.md`; if empty, use `Agent general-purpose` with this role. Brief: "Detect N+1, missing indexes, unbounded queries, flush in a loop, heavy synchronous work that should go to a queue. Report only actionable findings."

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and note what you use. If there are frontend changes and `quality.frontend_test` is defined, run it as well.

## 3. Criteria coverage (S and larger)

The gate of this phase is not "suite green" — it is "every acceptance criterion in `03-design.md` is demonstrably proven". Build the mapping (`XS` skips this phase entirely, so it does not apply; for `S` and larger it does):

1. Read the enumerated **Acceptance criteria** from `03-design.md`. For each criterion, find the test(s) that prove it — the specific test that would fail if that criterion were violated. A test that merely "touches the area" is not enough; it must assert the criterion's observable result (reuse the literal values from the criterion / contracts).
2. Classify each criterion:
   - **proven-by-test** — a named test demonstrably asserts it. Record the test path.
   - **needs-manual** — not provable by an automated test now (UI, end-to-end flow, visual result). Goes to the assisted loop in §4.
   - **unproven** — neither: no test asserts it and it is not a manual case. This is a gap → the testing agent in §2 adds the missing test; until it exists, the criterion stays `unproven`.
3. A criterion is **not** proven just because the suite is green. If no test actually asserts its result, it is `unproven` until one is added.

## 4. Assisted manual verification (for `needs-manual` criteria)

If `meta.json.worktree` is not null (the work was developed in a worktree and the runnable env lives in the main checkout), offer once before verifying: "to test this branch against the main environment, run `/flow:work:try <meta.branch>` (it switches the main checkout and re-syncs per `git.worktree_resync`), and `/flow:work:try --back` to return afterwards." Suggest it, do not run it yourself and do not force it.

For criteria that no automated test can prove now, verify them **together with the user**, one or a few at a time, keeping the running register — the user runs the flow, you keep the checklist until every criterion is accounted for:

1. For each `needs-manual` criterion, tell the user exactly what to do and what to observe, phrased from its given/when/then (e.g. "Open `/campaigns`, filter by last 7 days → the list should show only campaigns from the last 7 days, newest first").
2. Ask with `AskUserQuestion` — options **Pass** / **Fail** / **Blocked** (cannot test now). Batch up to 4 criteria per question.
3. Record each answer immediately in `07-validation.md` (§6 output, "Criteria coverage"):
   - **Pass** → status `proven-manually`, note the date.
   - **Fail** → status `unproven`; the criterion is not met — this blocks the gate until the implementation is fixed and re-verified.
   - **Blocked** → status `unproven`; record why. A blocked criterion does not pass the gate.
4. Repeat until every `needs-manual` criterion is `proven-manually`, or the user decides to stop (the rest stay `unproven`, which blocks advancing in §7).

## 5. Manual edge cases

If the feature has UI or critical flows:
- If it touches payments: test with the test cards or credentials appropriate for the provider (see `Skill stripe:test-cards` if using Stripe).
- If it touches workers/queues: make sure no jobs are stuck in dead-letter. If there are and they are not yours, do not touch them here.
- If it touches migrations: run `quality.db_update` from `FLOW.md` (if defined). Verify there is no unexpected schema difference with the comparison command the project uses.

## 6. Output

Write `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validation <TICKET>

## Criteria coverage
<one row per acceptance criterion from 03-design.md (S+; "N-A — XS" if the phase was skipped)>

| Criterion | Proof type | Test / confirmation | Status |
|-----------|-----------|---------------------|--------|
| AC1: <short> | test | `tests/Foo/BarTest::testX` | ✅ proven-by-test |
| AC2: <short> | manual | confirmed by user 2026-06-24 | ✅ proven-manually |
| AC3: <short> | manual | — | ❌ unproven (blocked: staging down) |

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

## 7. Close

- **Do not advance `phase`** if any of these holds: tests are red, regressions are found, or **any acceptance criterion is `unproven`** (no test demonstrably asserts it and it was not manually confirmed). The criterion→test mapping is part of the gate, not just a report — the same "do not advance on red" rule. The user resolves the gap (add the missing test, fix the implementation, or finish the manual verification) and returns to `/flow:feat:validate`.
- If the suite is green **and** every acceptance criterion is `proven-by-test` or `proven-manually`: `phase = "validate"`, add to `phases_done`. Suggest `/flow:feat:ship`.
