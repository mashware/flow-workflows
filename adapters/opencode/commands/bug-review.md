---
description: Multi-agent code review of the fix before shipping
---

# `/bug-review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Load `meta.json`. Require `fix` in `phases_done`. For `size` ≥ S also require `validate`.
- If `git diff` shows no changes, warn and stop.

## 2. Run both code reviews

Launch **both** over the fix scope against the base (committed + uncommitted working tree) and **consolidate their findings into a single deduplicated report**:

1. **Integrated review**: run a full pass over the local diff looking for correctness bugs + simplification/efficiency issues, at high effort. If the tool has a built-in review skill or command, use it; otherwise perform the review yourself.
2. **`quality.review_skill` from FLOW.md**: invoke it as a skill, passing `03-investigation.md` and `04-fix.md` as context. If `quality.review_skill` is empty and `quality.reviewers` has entries, launch those sub-agents in parallel as a review panel. If both are empty, rely on the integrated review already run in step 1.

Deduplicate overlaps (correctness/simplification flagged by both — count once). Fix-specific focus beyond the generic analysis:
- The change must actually resolve the problem described in `02-diagnose.md` / `03-investigation.md`.
- There must be no scope creep (hidden refactor). If there is, list it.
- The regression test in `05-validation.md` must cover the case.

## 3. Additional checks by area

Only what the skill in §2 does not already cover. Launch additionally in parallel if applicable:

- DB / queries → sub-agent from `agents.performance` in FLOW.md; if empty, use a general-purpose sub-agent with a performance role in the prompt.
- Workers / failure queue → sub-agent from `agents.queues` in FLOW.md to confirm the fix prevents recurrence; if empty, use a general-purpose sub-agent with a messaging role in the prompt.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also sneak in excessive defenses ("while I'm fixing this, I'll add a retry/guard/fallback just in case"). Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"What real, present scenario in this project justifies it?"* Verify against the code — can the flow actually reach that state, or is something already preventing it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` when domain rules are involved.
- A fix must be **minimal**: anything that does not directly attack the root cause from `03-investigation.md` and does not address a present scenario is unnecessary. Goes to Blockers with a proposal to cut it.

## 4.5. Completeness check (M/L only, no loop)

A fix is minimal by design (§4), so here **one** check is enough — no loop. **M/L only**: after consolidating findings from §2-§3, compare `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file in the fix was not examined by any reviewer, give it a targeted pass with the relevant reviewer and merge the findings. If the diff is small (normal for a fix), this resolves in seconds or does not apply.

## 5. Adversarial verification of findings (parallel sub-agents, optional M/L)

Same as `/feat-review` §6: if `meta.json.size` is **M or L** and there are **≥ 4** findings across blockers and suggestions, offer the user a filter pass with a parallel panel of skeptics (3 skeptics per finding, refute-by-default, survives if fewer than 2 refute it). Discarded findings are removed from the list and noted in the output under "Discarded by verification" with the reason. Not offered for XS/S or with fewer than 4 findings.

## 6. Quality gates

Use the commands from `quality` in FLOW.md; if empty, auto-discover:

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
- Sub-agents launched: …
- Blockers: N
- Suggestions: M

## Does the fix actually resolve the bug?
- Yes / No / Partial — explain

## Is there scope creep beyond the bug?
- Yes (list and propose moving to another ticket) / No

## Over-engineering (fit + YAGNI)
- New defensive mechanisms in the fix: <list, or "none">
- No real scenario justifying them: <list, or "none">

## Is the regression test adequate?
- Yes / No (what is missing)

## Discarded by adversarial verification
<only if §5 ran; refuted findings with their reason, or "n/a">

## Blockers
1. [file:line] …

## Suggestions
1. …
```

## 8. Close

- With blockers: `phase` stays at `validate`. Iterate.
- Without blockers: `phase = "review"`, add to `phases_done`. Suggest `/bug-postmortem` (M/L) or `/bug-ship` (XS/S).
