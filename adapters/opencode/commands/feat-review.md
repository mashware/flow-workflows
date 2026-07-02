---
description: Mandatory multi-agent code review before pushing
---

# `/feat-review`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Mandatory review phase. **`/feat-ship` cannot run without passing through here and resolving blockers.**

## 1. Pre-flight

- Load `meta.json`. Require `build` in `phases_done`. If missing, send the user to `/feat-build` and stop.
- Check that `git diff` has real changes. If there are none, warn and stop.

## 2. Run the code reviews

Launch **both** over the same scope and **consolidate their findings into a single deduplicated report**. Scope: the complete feature work against the base branch (committed + working tree, because commits are opt-in and there may be uncommitted changes).

1. **Integrated review**: run a full pass over the local diff looking for correctness bugs + reuse/simplification/efficiency, at high effort. If the tool has a built-in code review skill or command, use it; otherwise perform the review yourself.
2. **Project panel**: read `quality.review_skill` from `FLOW.md`.
   - If `review_skill` has a value: invoke that skill passing `03-design.md` as additional context. Scope: `git diff <git.default_base>...HEAD`; if there are uncommitted working tree changes, make sure they're included.
   - If `review_skill` is empty but `quality.reviewers` has entries: launch each `@name` sub-agent from that list in parallel as a panel, with the same context and scope.
   - If both are empty: the pass from point 1 already covers this review; nothing additional is launched.

Both overlap on correctness and simplification: deduplicate those findings (count each once). Specific reviewers contributed by `review_skill` (offensive/defensive security, silent failures, architecture) should not be repeated in later phases.

## 3. Reinforcements by area

Only what the §2 skill **doesn't** already cover. If the feature touches specific areas, additionally launch **in parallel**:

- DB / heavy queries → use the `agents.performance` sub-agent from `FLOW.md` on the changed files; if empty, skip this reinforcement.
- Workers / message queues → use the `agents.queues` sub-agent from `FLOW.md` to verify there's no `flush()` in a loop and that workers are registered with the project convention (see `FLOW.md` section `conventions`); if empty, skip this reinforcement.
- Frontend → if there are UI code changes, use the `agents.frontend` sub-agent from `FLOW.md`; if there are also affected frontend tests, use `agents.frontend_test` as well; if either is empty, skip that reinforcement.

## 3.5. Completeness sweep (anti-abandonment, M/L only)

A reviewer with a large diff tends to **abandon early**: covers the obvious parts of the first files, summarizes the rest as "no issues" and declares done. This pass corrects that structurally. **Only if `meta.json.size` is M or L** (in XS/S the diff fits in a single pass and this adds nothing).

Loop, maximum **2 rounds**:

1. **Work list**: `git diff --stat <git.default_base>...HEAD` → list of changed files/areas.
2. **Coverage map**: from the consolidated findings of §2-§3, mark which files/areas received at least one finding or were explicitly examined.
3. **Completeness critic (1 sub-agent, biased)**: launch it passing **only** two things: the complete list of diff files (step 1) and, for each reviewer from §2-§3, one line describing what each covered. **Don't** pass the detailed findings or the design — its only job is to detect gaps, not to opine on what's already been seen. Prompt:

   > You are a coverage auditor for a code review. I give you (1) the list of files changed in this diff and (2) a one-line summary per reviewer of what area each covered. Your only task: name the files or areas in the diff that **no** reviewer examined, and any claim a reviewer accepted without verifying. Don't opine on existing findings. Output: list of concrete gaps (`file/area` + why it deserves a second look) or exactly "none". Under 150 words.

4. **If fresh gaps are named**: re-launch a targeted round **only for those files/areas** with the applicable `quality.review_skill` reviewers (restrict their paths to the gaps). Merge the new findings and deduplicate them against the already-consolidated ones.
5. **Repeat 2-4** until a round returns "none" fresh gaps **or** 2 rounds are reached.
6. **No silent truncation**: if after 2 rounds the critic still points to uncovered areas, **record them literally** in the output under "Areas not covered after 2 rounds" with their reason.

Fresh findings from this sweep enter the normal flow: they go through §4 (over-engineering), §5 (contracts), and §6 (adversarial verification) like any other finding.

## 4. Over-engineering audit (fit + YAGNI)

**Second barrier against over-engineering** (the first is the challenger in `/feat-design`). Independent of the multi-agent code review: here we look at the diff for what **doesn't belong**, not what's missing.

1. **Locate every defensive mechanism in the diff**: validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker, queue, flag, retry.
2. **For each one, find its row** in the "Defensive mechanisms and their justification" table in `03-design.md`.
   - **If it has no row**: blocker. It slipped through without passing the design filter. Question: what real, present scenario in the project justifies it?
   - **If it has a row but the scenario is hypothetical** ("just in case", "it could happen that…", "in the future"): blocker type "doesn't belong".
3. **Verify the scenario against the code, not the document**: can the flow actually reach that state? Is there an upstream that already prevents it? If `domain_memory.enabled` is `true`, query `mcp__domain-memory__search_knowledge` if the scenario depends on domain rules.
4. **Key question per piece**: *"if I remove this, what breaks in the project — today, not in some hypothetical future?"*. If the honest answer is "nothing that could realistically happen", it's an over-engineering finding.

"Doesn't belong" findings go to Blockers with a concrete proposal: "remove X — protects against Y, which cannot occur because Z (evidence)".

## 5. Double-blind contract verification

If `05-implementation.md` has a "Contracts to respect" section, launch a general-purpose sub-agent with a **deliberately biased** prompt: it receives only two things, nothing more, nothing less.

> You are a contract reviewer. You must say whether the diff fulfills some literal contracts I'll give you. **You have no access to the rest of the design, the controller context, the brief, or the implementation explanations.** Only:
>
> 1. **Contracts to respect** (copied verbatim from the design):
>    <PASTE here the "Contracts to respect" section from `05-implementation.md` as-is, without reformatting>
>
> 2. **Diff of relevant files**: the shape constructions (JSON arrays, JsonSerializable, events, headers, routes, columns, metrics) from the changed files:
>    <PASTE here only the diff hunks that touch shape construction, not the whole file>
>
> Your only task: for **each contract** in block 1, tell me whether the code in block 2 produces **exactly** that shape — key by key, nesting by nesting, same case, same singular/plural. Output: table `| Contract | Matches (yes/no) | If no: what differs |`. Under 200 words. Don't rationalize mismatches ("maybe they meant X"): if it differs, say so.

Why biased: if you pass the full code or full design, the sub-agent rationalizes the mismatch by reading nearby justifications. By biasing it to "literal contract vs what the diff emits", the comparison stays textual.

Any "no" in the table → blocker. Pass it to the output as a broken contract finding with the concrete fix proposal.

If `05-implementation.md` doesn't have "Contracts to respect" (build recorded "N/A"), skip this step.

## 6. Adversarial finding verification (parallel sub-agents, optional M/L)

Reviewers tend to **over-report**: a "plausible" finding isn't always real, and fixing false positives costs time and can worsen the code. If `meta.json.size` is **M or L** and the total of blockers + suggestions from §2-§5 is **≥ 4**, offer the user to filter them ("Want to verify the findings with a panel of skeptics in parallel? Discard false positives before you take them to fix."). If they accept, launch parallel skeptic sub-agents:

For each finding `{id, file, description, proposal}`, launch 3 independent sub-agents with the same prompt:

> You are a skeptic. Code review finding in the project:
> File: {file}
> Problem: {description}
> Proposal: {proposal}
>
> Try to REFUTE it: read the actual code and say whether the problem is NOT real (refuted=true) or it is (refuted=false). When in doubt, refute — the burden of proof is on the finding. Be concrete about why.

A finding **survives** if fewer than 2 of the 3 skeptics refute it. **Discarded** findings (≥2 skeptics refute them) are removed from the blockers/suggestions list and noted in the output under "Discarded by verification" with the reason. This is not offered for XS/S or with fewer than 4 findings: the cost doesn't justify it.

## 7. Local quality gates

Read `quality.*` from `FLOW.md`. If empty, auto-discover equivalent commands (Makefile, npm/composer scripts) and report what you use.

Launch in parallel (in the background if they take a while):
- `quality.style_fix`
- `quality.static_analysis`
- `quality.test_one` (if there are new tests, with the appropriate filter)

Collect the results.

## 8. Output

Write `.claude/work/<TICKET>/06-review.md`:

```markdown
# Code review <TICKET>

## Summary
- Sub-agents launched: …
- Completeness rounds (M/L): N
- Critical findings (block ship): N
- Suggestion findings: M

## Areas not covered after 2 rounds
<only if §3.5 had remaining gaps after the limit; literal list with reason, or "none">

## Double-blind contract verification
- Contracts compared: N
- Mismatches: <list or "none">

## Over-engineering (fit + YAGNI)
- Defensive mechanisms in the diff: <list>
- Without justification in `03-design.md` or with hypothetical scenario: <list, or "none">
- Trim proposal: <what to remove and why, or "nothing to trim">

## Discarded by adversarial verification
<only if §6 was run; list of refuted findings with their reason, or "not applicable">

## Blockers (must-fix)
1. [file:line] description + concrete proposal

## Suggestions (nice-to-have)
1. [file:line] description

## Quality gates
- style_fix: ✅ / ❌
- static_analysis: ✅ / ❌
- modified tests: ✅ / ❌

## Next step
<if there are blockers: "resolve and return to /feat-review">
<if none: "/feat-validate">
```

## 9. Close

- If there are blockers: **don't advance `phase`**. Leave `phase = "build"` and let the user resolve them.
- If there are no blockers: `phase = "review"`, add to `phases_done`.
- Summarize findings and next step to the user.
