# `/flow-feat-plan`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Delivery planning phase. **No code.** Decides how to split the feature into MRs/PRs that can live on the main branch independently even if the later ones never arrive.

## 1. Pre-flight

- Load `meta.json` by current branch. If it doesn't exist, send the user to `/flow-feat-start`.
- Require `design` in `phases_done`. If not, send to `/flow-feat-design` and stop.
- Read `01-context.md`, `02-brainstorm.md` (if it exists), and `03-design.md`.
- **If `size` is `XS` or `S`**: warn that this phase doesn't apply (always 1 MR/PR), mark `plan` as skipped in `phases_done` with value `"plan:skipped"`, and suggest `/flow-feat-build`. Stop.

## 2. Work

Load the project's convention skills (see `FLOW.md` section `conventions`).

**Before splitting, YAGNI filter on the design**: the plan only divides work that `03-design.md` already validated as necessary. If when splitting you see an MR/PR (or part of one) dedicated to a **hypothetical future problem** or to protecting against a scenario that **cannot happen in this project**, don't make it a deliverable: mark it as "out of scope — idea for a separate ticket" and flag it to the user.

Launch a subagent with the assignment (self-contained):

> Read `.claude/work/<TICKET>/03-design.md`. Propose how to split the implementation into **independently mergeable MRs/PRs**: each one must be able to live on the main branch without breaking anything even if the later ones never arrive. Think about feature flags, temporary dead code, schema backward-compatibility, live migrations in multiple steps, stable event contracts. **Do not create MRs/PRs dedicated to hypothetical future problems or defenses against scenarios the project already prevents — split only what's needed for what the ticket asks today (YAGNI).**
>
> Then build the **dependency graph** (which MR/PR needs another one merged or deployed before it can start) and **sort it topologically into execution waves**: wave 1 = everything with no unmet dependency (can start immediately, in parallel); wave 2 = everything unlocked once wave 1 is in; and so on. **Number the MRs/PRs following that wave order** — the lowest numbers to wave 1, then wave 2, etc. — so that **every MR/PR's dependencies have a strictly lower number than itself** (`#1` is always a valid starting point, never "start at #5"). Within a wave (parallel, no dependency between them) the order is free; number them consecutively. **The number is the execution order, not a grouping by feature area.**
>
> Return a table with: **`n`** (final number = execution order), **`wave`**, **`depends_on`** (list of the `n` it needs merged first; empty if it can start immediately), what it includes, mergeable alone (yes/no + how it's guaranteed), what it unlocks for the next one, risk if it stays alone on the main branch indefinitely, **`lines_est`** (approximate lines, sum of added + modified) and **`files_est`** (approximate files it touches). Estimates are **indicative** — they serve as a gauge during build, not as a contract. If the right answer is "1 single MR/PR", justify it and return that. Under 600 words.

If the feature touches payments, authentication, or sensitive data, launch **in parallel** the `agents.security` agent from `FLOW.md` (or general subagent if empty) assigned to: "For each proposed MR/PR in the delivery plan, identify whether it opens a security exposure window while the subsequent ones are not yet merged. Actionable only."

## 3. Output

Consolidate in `.claude/work/<TICKET>/04-mr-plan.md`:

```markdown
# Delivery plan <TICKET>

## Summary
- Number of MRs/PRs: N
- Justification for splitting (1-2 lines):

## Execution order (waves)
The number of each MR/PR **is** its execution order: a lower number never depends on a higher one, so `#1` is always a valid starting point.
- **Wave 1** (start now, in parallel): #1, #2
- **Wave 2** (after #1 is merged/deployed): #3, #4
- **Wave 3** (after #3): #5

MRs/PRs in the same wave with no dependency between them can be built in parallel (or as a train). There is no "start at #5" — if something can start first, it is numbered first.

## MRs/PRs

### #1: <short title>
- **Wave**: N — **depends on**: #a, #b (or "nothing — can start immediately").
- **Includes**: bullets of what changes.
- **Mergeable alone**: yes / no — how it's guaranteed (flag, nullable column, unused code, etc.).
- **Unlocks**: what it allows in the next one.
- **Risk if it stays alone on the main branch**: …
- **Estimated size**: XS / S / M.
- **`lines_est`**: ~N lines (added + modified).
- **`files_est`**: ~N files.

### #2: …

## Dependencies between MRs/PRs
<simple graph in bullets: #3 depends on migration from #1, etc. This graph is what produced the waves and the numbering above — keep them consistent.>

## Plan risks
- Live migrations:
- Compatibility with deployed clients:
- New domain events:
- Feature flags introduced (and when they're removed):

## Decision: one or multiple MRs/PRs?
<if 1: justification. If multiple: why this split and not another>
```

If the plan proposes 1 single MR/PR, keep the artifact the same with that single entry and the justification. Don't force artificial splitting.

## 4. Register in `meta.json`

Add the `mrs` array to `meta.json` with the agreed plan:

```json
"mrs": [
  { "n": 1, "title": "…", "size": "S", "status": "pending", "phases_done": [], "wave": 1, "depends_on": [], "lines_est": 120, "files_est": 6 },
  { "n": 2, "title": "…", "size": "M", "status": "pending", "phases_done": [], "wave": 2, "depends_on": [1], "lines_est": 350, "files_est": 14 }
]
```

`n` follows the execution order (topological): `depends_on` only ever references a **lower** `n`, and `wave` groups MRs/PRs that can run in parallel. `/flow-feat-build §1` reads `depends_on` to pick the next **startable** MR/PR and to tell the user which ones can go in parallel; keep both fields accurate whenever the plan is edited or renumbered.

Each entry starts with an empty **`phases_done`**: it tracks the phases (`build`/`review`/`validate`) completed **for that MR/PR specifically**, so the gates in `/flow-feat-review §1`, `/flow-feat-validate §1` and `/flow-feat-ship §1` judge *this* MR/PR — a sibling's review never satisfies a new MR/PR's gate. Leave it `[]` for every seeded entry.

Estimates are **indicative**, not contractual. `/flow-feat-build` uses them as a gauge: if the actual work exceeds +50% of `lines_est` or `files_est + 2`, it triggers the question to "cut or continue".

Valid statuses:

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started. |
| `in_progress` | Build/review/validate of this MR/PR is underway. |
| `merged` | MR/PR merged to the main branch. |
| `closed` | MR/PR closed without merging (rejected, discarded). Requires `note` with reason. |
| `superseded` | Replaced by a later MR/PR. Requires `note` pointing to the replacement. |

## 5. Is the size still right?

If when splitting you find it actually results in 1 single small MR/PR (≤ 50 lines, no migrations), reclassify to `S` and flag it. If on the other hand 5+ large MRs/PRs emerge, consider bumping to `L`. Confirm with the user before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "plan"`, add `plan` to `phases_done`.
- Show the user the summary table and ask for approval.
- If they request changes, edit the artifact and `meta.json.mrs` before advancing.
- Suggest `/flow-feat-build` to start the first MR/PR.
