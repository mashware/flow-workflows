---
description: Mandatory multi-agent code review before shipping
---

# `/flow:feat:review`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Mandatory review phase. **`/flow:feat:ship` cannot run without passing through here and resolving blockers.**

## 1. Pre-flight

- Load `meta.json`. Require `build` in `phases_done`. If missing, send the user to `/flow:feat:build` and stop.
- Check that `git diff` has real changes. If there are none, warn and stop.

## 2. Invoke the code reviews

Scope for every reviewer below: the full feature work against the base branch (committed + working tree, because commits are opt-in and there may be uncommitted changes).

### 2.0 Resolve review depth (scale to the work size)
Read `quality.review_depth` from `FLOW.md` (`proportional` | `full`; empty → `proportional`) and `meta.json.size`. This decides **what §2.1 launches** — a handful of changed lines does not need a full specialized panel, and running one over a tiny diff is almost pure latency:

- **`full`** (any size): run both the built-in `code-review` (high effort) and the project panel. This is the pre-0.7 behavior; skip the tiering below.
- **`proportional`** (default), by size:
  - **XS**: built-in `code-review` **only**, at **medium** effort. Do **not** launch the project panel (`review_skill`/`reviewers`).
  - **S**: built-in `code-review` at **high** effort. Launch the project panel **only if** the diff touches a **sensitive surface** — authentication/authorization, secrets/credentials, payments/billing, personal or otherwise sensitive data, a public API/contract shape, or a DB migration/schema change. If it does not, the built-in `code-review` alone is the review.
  - **M** / **L**: built-in `code-review` (high) + the full project panel (as below).

Record in `06-review.md` which tier ran and why (e.g. "S, no sensitive surface → built-in only").

### 2.1 Launch and consolidate
Launch the reviewers selected in §2.0 and **consolidate their findings into a single deduplicated report**:

1. **Built-in `code-review`** (the Claude Code one, no prefix), at the effort resolved in §2.0. Single pass over the local diff: correctness failures + reuse/simplification/efficiency.
2. **Project panel** (only when §2.0 selected it): read `quality.review_skill` from `FLOW.md`.
   - If `review_skill` has a value: invoke that skill passing `03-design.md` as additional context. Scope: `git diff <git.default_base>...HEAD`; if there are uncommitted working tree changes, make sure they are included.
   - If `review_skill` is empty but `quality.reviewers` has entries: launch each agent in that list in parallel as a panel, with the same context and scope.
   - If both are empty: step 1 (built-in `code-review`) already covers this pass; nothing additional is launched.

When both run, they overlap on correctness and simplification: deduplicate those findings (count each once). The specific reviewers from `review_skill` (offensive/defensive security, silent failures, architecture) should not be repeated in later phases.

## 3. Targeted reinforcements

Only what the §2 skill does **not** already cover. If the feature touches specific areas, additionally launch **in parallel**:

- DB / heavy queries → use the `agents.performance` agent from `FLOW.md` on the changed files; if empty, skip this reinforcement.
- Workers / message queues → use the `agents.queues` agent from `FLOW.md` to verify there is no `flush()` in a loop and that workers are registered with the project convention (see `FLOW.md` section `conventions`); if empty, skip this reinforcement.
- Frontend → if there are changes in interface code, use the `agents.frontend` agent from `FLOW.md`; if there are also affected frontend tests, use `agents.frontend_test` as well; if either is empty, skip that reinforcement.

## 3.5. Completeness sweep (anti-abandonment, M/L only)

A reviewer with a large diff tends to **abandon early**: covers the obvious in the first files, summarizes the rest as "no issues", and declares done. This pass fixes that structurally. **Only if `meta.json.size` is M or L** (for XS/S the diff fits easily in one pass and this adds no value).

Loop, maximum **2 rounds**:

1. **Worklist**: `git diff --stat <git.default_base>...HEAD` → list of changed files/areas.
2. **Coverage map**: from the consolidated findings of §2-§3, mark which files/areas received at least one finding or were explicitly examined.
3. **Completeness critic (1 agent, blinded)**: launch it with `Agent general-purpose` (opus model — this is judgment, not tracking) passing **only** two things: the full list of diff files (step 1) and, for each §2-§3 reviewer, one line on what it covered. **Do not** pass the detailed findings or the design — its only job is to detect gaps, not opine on what was already seen. Prompt:

   > You are a coverage auditor for a code review. I give you (1) the list of files changed in this diff and (2) a one-line summary per reviewer of what area each one covered. Your only task: name the files or areas in the diff that **no** reviewer examined, and any claim a reviewer accepted as correct without verifying. Do not opine on existing findings. Output: list of concrete gaps (`file/area` + why it deserves a second look) or exactly "none". Under 150 words.

4. **If it names fresh gaps**: relaunch a targeted round **only on those files/areas** with the applicable `quality.review_skill` reviewers (constrain their paths to the gaps). Merge the new findings and deduplicate against the already consolidated ones.
5. **Repeat 2-4** until a round returns "none" fresh gaps **or** 2 rounds are reached.
6. **No silent truncation**: if after 2 rounds the critic still flags uncovered areas, **record them literally** in the output under "Areas not covered after 2 rounds" with their reason. Better to declare the limit than to feign complete coverage.

Fresh findings from this sweep enter the normal flow: they go through §4 (over-engineering), §5 (contracts), and §6 (adversarial verification) like any other.

## 4. Over-engineering audit (fit + YAGNI)

**Second barrier against over-engineering** (the first is the challenger in `/flow:feat:design`). Independent of the multi-agent code review: here the diff is examined looking for what is **unnecessary**, not what is missing.

1. **Locate every defensive mechanism in the diff**: validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker, queue, flag, retry.
2. **Find its row** in the "Defensive mechanisms and their justification" table in `03-design.md`.
   - **If it has no row**: blocker. It slipped in without passing the design filter. Ask: what real and present scenario in the project justifies it?
   - **If it has a row but the scenario is hypothetical** ("just in case", "it could happen that…", "in the future"): blocker of type "unnecessary".
3. **Verify the scenario against the code, not against paper**: can the flow really reach that state? Is there an upstream that already prevents it? A quota/constraint that already bounds it? Is the mechanism redundant with something that already exists? If `domain_memory.enabled` is `true`, query `mcp__domain-memory__search_knowledge` if the scenario depends on domain rules.
4. **Key question per piece**: *"if I remove this, what breaks in the project — today, not in a hypothetical future?"*. If the honest answer is "nothing that can really happen", it is an over-engineering finding.

"Unnecessary" findings go to Blockers with a concrete proposal: "remove X — protects against Y, which cannot happen because Z (evidence)".

## 5. Double-blind contract verification

If `05-implementation.md` has a "Contracts to respect" section, launch an `Agent general-purpose` with a **deliberately blinded** prompt: it only receives two things, nothing more, nothing less.

> You are a contract reviewer. You must say whether the diff meets some literal contracts I give you. **You have no access to the rest of the design, the controller context, the brief, or the implementation explanations.** Only:
>
> 1. **Contracts to respect** (copied verbatim from design):
>    <PASTE here the "Contracts to respect" section from `05-implementation.md` as-is, without reformatting>
>
> 2. **Diff of relevant files**: the shape constructions (JSON arrays, JsonSerializable, events, headers, routes, columns, metrics) from the changed files:
>    <PASTE here only the diff hunks that touch shape construction, not the full file>
>
> Your only task: for **each contract** in block 1, tell me whether the code in block 2 produces **exactly** that shape — key by key, nesting by nesting, same case, same singular/plural. Output: table `| Contract | Matches (yes/no) | If not: what differs |`. Under 200 words. Do not rationalize mismatches ("maybe they meant X"): if it differs, say so.

Why blinded: if you pass the full code or full design, the agent rationalizes the mismatch by reading nearby justifications. By blinding it to "literal contract vs what the diff emits", the comparison stays textual and does not self-contaminate.

Any "no" in the table → blocker. Passes to the output as a broken-contract finding with the concrete fix proposal.

If `05-implementation.md` does not have "Contracts to respect" (build recorded "N/A"), skip this step.

## 6. Adversarial finding verification (Workflow, optional M/L)

Reviewers tend to **over-report**: a "plausible" finding is not always real, and fixing false positives costs time and can worsen the code. If `meta.json.size` is **M or L** and the sum of blockers + suggestions from §2-§5 is **≥ 4**, offer with `AskUserQuestion` to filter them ("Verify findings with a panel of skeptics in parallel? Discards false positives before you go fix them."). If accepted, call the `Workflow` tool:

```js
export const meta = {
  name: 'review-verify',
  description: 'Adversarially verify each review finding in parallel',
  phases: [{ title: 'Verify' }],
}
const FINDINGS = args.hallazgos    // [{id, archivo, descripcion, propuesta}]
const VERDICT = {
  type: 'object',
  properties: {
    refutado: { type: 'boolean' },
    motivo: { type: 'string' },
  },
  required: ['refutado', 'motivo'],
}
const verified = await parallel(FINDINGS.map(h => () =>
  parallel([0, 1, 2].map(() => () =>
    agent(
      `You are a skeptic. Code review finding in the project:\n` +
      `File: ${h.archivo}\nProblem: ${h.descripcion}\nProposal: ${h.propuesta}\n\n` +
      `Try to REFUTE it: read the real code and say whether the problem is NOT real (refutado=true) or it is (refutado=false). ` +
      `When in doubt, refute — the burden of proof is on the finding. Be concrete about why.`,
      { label: `verify:${h.id}`, phase: 'Verify', schema: VERDICT, model: 'sonnet' }
    )))
    .then(votes => {
      const refuting = votes.filter(Boolean).filter(v => v.refutado).length
      return { ...h, survives: refuting < 2, refuting }
    })))
return { confirmed: verified.filter(h => h.survives), discarded: verified.filter(h => !h.survives) }
```

Pass `args: { hallazgos: [...] }` with the consolidated findings (short id, file:line, description, proposal). `discarded` ones (≥ 2 skeptics refute them) are removed from the blockers/suggestions list — record them in the output under "Discarded by verification" with the reason, so there is a trace of what was filtered and why. `confirmed` ones continue to the normal output. Not offered for XS/S or with fewer than 4 findings: the cost does not justify it.

## 7. Local quality gates

Read `quality.*` from `FLOW.md`. If empty, auto-discover equivalent commands (Makefile, npm/composer scripts) and note what you use.

Launch in parallel (background if slow):
- `quality.style_fix`
- `quality.static_analysis`
- `quality.test_one` (if there are new tests, with the appropriate filter)

Collect the results.

## 8. Output

Write `.claude/work/<TICKET>/06-review.md`:

```markdown
# Code review <TICKET>

## Summary
- Review tier: <full | proportional — which reviewers ran and why, per §2.0>
- Agents launched: …
- Completeness rounds (M/L): N
- Critical findings (block ship): N
- Suggestion findings: M

## Areas not covered after 2 rounds
<only if §3.5 still had gaps after exhausting the cap; literal list with reason, or "none">

## Double-blind contract verification
- Contracts compared: N
- Mismatches: <list or "none">

## Over-engineering (fit + YAGNI)
- Defensive mechanisms in diff: <list>
- Without justification in `03-design.md` or with hypothetical scenario: <list, or "none">
- Proposed trimming: <what to remove and why, or "nothing to remove">

## Discarded by adversarial verification
<only if §6 was run; list of refuted findings with reason, or "not applicable">

## Blockers (must-fix)
1. [file:line] description + concrete proposal

## Suggestions (nice-to-have)
1. [file:line] description

## Quality gates
- style_fix: ✅ / ❌
- static_analysis: ✅ / ❌
- modified tests: ✅ / ❌

## Next step
<if there are blockers: "resolve and return to /flow:feat:review">
<if none: "/flow:feat:validate">
```

## 9. Close

- If there are blockers: **do not advance `phase`**. Leave `phase = "build"` and the user resolves them.
- If there are no blockers: `phase = "review"`, add to `phases_done`.
- Summarize findings and next step for the user.
