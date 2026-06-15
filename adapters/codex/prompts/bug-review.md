# `/bug-review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user.

- Load `meta.json`. Require `fix` in `phases_done`. For `size` ≥ S also require `validate`.
- If `git diff` shows no changes, warn and stop.

## 2. Invoke the two code reviews

Launch **both** over the fix scope against the base (committed + uncommitted working tree) and **consolidate their findings into a single deduplicated report**:

1. **Correctness review**: one pass over the local diff: correctness bugs + simplification/efficiency, at high effort.
2. **Skill `quality.review_skill` from FLOW.md**: invoke it as `<review_skill> branch`. If `quality.review_skill` is empty and `quality.reviewers` has entries, launch those subagents in parallel as a review panel. If both are empty, the review in point 1 already covers this pass.

Deduplicate overlaps. Specific fix focus in addition to the generic analysis:
- The change must actually resolve the problem from `02-diagnose.md` / `03-investigation.md`.
- There must be no expanded scope (hidden refactor). If there is, list it.
- The regression test from `05-validation.md` must cover the case.

Pass as context: `03-investigation.md` and `04-fix.md`.

## 3. Reinforcements by area

Only what the §2 skill doesn't already cover. Launch additionally in parallel if applicable:

- DB / queries → `agents.performance` agent from FLOW.md; if empty, use a general subagent with a performance role.
- Workers / failure queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence; if empty, general subagent with a messaging role.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also sneak in unnecessary defenses. Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"what real and present scenario in the project justifies this?"*. Verify against the code — can the flow actually reach that state, or is there something that already prevents it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` if it depends on domain rules.
- A fix must be **minimal**: anything that doesn't directly address the root cause goes to Blockers with a proposed cut.

## 4.5. Completeness check (M/L, no loop)

A fix is minimal by design, so here one check is enough. **M/L only**: after consolidating findings from §2-§3, compare `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file from the fix wasn't looked at by any reviewer, give it a targeted pass and merge any new findings.

## 5. Adversarial finding verification (optional M/L)

If `meta.json.size` is **M or L** and there are **≥ 4** findings across blockers and suggestions, offer the user to filter them with a parallel skeptics panel (3 skeptics per finding, with a refute-by-default instruction; survives if fewer than 2 refute it). Discarded ones are noted under "Discarded by verification" with the reason. Not offered for XS/S or with fewer than 4 findings.

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
- Reviewers launched: …
- Blockers: N
- Suggestions: M

## Does the fix actually resolve the failure?
- Yes / No / Partial — explain

## Is there expanded scope outside the failure?
- Yes (list and propose moving to another ticket) / No

## Over-engineering (fit + YAGNI)
- New defensive mechanisms in the fix: <list, or "none">
- Without a real scenario to justify them: <list, or "none">

## Is the regression test adequate?
- Yes / No (what's missing)

## Discarded by adversarial verification
<only if §5 was run; refuted findings with reason, or "not applicable">

## Blockers
1. [file:line] …

## Suggestions
1. …
```

## 8. Close

- With blockers: `phase` stays at `validate`. Iterate.
- Without blockers: `phase = "review"`, add to `phases_done`. Suggest `/bug-postmortem` (M/L) or `/bug-ship` (XS/S).
