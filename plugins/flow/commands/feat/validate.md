---
description: Validate tests, edge cases, and integrity before shipping
---

# `/flow:feat:validate`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context. **Models key for this command: `test`.**

Verify the feature is complete: test coverage, edge cases, performance, regressions.

## 1. Pre-flight

- Read `meta.json` and `00-summary.md`; open in full only the acceptance criteria of `03-design.md` and `05-implementation.md`. (flow-core §5)
- Require `review` in `phases_done`. **Multi-MR/PR work** (`meta.json.mrs` has >1 entry) → require `review` in the **current `in_progress` MR/PR's** own `phases_done` (its `mrs[]` entry), not the work-level list — a previous MR/PR's `review` does not count. Missing → send to `/flow:feat:review`.
- `size` `XS` → this phase may be skipped (warn and continue with `/flow:feat:ship`).

## 2. Work

Launch **in parallel** — both briefs end with the report contract of flow-core §6 (`agents.report_max_words`, empty → 250; findings only, one line each), and the testing agent is told the **test files are the deliverable**, saved as each one is finished, not at the end:

1. **Testing agent**: the `agents.testing` agent from `FLOW.md`; if empty, `Agent general-purpose` with this role. Brief: "Review the branch changes and complete the test suite where coverage is missing. Focus: the acceptance criteria in `03-design.md` marked `test` that no current test demonstrably asserts (see the §3 mapping), plus edge cases from `03-design.md`, error paths, input validations, emitted domain events. Do not rewrite tests that already pass. Read `.claude/work/<TICKET>/03-design.md` and `05-implementation.md`. Follow the project's test conventions (see `FLOW.md` section `conventions`)."

2. **Performance agent** if the feature touches persistence, repositories, templates on hot paths, controllers with real traffic, or calls anything outside the process inside a loop: the `agents.performance` agent from `FLOW.md`; if empty, `Agent general-purpose` with this role. Brief: "Detect N+1, missing indexes, unbounded queries, flush in a loop, per-iteration calls that leave the process (external API, HTTP, cache, filesystem), and heavy synchronous work that should go to a queue. For any call inside a loop that can fail, follow what **each failed iteration** sets off downstream — what it publishes, enqueues, disables or logs — and whether N failures multiply it. Report only actionable findings."

   **A green suite is not a performance result** — a tiny fixture database proves a query's **rows**, never its **plan**. If `/flow:feat:review §3.6` left any query verdict `unresolved`, or an acceptance criterion concerns speed or volume: run the measurement of **`/flow:work:query §4`** with the volumes in `data.volumes` (or a data set shaped like them — the distribution matters more than the total), record plan and timings, and gate on the result. No `data.*` configuration and the criterion cannot be measured → it is `unproven` with the reason, never silently `proven`.

3. **Full suite**: run `quality.test` from `FLOW.md` in the background; if empty, auto-discover the project's test command and note what you use. Frontend changes and `quality.frontend_test` defined → run it as well.

## 3. Criteria coverage (S and larger)

The gate of this phase is not "suite green" — it is "every acceptance criterion in `03-design.md` is demonstrably proven". `XS` skips this phase entirely; for `S` and larger build the mapping:

1. Read the enumerated **Acceptance criteria** from `03-design.md`. For each, find the test(s) that would fail if it were violated. A test that merely "touches the area" is not enough — it must assert the criterion's observable result (reuse the literal values from the criterion / contracts).
2. Classify each criterion:
   - **proven-by-test** — a named test demonstrably asserts it. Record the test path.
   - **needs-manual** — not provable by an automated test now (UI, end-to-end flow, visual result). Goes **first** to the automated attempt in §3.5, and only what that cannot drive reaches the assisted loop in §4.
   - **unproven** — neither. This is a gap → the testing agent in §2 adds the missing test; until it exists the criterion stays `unproven`.
3. A criterion is **not** proven just because the suite is green: no test asserts its result → `unproven` until one is added.

## 3.5 Try it yourself first (for `needs-manual` criteria)

Everything else this phase produces is evidence *you* generated — a named test, a green suite, a
measured plan. `needs-manual` was the one bucket where the evidence was the user's, taken on your
word about what to look at. Exhaust what you can verify before asking them for anything.

Read `quality.functional_check` from `FLOW.md` (empty → use what is available: a browser automation
tool, a simulator, a CLI that drives the app, an HTTP call against a local endpoint — the same
signals `/flow:doctor` reports). **Nothing available → skip this section in one line and go to §4**;
that is a legitimate outcome, not a failure.

`meta.json.worktree` not null → the runnable environment lives in the main checkout, not here. Do
not fight it: say so once and go to §4, whose first move is `/flow:work:try` (§4 owns that handover).

For each `needs-manual` criterion, drive its given/when/then against the running app and record one
of three outcomes:

- **`proven-by-agent`** — you exercised it and observed the expected result. Record **how** (tool,
  route, command) and the **evidence** (§3.6).
- **`needs-manual`** — you could not drive it: no tool, credentials you do not hold, a physical
  device, a third-party sandbox. **Record the reason.** It falls through to §4, so the user is only
  ever asked about what you genuinely could not do.
- **Fail** — you drove it and the result is not what the criterion says. `unproven`, and it blocks
  the gate exactly as a failed manual check does. Do not "fix and re-run" here: report it, the
  implementation is what changes.

**Never mark a criterion proven on reasoning alone.** Reading the code and concluding it must work
is `needs-manual`, not `proven-by-agent`. This is the same rule the data-access duel applies to an
unmeasured plan, and it is the only thing that makes the status worth anything.

## 3.6 Evidence

`quality.evidence` is `off` → skip; the statuses above still apply.

Capture what you observed into `.claude/work/<TICKET>/evidence/`, one file per criterion, named
after it (`ac2-campaign-filter-after.png`). Visual criterion → a screenshot; non-visual → the
response body, the log excerpt, the command output, saved as text.

**A criterion that changes something already visible needs a before.** Capture it on the base
branch, or from the pre-change state, *before* running the flow — a before taken after the change
does not exist, and inventing one is worse than having none. No before available → say so; the after
alone is still worth attaching.

`/flow:feat:ship` reads this folder to build the MR/PR's Evidence section.

## 3.7 Entry-point benchmark (before vs after)

Read `quality.bench_cmd` from `FLOW.md`. **Empty → say so in one line and skip.** The plugin ships
no benchmarking tool and invents no timings: with no command here, the phase makes no claim about
speed or memory at all.

Runs when the diff touches a **route, console command, consumer or job** — an entry point a
benchmark can address. Not for a change confined to code no entry point reaches differently.

1. **Pick the targets**: the entry points this diff actually changes, at most three. More than
   three → take the three the ticket is about and say which were skipped.
2. **Run on the base**: `git merge-base HEAD <git.default_base>`, checked out the way this repo
   already switches (`/flow:work:try` mechanics, or the existing worktree), then `quality.bench_cmd`
   with `{TARGET}` substituted, **three runs**.
3. **Run on `HEAD`**, same target, same input, same three runs, same machine state.
4. **Report `min–max`, never a mean**, for wall time and peak memory, plus whatever else the command
   emits.

**A difference inside the spread is "no measurable change".** Not a percentage, not "slightly
faster". A laptop running containers produces variance that reads as a 5% win, and a table that
publishes those wins is disbelieved within a fortnight — at which point the real regressions stop
being read too. When the times overlap, lead with the counts the run produced (queries executed,
rows read, allocations) — those are not noisy.

Base cannot be run (the entry point did not exist, the schema moved under it) → **not measured**
with the reason. A benchmark is never estimated from reading the diff.

## 4. Assisted manual verification (for `needs-manual` criteria)

`meta.json.worktree` not null (the runnable env lives in the main checkout) → offer once before verifying: "to test this branch against the main environment, run `/flow:work:try <meta.branch>` (it switches the main checkout and re-syncs per `git.worktree_resync`), and `/flow:work:try --back` to return afterwards." Suggest it; do not run it yourself and do not force it. **`/flow:work:try` §3.5 prints this same plan once the environment is up and can collect the verdicts there** — say so, so the user is not left to ask for it again on the other side.

Only the criteria §3.5 could not drive reach this loop, each with the recorded reason it could not.
Say which, and why, before asking anything — a user asked to verify what the agent could have done
itself learns to skip the question.

Verify `needs-manual` criteria **together with the user**, one or a few at a time — the user runs the flow, you keep the checklist until every criterion is accounted for:

1. For each `needs-manual` criterion, tell the user exactly what to do and what to observe, phrased from its given/when/then (e.g. "Open `/campaigns`, filter by last 7 days → the list should show only campaigns from the last 7 days, newest first").
2. Ask with `AskUserQuestion` — options **Pass** / **Fail** / **Blocked** (cannot test now). Batch up to 4 criteria per question.
3. Record each answer immediately in `07-validation.md` (§6 output, "Criteria coverage"):
   - **Pass** → status `proven-manually`, note the date.
   - **Fail** → status `unproven`; blocks the gate until the implementation is fixed and re-verified.
   - **Blocked** → status `unproven`; record why. Does not pass the gate.
4. Repeat until every `needs-manual` criterion is `proven-manually`, or the user decides to stop (the rest stay `unproven`, which blocks advancing in §7).

## 5. Manual edge cases

If the feature has UI or critical flows:
- Payments → test with the test cards or credentials the provider publishes for its sandbox (and the harness skill for that provider, if installed).
- Workers/queues → make sure no jobs are stuck in dead-letter. Stuck jobs that are not yours: do not touch them here.
- Migrations → run `quality.db_update` from `FLOW.md` (if defined); verify no unexpected schema difference with the comparison command the project uses.

## 6. Output

Write `.claude/work/<TICKET>/07-validation.md`:

```markdown
# Validation <TICKET>

## Criteria coverage
<one row per acceptance criterion from 03-design.md (S+; "N-A — XS" if the phase was skipped)>

| Criterion | Proof type | Test / confirmation | Evidence | Status |
|-----------|-----------|---------------------|----------|--------|
| AC1: <short> | test | `tests/Foo/BarTest::testX` | — | ✅ proven-by-test |
| AC2: <short> | agent | browser, `/campaigns?range=7d` | `evidence/ac2-*.png` | ✅ proven-by-agent |
| AC3: <short> | manual | confirmed by user 2026-06-24 | `evidence/ac3-after.png` | ✅ proven-manually |
| AC4: <short> | manual | — (§3.5: no simulator on this host) | — | ❌ unproven (blocked: staging down) |

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
- Entry-point benchmark (§3.7): <one row per target, or "no bench_cmd" / "no entry point touched">

  | Entry point | Time base → HEAD (min–max, 3 runs) | Peak memory base → HEAD | Verdict |
  |---|---|---|---|
  | `GET /campaigns` | 210–224 ms → 88–95 ms | 42–43 MB → 30–31 MB | improved |
  | `app:sync-contacts` | 1.8–2.4 s → 1.9–2.3 s | 120 MB → 121 MB | no measurable change |

- Queries measured: <per query — plan, index used, rows read, time (3 runs), and on what data set; "schema only" or "not measured" with the reason when there was no way to run it>
- Verdicts still unresolved from `06-review.md §Data-access duel`: <list, or "none">
- Open risks: …

## Edge cases verified
<`[x]` verified. Every `[ ]` left unchecked at Close carries an `F<n>` and a `meta.json.followups[]` entry (`kind: "edge-case"`, `source: "validate"`, flow-core §7) — an edge case nobody checked and nobody recorded is indistinguishable from one that does not exist. Same for anything left under "Open risks" above.>
- [x] …
- [ ] …

## Regressions
- Areas checked: …
- No regressions detected / detected: …
```

## 7. Close

- **Do not advance `phase`** if tests are red, regressions are found, or **any acceptance criterion is `unproven`** (no test demonstrably asserts it, and neither §3.5 nor the user confirmed it). The criterion→test mapping is part of the gate — the same "do not advance on red" rule. The user resolves the gap (add the missing test, fix the implementation, or finish the manual verification) and returns to `/flow:feat:validate`.
- Suite green **and** every acceptance criterion `proven-by-test`, `proven-by-agent` or `proven-manually` → `phase = "validate"`, add to `phases_done`. **Multi-MR/PR work** → also add `validate` to the current `in_progress` MR/PR's own `phases_done` (its `mrs[]` entry) — the per-MR/PR marker `/flow:feat:ship §1` gates on. Suggest `/flow:feat:ship`.
- **Record *what* you validated**, in the same write and only when the phase advances: `validated_sha` = `git rev-parse HEAD`, work-level and in this MR/PR's `mrs[]` entry. `/flow:feat:ship §1` reads it to tell "the suite passed here" from "the suite passed on something else".
- **Unchecked edge cases and open risks become `followups[]` entries** (flow-core §7) before advancing — see the output template above.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- **Autonomy handoff — this one stops in every mode, `auto` included.** `ship` pushes and opens the MR/PR: a hard gate in every mode, so do **not** chain into it. Stop here and propose `/flow:feat:ship` with a single `AskUserQuestion` (recommended option by default), invoking it only when the user confirms. This is the deliberate end of the unattended run.

In `guided`/`auto` this is, together with the brief in `/flow:feat:build §2`, **the only stop of the whole MR/PR** — everything between them ran unattended. It carries the **full stop header** and the body answers, in this order: what is green, what this MR/PR proves and what it does not, and what shipping it takes. Assume the user has read none of the build and review.
