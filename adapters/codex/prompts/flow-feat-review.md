# `/flow-feat-review`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Mandatory review phase. **`/flow-feat-ship` cannot run without passing through here and resolving blockers.**

## 1. Pre-flight

- Load `meta.json`. Require that `build` is in `phases_done`. If not, send the user to `/flow-feat-build` and stop.
- Verify that `git diff` has real changes. If not, warn and stop.

## 2. Invoke the code reviews

Launch **both** over the same scope and **consolidate their findings into a single deduplicated report**. Scope: the full feature work against the base branch (committed + working tree, because commits are opt-in and there may be uncommitted changes).

1. **Correctness review**: one pass over the local diff: correctness bugs + reuse/simplification/efficiency, at high effort. If Codex has a code review tool configured, use it; otherwise perform the review directly.
2. **Project panel**: read `quality.review_skill` from `FLOW.md`.
   - If `review_skill` has a value: invoke it passing `03-design.md` as additional context. Scope: `git diff <git.default_base>...HEAD`; if there are uncommitted changes, make sure they're included.
   - If `review_skill` is empty but `quality.reviewers` has entries: launch each subagent from that list in parallel as a panel, with the same context and scope.
   - If both are empty: step 1 already covers this pass; don't launch anything additional.

The two overlap on correctness and simplification: deduplicate those findings (count them once).

## 3. Reinforcements by area

Only what the §2 skill does **not** already cover. If the feature touches specific areas, additionally launch **in parallel**:

- DB / heavy queries → use the `agents.performance` agent from `FLOW.md` on the changed files; if empty, skip this reinforcement.
- Workers / message queues → use the `agents.queues` agent from `FLOW.md` to verify there's no `flush()` in a loop and that workers are registered per the project convention; if empty, skip this reinforcement.
- Frontend → if there are changes to UI code, use the `agents.frontend` agent from `FLOW.md`; if there are also affected frontend tests, use `agents.frontend_test` as well; if either is empty, skip that reinforcement.

## 3.5. Completeness sweep (M/L only)

A reviewer with a large diff tends to give up early. **Only if `meta.json.size` is M or L**:

Loop, maximum **2 rounds**:
1. **File list**: `git diff --stat <git.default_base>...HEAD` → list of changed files/areas.
2. **Coverage map**: from the consolidated findings of §2-§3, mark which files/areas received at least one finding or were explicitly examined.
3. **Completeness auditor** (general subagent, with only two things: the full file list from the diff and, for each reviewer from §2-§3, one line on what area each one covered):

   > You are a coverage auditor for a code review. I'm giving you (1) the list of files changed in this diff and (2) a one-line summary per reviewer of what area each one covered. Your only task: name the files or areas in the diff that **no** reviewer got to examine, and any claim a reviewer accepted as true without verifying. Don't comment on existing findings. Output: list of concrete gaps (`file/area` + why it deserves a second look) or exactly "none". Under 150 words.

4. **If it names fresh gaps**: relaunch a targeted round **only on those files/areas**.
5. **Repeat 2-4** until a round returns "none" or 2 rounds are reached.
6. **No silent truncation**: if after 2 rounds the auditor still flags uncovered areas, note them in the output under "Areas not covered after 2 rounds".

## 4. Over-engineering audit (fit + YAGNI)

**Second barrier against over-engineering.** Looks for what is **unnecessary** in the diff:

1. **Locate every defensive mechanism in the diff**: validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker, queue, flag, retry.
2. **For each one, find its row** in the "Defensive mechanisms and their justification" table in `03-design.md`.
   - **If it has no row**: blocker. It slipped through without passing the design filter.
   - **If it has a row but the scenario is hypothetical**: blocker of type "unnecessary".
3. **Verify the scenario against the code**: can the flow actually reach that state? If `domain_memory.enabled` is `true`, query `mcp__domain-memory__search_knowledge` if the scenario depends on domain rules.
4. **Key question**: *"if I remove this, what breaks in the project — today, not in a hypothetical future?"*. If the honest answer is "nothing that could actually happen", it's an over-engineering finding.

"Unnecessary" findings go to Blockers with a concrete proposal.

## 5. Double-blind contract verification

If `05-implementation.md` has a "Contracts to respect" section, launch a general subagent with a **deliberately blinded** prompt — it only receives two things:

> You are a contract reviewer. You have to say whether the diff fulfills some literal contracts I'm giving you. **You have no access to the rest of the design, nor to the controller context, nor to the brief, nor to the implementation explanations.** Only:
>
> 1. **Contracts to respect** (copied verbatim from the design):
>    <PASTE here the "Contracts to respect" section from `05-implementation.md` as-is, without reformatting>
>
> 2. **Diff of relevant files**: the shape constructions (JSON arrays, serialization, events, headers, routes, columns, metrics) from the changed files:
>    <PASTE here only the diff hunks that touch shape construction>
>
> Your only task: for **each contract** in block 1, tell me whether the code in block 2 produces **exactly** that shape — key by key, nesting by nesting, same case, same singular/plural. Output: table `| Contract | Matches (yes/no) | If no: what differs |`. Under 200 words. Don't rationalize mismatches: if it differs, say so.

Any "no" in the table → blocker.

If `05-implementation.md` has no "Contracts to respect" (build recorded "N/A"), skip this step.

## 6. Adversarial finding verification (optional M/L)

If `meta.json.size` is **M or L** and the sum of blockers + suggestions from §2-§5 is **≥ 4**, offer the user to filter them with a parallel skeptics panel. If accepted, launch subagents in parallel on each finding (3 skeptics per finding, with a refute-by-default instruction): a finding survives if fewer than 2 skeptics refute it. Discarded ones (≥2 refute them) are noted in the output under "Discarded by verification" with the reason.

Not offered for XS/S or with fewer than 4 findings: the cost doesn't justify it.

## 7. Local quality gates

Read `quality.*` from `FLOW.md`. If empty, auto-discover equivalent commands and flag what you're using.

Launch in parallel (in the background if slow):
- `quality.style_fix`
- `quality.static_analysis`
- `quality.test_one` (if there are new tests, with the appropriate filter)

## 8. Output

Write `.claude/work/<TICKET>/06-review.md`:

```markdown
# Code review <TICKET>

## Summary
- Reviewers launched: …
- Completeness rounds (M/L): N
- Critical findings (block ship): N
- Suggestion findings: M

## Areas not covered after 2 rounds
<only if §3.5 had gaps after hitting the cap; literal list with reason, or "none">

## Double-blind contract verification
- Contracts compared: N
- Mismatches: <list or "none">

## Over-engineering (fit + YAGNI)
- Defensive mechanisms in the diff: <list>
- Without justification in `03-design.md` or with hypothetical scenario: <list, or "none">
- Proposed cuts: <what to remove and why, or "nothing to cut">

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
<if blockers: "resolve and return to /flow-feat-review">
<if none: "/flow-feat-validate">
```

## 9. Close

- If there are blockers: **do not advance `phase`**. Leave `phase = "build"` and the user resolves them.
- If no blockers: `phase = "review"`, add to `phases_done`.
- Summarize findings and next step for the user.
