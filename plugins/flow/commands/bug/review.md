---
description: Multi-agent code review of the fix before submitting
---

# `/flow:bug:review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`. Require `fix` in `phases_done`. For `size` ≥ S also require `validate`.
- If `git diff` shows no changes, warn and stop.

## 2. Run the code reviews

Scope for every reviewer below: the fix against the base (committed + uncommitted working tree).

### 2.0 Resolve review depth (scale to the work size)
Read `quality.review_depth` from `FLOW.md` (`proportional` | `full`; empty → `proportional`) and `meta.json.size`. A minimal fix does not need a full specialized panel:

- **`full`** (any size): built-in `code-review` (high) + the project panel. Pre-0.7 behavior; skip the tiering below.
- **`proportional`** (default), by size:
  - **XS**: built-in `code-review` **only**, at **medium** effort. No project panel.
  - **S**: built-in `code-review` at **high** effort. Project panel **only if** the diff touches a **sensitive surface** (auth/authorization, secrets, payments/billing, personal/sensitive data, a public API/contract shape, or a DB migration/schema change); otherwise built-in only.
  - **M** / **L**: built-in `code-review` (high) + the project panel.

Record in `06-review.md` which tier ran and why. Note fixes skew XS/S, so most fixes get the built-in pass alone.

### 2.1 Launch and consolidate
Launch the reviewers selected in §2.0 and **consolidate their findings into a single deduplicated report**:

1. **Built-in `code-review`** (the Claude Code one, no prefix), at the effort resolved in §2.0. Single pass over the local diff: correctness issues + simplification/efficiency.
2. **Project panel** (only when §2.0 selected it): skill `quality.review_skill` from FLOW.md, invoked as `<review_skill> branch`. If `quality.review_skill` is empty and `quality.reviewers` has entries, launch those agents in parallel as a review panel. If both are empty, the built-in `code-review` above is the whole review.

Deduplicate overlaps (correctness/simplification flagged by both; count once). Specific focus for the fix beyond generic analysis:
- The change must genuinely resolve the problem from `02-diagnose.md` / `03-investigation.md`.
- There must be no expanded scope (hidden refactor). If there is, list it.
- The regression test from `05-validation.md` must cover the case.

Pass as context: `03-investigation.md` and `04-fix.md`.

## 3. Reinforcements by area

Only what the skill in §2 does not already cover. Launch additionally in parallel if applicable:

- DB / queries → `agents.performance` agent from FLOW.md; if empty, use `Agent general-purpose` with a performance role in the prompt.
- Workers / dead-letter queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence; if empty, use `Agent general-purpose` with a messaging role in the prompt.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also smuggle in excess defenses ("since I'm fixing this, I'll add a retry/guard/fallback just in case"). Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"What real, present scenario in this project justifies it?"*. Verify against the code — can the flow actually reach that state, or is there already something that prevents it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` if it depends on domain rules.
- A fix must be **minimal**: anything that does not directly attack the root cause from `03-investigation.md` and does not respond to a present scenario is unnecessary. Add to Blockers with a trim proposal.

## 4.5. Completeness check (M/L, no loop)

A fix is minimal by design (§4), so here **one** check is enough — no loop. **M/L only**: after consolidating findings from §2-§3, contrast `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file from the fix was not looked at by any reviewer, give it a targeted pass with the applicable reviewer and merge. If the diff is small (normal for a fix), this resolves in seconds or does not apply.

## 5. Adversarial finding verification (Workflow, optional M/L)

Same as `/flow:feat:review` §6: if `meta.json.size` is **M or L** and there are **≥ 4** findings across blockers and suggestions, offer with `AskUserQuestion` to filter them with a panel of skeptics in parallel (same `Workflow` script `review-verify`: 3 skeptics per finding, refute-by-default, survives if fewer than 2 refute it). Discarded findings are removed from the list and noted in the output under "Discarded by verification" with the reason. Not offered for XS/S or with fewer than 4 findings.

## 6. Quality gates

Use the `quality` commands from FLOW.md; if empty, auto-discover:

```
<quality.style_fix>
<quality.static_analysis>
<quality.test_one> (regression test)
```

## 7. Output

`.claude/work/<TICKET>/06-review.md`:

```markdown
# Fix review {TICKET}

## Summary
- Review tier: <full | proportional — which reviewers ran and why, per §2.0>
- Agents launched: …
- Blockers: N
- Suggestions: M

## Does the fix actually resolve the bug?
- Yes / No / Partial — explain

## Is there expanded scope beyond the bug?
- Yes (list and propose moving to another ticket) / No

## Over-engineering (fit + YAGNI)
- New defensive mechanisms in the fix: <list, or "none">
- Without a real scenario to justify them: <list, or "none">

## Is the regression test adequate?
- Yes / No (what is missing)

## Discarded by adversarial verification
<only if §5 was run; refuted findings with their reason, or "not applicable">

## Blockers
1. [file:line] …

## Suggestions
1. …
```

## 8. Close

- With blockers: `phase` stays at `validate`. Iterate.
- Without blockers: `phase = "review"`, add to `phases_done`. Suggest `/flow:bug:postmortem` (M/L) or `/flow:bug:ship` (XS/S).
