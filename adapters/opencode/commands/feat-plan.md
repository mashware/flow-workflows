---
description: Break the work into small, independently mergeable MRs/PRs before implementing
---

# `/feat-plan`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Delivery planning phase. **No code is written here.** Decide how to split the feature into MRs/PRs that can live on their own on the main branch even if the following ones never arrive.

## 1. Pre-flight

- Load `meta.json` for the current branch. If it doesn't exist, send the user to `/feat-start`.
- Require `design` in `phases_done`. If missing, send to `/feat-design` and stop.
- Read `01-context.md`, `02-brainstorm.md` (if it exists), and `03-design.md`.
- **If `size` is `XS` or `S`**: warn that this phase doesn't apply (always 1 MR/PR), mark `plan` as skipped in `phases_done` with value `"plan:skipped"`, and suggest `/feat-build`. Stop.

## 2. Work

Load the project conventions (see `FLOW.md` section `conventions`).

**Before splitting, apply a YAGNI filter to the design**: the plan only breaks down work that `03-design.md` has already validated as necessary. If while splitting you spot an MR/PR (or part of one) dedicated to a **hypothetical future problem** or to defending against a scenario **that cannot occur in this project**, don't make it a deliverable: mark it as "out of scope — idea for a separate ticket" and alert the user. Don't split or plan what won't be built today. If this reveals that the design let extra pieces through, go back to `/feat-design` to trim them before planning.

Launch a sub-agent with this self-contained task:

> Read `.claude/work/<TICKET>/03-design.md`. Propose how to split the implementation into **independently mergeable MRs/PRs**: each one must be able to live on its own on the main branch without breaking anything even if the following ones never arrive. Think about feature flags, temporary dead code, schema backward compatibility, multi-step online migrations, stable event contracts. **Do not create MRs/PRs dedicated to hypothetical future problems or defenses against scenarios the project already prevents — split only what the ticket needs today (YAGNI).** Table with: order, what it includes, independently mergeable (yes/no + how it's guaranteed), what it unblocks in the next one, risk if it stays alone on the main branch indefinitely, **`lines_est`** (approximate lines, sum of added + modified) and **`files_est`** (approximate files touched). Estimates are **soft** — they serve as a gauge during construction, not a contract. If the right answer is "1 single MR/PR", justify it and return that. Under 500 words.

If the feature touches payments, authentication, or sensitive data, launch **in parallel** the security sub-agent from `FLOW.md` (or a general-purpose sub-agent if empty) with this task: "For each proposed MR/PR in the delivery plan, identify whether it opens a security exposure window while the following ones aren't merged yet (e.g. new endpoint without its final check, column without its final constraint). Actionable items only."

## 3. Output

Consolidate into `.claude/work/<TICKET>/04-mr-plan.md`:

```markdown
# Delivery plan <TICKET>

## Summary
- Number of MRs/PRs: N
- Split rationale (1-2 lines):
- Recommended order: #1 → #2 → …

## MRs/PRs

### #1: <short title>
- **Includes**: bullets of what changes.
- **Independently mergeable**: yes / no — how it's guaranteed (flag, nullable column, unused code, etc.).
- **Unblocks**: what the next one can do.
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
- Feature flags introduced (and when they're removed):

## Decision: one or several MRs/PRs?
<if 1: justification. If several: why this split and not another>
```

If the plan proposes 1 single MR/PR, keep the artifact the same with that single entry and the justification. Don't force artificial splits.

## 4. Record in `meta.json`

Add to `meta.json` the `mrs` array with the agreed plan:

```json
"mrs": [
  { "n": 1, "title": "…", "size": "S", "status": "pending", "lines_est": 120, "files_est": 6 },
  { "n": 2, "title": "…", "size": "M", "status": "pending", "lines_est": 350, "files_est": 14 }
]
```

Estimates are **indicative**, not contractual. `/feat-build` uses them as a gauge: if real work exceeds `lines_est` by +50% or `files_est + 2`, it triggers the "cut or continue" question (see §C of build).

Valid statuses:

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started. |
| `in_progress` | Construction/review/validation of this MR/PR is underway. |
| `merged` | MR/PR merged to the main branch. |
| `closed` | MR/PR closed without merging (rejected, discarded). Requires `note` with reason. |
| `superseded` | Replaced by a later MR/PR (the plan was revised). Requires `note` pointing to the replacement. |

`/feat-build` moves `pending` → `in_progress`. `/feat-ship` moves `in_progress` → `merged` when it confirms the merge, or to `closed` if discarded. If after a build the split needs to be revised, go back to `/feat-plan`, mark the old entry as `superseded`, and add the new ones.

## 5. Is the size still correct?

If while splitting you find that there's really only 1 small MR/PR (≤ 50 lines, no migrations), reclassify to `S` and warn the user. If on the other hand you get 5+ large MRs/PRs, consider upgrading to `L`. Confirm with the user before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "plan"`, add `plan` to `phases_done`.
- Show the user the summary table and ask for approval.
- If changes are requested, edit the artifact and `meta.json.mrs` before proceeding.
- Suggest `/feat-build` to start the first MR/PR.
