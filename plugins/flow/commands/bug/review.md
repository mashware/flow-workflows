---
description: Multi-agent code review of the fix before submitting
---

# `/flow:bug:review`

Mandatory code review of the fix.

## 1. Pre-flight

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context. **Models key for this command: `review`.**

- Read `meta.json` and `00-summary.md`; open in full only `03-investigation.md` and `04-fix.md` (reviewer context, §2.1) and `05-validation.md` (regression test); `02-diagnose.md` only when the summary leaves the symptom unclear. (flow-core §5)
- Require `fix` in `phases_done`; for `size` ≥ S also require `validate`.
- `git diff` shows no changes → warn and stop.

## 2. Run the code reviews

Scope for every reviewer: the fix against the base (committed + uncommitted working tree).

### 2.0 Resolve review depth (scale to the work size and the risk)
Read `quality.review_depth` from `FLOW.md` (`light` | `proportional` | `full`; empty → `proportional`) and `meta.json.size`. Built-in `code-review` effort ladder: **low < medium < high < xhigh < max** (lower = fewer, higher-confidence findings; higher = broader coverage).

**Sensitive surface** = auth/authorization, secrets, payments/billing, personal/sensitive data, a public API/contract shape, or a DB migration/schema change.

| Tier | What runs |
|---|---|
| `light` (any size) | One reviewer only: built-in `code-review` at **medium** — or `quality.review_skill` alone when it is set. No project panel, no §3 reinforcements, no §5 skeptic fan-out. A sensitive surface upgrades `light` to `proportional` for this review (bump included); record the upgrade. |
| `proportional` · XS | built-in `code-review` **only**, **medium**. No project panel. |
| `proportional` · S | built-in `code-review` **high**. Project panel **only if** the diff touches a sensitive surface. |
| `proportional` · M | built-in `code-review` **high** + project panel. |
| `proportional` · L | built-in `code-review` **xhigh** + project panel. |
| `full` (any size) | built-in `code-review` **xhigh** + project panel (pre-0.7 behaviour; no tiering). |

- **Sensitive-surface bump** (`proportional`, any size): **raise the built-in effort one tier** (medium→high→xhigh→**max**) and always run the panel — an XS/S security or migration fix escalates regardless of line count.
- Record in `06-review.md` which tier and effort ran and why.

### 2.1 Launch and consolidate
Launch the reviewers selected in §2.0 and **consolidate their findings into a single deduplicated report**:

1. **Built-in `code-review`** (the Claude Code one, no prefix), at the effort of §2.0. Single pass over the local diff: correctness + simplification/efficiency.
2. **Project panel** (only when §2.0 selected it): skill `quality.review_skill` from FLOW.md, invoked as `<review_skill> branch`. `review_skill` empty and `quality.reviewers` set → launch those agents in parallel as a panel. Both empty → the built-in `code-review` is the whole review. Launch the panel **as defined** — whole roster, no subset, no substitutions; an agent that cannot run goes to §7 `Agents launched` with the reason.

Deduplicate overlaps (count once). Fix-specific focus beyond generic analysis:
- The change genuinely resolves the problem from `02-diagnose.md` / `03-investigation.md`.
- No expanded scope (hidden refactor) — list any.
- The regression test from `05-validation.md` covers the case.

Pass `03-investigation.md` and `04-fix.md` as context. The root cause and the contracts are truth; any *"why I chose this approach"* prose in `04-fix.md` is a hypothesis to test against the code, never an axiom. Same for your own briefs: a settled decision is context (*"this is decided; what consequences does it have?"*), never a scope exclusion.

## 2.2 Idiom / primitive audit (only if the fix introduces new architectural pieces)

Skip unless the fix adds a new service, handler, command/query, interface, or bus/dispatch wiring. Then run the blind idiom check of `/flow:feat:review §5.5`: the `agents.architecture` agent from `FLOW.md` (empty → `Agent general-purpose`) receives **only** the new pieces + their wiring and the project's primitive vocabulary (`FLOW.md` `conventions`), **without** the fix's justifications. Per piece: does the class do what its name/role promises? Why does it depend on what it depends on (a bus injected only to call another handler, a service dressed as something else, an interface with a single handler consumer)? Is there a simpler, more honest primitive? Findings enter the flow like any other.

## 3. Reinforcements by area

Only what §2 does not already cover; skipped under `light`. Launch in parallel if applicable:

- A repeated call that leaves the process (external API, HTTP, cache, filesystem) → `agents.performance` agent from FLOW.md (empty → `Agent general-purpose` with a performance role). Ask what **each failed iteration** sets off downstream, not just the happy path. **Queries have their own pass** in §3.5.
- Workers / dead-letter queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence (empty → `Agent general-purpose` with a messaging role).

## 3.5 Data-access duel (any size, whenever the fix touches a query)

Runs when the fix **adds or modifies** a query — raw SQL, the ORM's query language, a query-builder chain, a repository finder, a relation traversed in a loop, an aggregate/count, a bulk write, a migration or index change, or the equivalent against a search engine or key-value store. **Any size, XS included** — a one-line `ORDER BY` or `LIMIT` change has a cost invisible in the diff.

Run the mechanics of **`/flow:work:query`**: its **§2 fact sheet** (filter, order **with direction**, bound and whether per key or global, both sides of each join with real types and collations, heavy columns, cardinality with its source, the indexes that actually exist), its **§3 blinded challenger** over the twelve-item checklist with the main agent judging, its **§4 measurement** when the schema cannot settle it, and its **§5 verdict** shape.

Fix-specific:
- **Bug about slowness or timeouts → the duel is the fix's proof**: the verdict must show the plan before and after, or the fix is unproven whatever the tests say.
- A **trick** added under pressure (a cast to align a collation, a hint, a hand-written column order) — checklist item 11 applies in full: it ships with a comment saying why it is there and what removes it, plus the ticket for the root cause, or it does not ship.
- Verdicts map as findings: **change** blocks, **schema / follow-up** → proposed ticket, **unresolved** recorded literally.

## 4. Over-engineering audit (fit + YAGNI)

Review the diff for new defensive mechanisms smuggled in "just in case" (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- Per mechanism: *"What real, present scenario in this project justifies it?"* Verify against the code — can the flow reach that state, or does something already prevent it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` when it depends on domain rules.
- A fix is **minimal**: anything not directly attacking the root cause of `03-investigation.md` and not answering a present scenario → Blockers, with a trim proposal.

## 4.5. Completeness check (M/L, no loop)

**M/L only**, **one** check, no loop: after consolidating §2-§3, contrast `git diff --stat <git.default_base>...HEAD` against what was reviewed. Any changed file no reviewer looked at → targeted pass with the applicable reviewer, merge. A small diff (normal for a fix) resolves this in seconds or makes it not apply.

## 5. Adversarial finding verification (parallel fan-out, optional)

Same as `/flow:feat:review` §6 — its gate, ceiling and autonomy rule, unchanged. Skipped under `light`. Gate: size **M or L**, diff **over 150 changed lines**, **≥ 4 ambiguous** findings (resting on an assumption about code outside the diff, a runtime behaviour, or an unverified convention — not defects visible in the diff). **One skeptic per ambiguous finding, in parallel, capped at `agents.fanout_max`** (empty → 4), refute-by-default. `manual` → offer it with `AskUserQuestion`; `guided`/`auto` → run without asking and note it in the artifact. Refuted findings come off the list into "Discarded by verification" with the reason. Gate closed → say so in one line; skipped and clean are not the same result.

## 6. Quality gates

`quality` commands from FLOW.md; empty → auto-discover:

```
<quality.style_fix>
<quality.static_analysis>
<quality.test_one> (regression test)
```

## 7. Output

Cost line: count every subagent this command launched — reviewers = §2.1 built-in + panel members + §2.2; reinforcements = §3, §3.5 and §4.5 agents; skeptics = §5.

`.claude/work/<TICKET>/06-review.md`:

```markdown
# Fix review {TICKET}

## Summary
- Review tier: <light | full | proportional — which reviewers ran, at what built-in effort (medium/high/xhigh/max), and why, per §2.0>
- Agents launched: <ran vs defined — `N/M` of the `review_skill`/`reviewers` roster, naming any that did not run (with the reason) and any substitution; "built-in only" if §2.0 selected no panel>
- Cost: <n> subagents launched (<k> reviewers · <m> reinforcements · <s> skeptics), tier <light|proportional|full>
- Blockers: N
- Suggestions: M

## Does the fix actually resolve the bug?
- Yes / No / Partial — explain

## Is there expanded scope beyond the bug?
- Yes (list and propose moving to another ticket) / No

## Over-engineering (fit + YAGNI)
- New defensive mechanisms in the fix: <list, or "none">
- Without a real scenario to justify them: <list, or "none">

## Data-access duel
<per §3.5; "no queries touched" if none>

| Query (file:line) | Bound | Index used / plan | Rows read → returned | Verdict | Evidence |
|---|---|---|---|---|---|

- Measured: <realistic data set / dev database / schema only / not measured, and why>
- Before vs after: <mandatory when the bug was about slowness — the plan on both sides>
- Unresolved: <the question left open, or "none">
- Schema / follow-up: <predating defects, with the proposed ticket, or "none">

## Is the regression test adequate?
- Yes / No (what is missing)

## Quality gates
<per §6 — the commands actually run, each with its result>
- style_fix: ✅ / ❌
- static_analysis: ✅ / ❌
- regression test (`test_one`): ✅ / ❌

## Discarded by adversarial verification
<only if §5 was run; refuted findings with their reason, or "not applicable">

## Blockers
1. [file:line] …

## Suggestions
1. …
```

## 8. Close

- With blockers: `phase` stays where it was (`validate` for size ≥ S, `fix` on XS, where validate never ran). Iterate.
- Without blockers: `phase = "review"`, add to `phases_done`. Suggest `/flow:bug:postmortem` (M/L) or `/flow:bug:ship` (XS/S).
- **Record *what* you reviewed**, in the same write: `reviewed_sha` = `git rev-parse HEAD` — `phases_done` says a review happened, the sha says on which tree, and `/flow:bug:ship §0` compares it against what is being pushed. Only when the phase advances: a review that ended in blockers reviewed nothing that stands.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- Stop body (after the flow-core §3 header): the findings that survived and what you did with each, plus the same Cost line as the Summary: "- Cost: <n> subagents launched (<k> reviewers · <m> reinforcements · <s> skeptics), tier <light|proportional|full>".
- **Autonomy handoff.** Only without blockers — with blockers, stop in every mode. **M/L**: `manual` → propose `/flow:bug:postmortem` with a single `AskUserQuestion`; `guided`/`auto` → chain into it in this same turn. **XS/S**: the next step is `ship`, which pushes and opens the MR/PR — a hard gate in **every** mode: stop here and propose `/flow:bug:ship` with a single `AskUserQuestion`, never chaining into it.
