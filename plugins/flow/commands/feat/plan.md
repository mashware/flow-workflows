---
description: Split the work into small, independently mergeable MRs/PRs before implementing
---

# `/feat:plan`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user.

Delivery planning phase. **No code is written.** Decides how to split the feature into MRs/PRs that can live on their own on the main branch even if the subsequent ones never land.

## 1. Pre-flight

- Load `meta.json` by current branch. If it does not exist, send the user to `/feat:start`.
- Require `design` in `phases_done`. If missing, send to `/feat:design` and stop.
- Read `01-context.md`, `02-brainstorm.md` (if it exists), and `03-design.md`.
- **If `size` is `XS` or `S`**: warn that this phase does not apply (always 1 MR/PR), mark `plan` as skipped in `phases_done` with value `"plan:skipped"`, and suggest `/feat:build`. Stop.

## 2. Work

Load the project convention skills (see `FLOW.md` section `conventions`).

**Before splitting, apply a YAGNI filter to the design**: the plan only divides work that `03-design.md` has already validated as necessary. If when splitting you see a MR/PR (or part of one) dedicated to a **hypothetical future problem** or to protecting against a scenario that **cannot happen in this project**, do not turn it into a deliverable: mark it as "out of scope — idea for a separate ticket" and notify the user. Do not split or plan what is not going to be built today. If this reveals that the design let in unnecessary pieces, return to `/feat:design` to trim them before planning.

Launch a subagent with this brief (self-contained):

> Read `.claude/work/<TICKET>/03-design.md`. Propose how to split the implementation into **independently mergeable MRs/PRs**: each one must be able to live on its own on the main branch without breaking anything even if the subsequent ones never land. Think about feature flags, temporary dead code, schema backwards-compatibility, multi-step online migrations, stable event contracts. **Do not create MRs/PRs dedicated to hypothetical future problems or to defenses against scenarios the project already prevents — split only what is necessary for what the ticket asks for today (YAGNI).** Table with: order, what it includes, standalone-mergeable (yes/no + how it is guaranteed), what it unlocks for the next one, risk if it stays alone on the main branch indefinitely, **`lines_est`** (approximate lines, sum of added + modified) and **`files_est`** (approximate files it touches). Estimates are **soft** — they serve as a thermometer during build, not as a contract. If the correct answer is "1 single MR/PR", justify it and return that. Under 500 words.

If the feature touches payments, authentication, or sensitive data, launch **in parallel** the `agents.security` agent from `FLOW.md` (or `Agent general-purpose` if empty) with the brief: "For each proposed MR/PR in the delivery plan, identify whether it opens a security exposure window while the subsequent ones are not yet merged (e.g. new endpoint without the final check, column without final constraint). Only actionable findings."

## 3. Output

Consolidate in `.claude/work/<TICKET>/04-mr-plan.md`:

```markdown
# Delivery plan <TICKET>

## Summary
- Number of MRs/PRs: N
- Split justification (1-2 lines):
- Recommended order: #1 → #2 → …

## MRs/PRs

### #1: <short title>
- **Includes**: bullets of what changes.
- **Standalone-mergeable**: yes / no — how it is guaranteed (flag, nullable column, unused code, etc.).
- **Unlocks**: what the next one can do.
- **Risk if it stays alone on the main branch**: …
- **Estimated size**: XS / S / M.
- **`lines_est`**: ~N lines (added + modified).
- **`files_est`**: ~N files.

### #2: …

## Dependencies between MRs/PRs
<simple graph in bullets: #2 depends on migration from #1, etc.>

## Plan risks
- Online migrations:
- Compatibility with deployed clients:
- New domain events:
- Introduced feature flags (and when to remove them):

## Decision: one or several MRs/PRs?
<if 1: justification. If several: why this split and not another>
```

If the plan proposes 1 single MR/PR, keep the artifact the same with that single entry and justification. Do not force artificial splitting.

## 4. Register in `meta.json`

Add to `meta.json` the `mrs` array with the agreed plan:

```json
"mrs": [
  { "n": 1, "title": "…", "size": "S", "status": "pending", "lines_est": 120, "files_est": 6 },
  { "n": 2, "title": "…", "size": "M", "status": "pending", "lines_est": 350, "files_est": 14 }
]
```

Estimates are **indicative**, not contractual. `/feat:build` uses them as a thermometer: if real work exceeds `lines_est` by +50% or `files_est + 2`, it triggers the "cut or continue" question (see §C in build).

Valid statuses:

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started. |
| `in_progress` | Build/review/validate for this MR/PR is in progress. |
| `merged` | MR/PR merged to the main branch. |
| `closed` | MR/PR closed without merge (rejected, discarded). Requires `note` with reason. |
| `superseded` | Replaced by a later MR/PR (the plan was rethought). Requires `note` pointing to the replacement. |

`/feat:build` moves `pending` → `in_progress`. `/feat:ship` moves `in_progress` → `merged` when it confirms the merge, or to `closed` if discarded. If after a build the splitting needs to be rethought, return to `/feat:plan`, mark the old entry as `superseded`, and add the new ones.

## 5. Is the size still correct?

If when splitting you find that there is really just 1 small MR/PR (≤ 50 lines, no migrations), reclassify to `S` and notify. Conversely, if 5+ large MRs/PRs come out, consider upgrading to `L`. Confirm with `AskUserQuestion` before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "plan"`, add `plan` to `phases_done`.
- Show the user the summary table and ask for approval.
- If they request changes, edit the artifact and `meta.json.mrs` before advancing.
- Suggest `/feat:build` to start the first MR/PR.
