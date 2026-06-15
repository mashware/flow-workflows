# `/feat-plan`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Delivery planning phase. **No code.** Decides how to split the feature into MRs/PRs that can live on the main branch independently even if the later ones never arrive.

## 1. Pre-flight

- Load `meta.json` by current branch. If it doesn't exist, send the user to `/feat-start`.
- Require `design` in `phases_done`. If not, send to `/feat-design` and stop.
- Read `01-context.md`, `02-brainstorm.md` (if it exists), and `03-design.md`.
- **If `size` is `XS` or `S`**: warn that this phase doesn't apply (always 1 MR/PR), mark `plan` as skipped in `phases_done` with value `"plan:skipped"`, and suggest `/feat-build`. Stop.

## 2. Work

Load the project's convention skills (see `FLOW.md` section `conventions`).

**Before splitting, YAGNI filter on the design**: the plan only divides work that `03-design.md` already validated as necessary. If when splitting you see an MR/PR (or part of one) dedicated to a **hypothetical future problem** or to protecting against a scenario that **cannot happen in this project**, don't make it a deliverable: mark it as "out of scope — idea for a separate ticket" and flag it to the user.

Launch a subagent with the assignment (self-contained):

> Read `.claude/work/<TICKET>/03-design.md`. Propose how to split the implementation into **independently mergeable MRs/PRs**: each one must be able to live on the main branch without breaking anything even if the later ones never arrive. Think about feature flags, temporary dead code, schema backward-compatibility, live migrations in multiple steps, stable event contracts. **Do not create MRs/PRs dedicated to hypothetical future problems or defenses against scenarios the project already prevents — split only what's needed for what the ticket asks today (YAGNI).** Table with: order, what it includes, mergeable alone (yes/no + how it's guaranteed), what it unlocks for the next one, risk if it stays alone on the main branch indefinitely, **`lines_est`** (approximate lines, sum of added + modified) and **`files_est`** (approximate files it touches). Estimates are **indicative** — they serve as a gauge during build, not as a contract. If the right answer is "1 single MR/PR", justify it and return that. Under 500 words.

If the feature touches payments, authentication, or sensitive data, launch **in parallel** the `agents.security` agent from `FLOW.md` (or general subagent if empty) assigned to: "For each proposed MR/PR in the delivery plan, identify whether it opens a security exposure window while the subsequent ones are not yet merged. Actionable only."

## 3. Output

Consolidate in `.claude/work/<TICKET>/04-mr-plan.md`:

```markdown
# Delivery plan <TICKET>

## Summary
- Number of MRs/PRs: N
- Justification for splitting (1-2 lines):
- Recommended order: #1 → #2 → …

## MRs/PRs

### #1: <short title>
- **Includes**: bullets of what changes.
- **Mergeable alone**: yes / no — how it's guaranteed (flag, nullable column, unused code, etc.).
- **Unlocks**: what it allows in the next one.
- **Risk if it stays alone on the main branch**: …
- **Estimated size**: XS / S / M.
- **`lines_est`**: ~N lines (added + modified).
- **`files_est`**: ~N files.

### #2: …

## Dependencies between MRs/PRs
<simple graph in bullets: #2 depends on migration from #1, etc.>

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
  { "n": 1, "title": "…", "size": "S", "status": "pending", "lines_est": 120, "files_est": 6 },
  { "n": 2, "title": "…", "size": "M", "status": "pending", "lines_est": 350, "files_est": 14 }
]
```

Estimates are **indicative**, not contractual. `/feat-build` uses them as a gauge: if the actual work exceeds +50% of `lines_est` or `files_est + 2`, it triggers the question to "cut or continue".

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
- Suggest `/feat-build` to start the first MR/PR.
