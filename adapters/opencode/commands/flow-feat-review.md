---
description: Mandatory multi-agent code review before pushing
---

# `/flow-feat-review`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a subagent panel, challengers or a skeptic filter, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

**Reporting — how every stop reads.** When this command stops — a question, a hard gate, or the end of the turn — the user is coming back to a screen they walked away from, often with other works running in other panes. They have **not** read your tool calls, your subagents' reports, or the artifacts you wrote. So every stop **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action you need from them, or "nothing, continuing with X">
```

Take every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #<n> of <N>` and `Plan:` lines when the work has no `mrs`. After the header, **at most ~10 lines of body**, and only what could change a decision the user might take. Everything else goes to the phase artifact, which is where it stays useful.

**Product altitude — the effect, not the implementation.** The body is written in the language of what changed for whoever uses this software: what the product does now that it did not, what was breaking and for whom, what is still not covered. Not what you built. Code identifiers — classes, files, methods, error codes — earn a line only when the user has to *decide* about one, when they asked something technical, or when they named it first; the mechanics belong to the phase artifact, which is where they stay useful. Ten lines about `AttachmentUploader` say nothing to someone who has not read the diff; "attachments over 25 MB no longer break the send — they upload separately and the mail carries a link" says all of it. When an identifier is genuinely unavoidable, the Zero-context rule below applies to it.

**Short lines, not prose.** One or two lines of headline, then two to five bullets, one idea each. No chained subordinate clauses, no "for context", no restating what an earlier stop already said. The ~10-line limit above is a ceiling, not a target: ten lines of prose obey it and are still a wall of text. This governs the report you write unprompted — when the user asks a technical question, answer it in full.

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion notices never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**A question is asked as a question.** Never end a message with one buried in prose: write it as an explicit numbered choice with the recommended option marked, and wait. In `manual` a question hidden in the text is invisible; in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve to be numbered and waited on, it is not a question — it is a decision you take and record.

**Live panel — the same stop, written to disk.** The user typically has several works in flight at once and a panel open per work, so "where is this one at?" is a question they should never have to type at you. Whenever the state such a panel would show changes, overwrite `.claude/work/<work>/panel.json` **whole** (never patch it) with a snapshot built from `meta.json` plus what you know right now:

```json
{
  "updated_at": "2026-08-06T16:45:00+02:00",
  "phase": "validate",
  "header": true,
  "lines": [
    {"text": "Expose a thread's tracking state and events", "style": "title"},
    "",
    {"ref": "#1", "text": "batch read sources", "mark": "wait", "link": "https://gitlab.com/…/merge_requests/9977"},
    {"ref": "#2", "text": "per-event and per-recipient counters", "mark": "current"},
    {"ref": "#3–#6", "text": "channel map · use case · document detail · route", "mark": "pending"},
    "",
    {"ref": "Now", "text": "unit suite and the test agent over #2", "mark": "info"},
    {"ref": "Next", "text": "ship #2", "mark": "info"},
    {"ref": "Decision", "text": "confirm the MR/PR body before I create it", "mark": "wait"},
    "",
    {"text": "sibling-repo still needs the endpoint contract", "mark": "block"}
  ]
}
```

**`mark` says what a line *is*; the panel decides how to draw it.** `done` (merged, finished) · `current` (what is running right now — at most one) · `pending` (not started) · `wait` (shipped or asked, now waiting on someone else — an open MR/PR, a decision of the user's) · `block` (something is stopping this) · `info` (plain statement of fact). Lines carrying a `mark` form an aligned column: symbol, then `ref`, then the text, with the link pinned right. **Do not also set `style` on a marked line** — `style` overrides the mark's colour, and the colour is how the mark reads. The one exception is a line whose colour *is* the information (a monitoring cycle's verdict): there, `mark: "info"` plus `style: ok|warn|error` is the point.

**`ref` need not be a number.** `#1`, `#3–#6`, but equally `Now`, `Next`, `Decision`. Column width is computed **per block**, and blocks are separated by blank lines — so the MR/PR train aligns with the train and the labels below align with each other, without dragging one another wide. Use blank lines deliberately: they are what keeps two groups from distorting each other.

**`link` is a field, never text inside `text`.** The panel shortens it to its MR/PR number and pins it to the right of the line, or hangs it underneath when it does not fit. Pasting a raw URL into `text` gets you a 60-character line that wraps.

**What goes in, in this order.** (1) The work title (`style: title`, no mark). (2) The MR/PR train — one entry per `meta.json.mrs[]`, `ref` `#n`, a short title, the `mark` for its real state, and `link` for the ones that have a URL; entries not started yet collapse into a single `#a–#z` `pending` line; omit the block when the work has no `mrs`. (3) `Now` — what is actually running, the one fact `meta.json` cannot hold. (4) `Next`. (5) `Decision`, marked `wait`, **only** when the flow is parked on the user, naming the decision. (6) Blockers marked `block`: a sibling repo whose `contract_handoff` is `pending`, a red pipeline, a dependency that has not merged.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. When that stretch is expected to outlast the panel's staleness warning (~30 min), set **`stale_after_minutes`** to what it will really take, so a long CI poll is not reported as a dead agent. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a header drawn from it shows the previous phase for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, phase and age are drawn by the panel — never repeat them in `lines`. Keep it under ~14 lines; the panel wraps a long line and aligns the continuation under its text, so length is a matter of saying less, not of measuring columns. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

Mandatory review phase. **`/flow-feat-ship` cannot run without passing through here and resolving blockers.**

## 1. Pre-flight

- Load `meta.json`. Require `build` in `phases_done`. **In a multi-MR/PR work** (`meta.json.mrs` has >1 entry) require `build` in the **current `in_progress` MR/PR's** own `phases_done` (its `mrs[]` entry), not the work-level list — a previous MR/PR's `build` does not count. If missing, send the user to `/flow-feat-build` and stop.
- Check that `git diff` has real changes. If there are none, warn and stop.

## 2. Run the code reviews

Launch **both** over the same scope and **consolidate their findings into a single deduplicated report**. Scope: the complete feature work against the base branch (committed + working tree, because commits are opt-in and there may be uncommitted changes).

1. **Integrated review**: run a full pass over the local diff looking for correctness bugs + reuse/simplification/efficiency, at high effort — **escalated to the maximum thoroughness the tool supports when `meta.json.size` is L or the diff touches a sensitive surface** (auth/authorization, secrets, payments/billing, personal/sensitive data, a public API/contract shape, or a DB migration/schema change). If the tool has a built-in code review skill or command, use it (at its highest effort tier for those cases); otherwise perform the review yourself.
2. **Project panel**: read `quality.review_skill` from `FLOW.md`.
   - If `review_skill` has a value: invoke that skill passing `03-design.md` as additional context. Scope: `git diff <git.default_base>...HEAD`; if there are uncommitted working tree changes, make sure they're included.
   - If `review_skill` is empty but `quality.reviewers` has entries: launch each `@name` sub-agent from that list in parallel as a panel, with the same context and scope.
   - If both are empty: the pass from point 1 already covers this review; nothing additional is launched.

   Launch the panel **as defined** — the whole roster, no hand-picked subset, no substitutions. Its members own whole categories the rest of the flow explicitly does not repeat later, so a missing one is a category with no owner at all. If a sub-agent genuinely cannot run, declare it: record it in the output's `Sub-agents launched` with the reason.

Both overlap on correctness and simplification: deduplicate those findings (count each once). Specific reviewers contributed by `review_skill` (offensive/defensive security, silent failures, architecture) should not be repeated in later phases.

## 2.2 Design truth vs design rationale (don't inherit rationalizations)

`03-design.md` is passed to reviewers as context, but **not all of it carries the same authority**:
- Its **contracts and acceptance criteria are truth** — respect them, verify the code meets them.
- Its **pattern/architecture decisions and their justifications** — the ADR-light "Why" column, phrases like *"respects bounded contexts"*, *"for consistency"*, *"follows the pattern"* — are **hypotheses, not axioms**. A reviewer may and should refute them if the code tells a different story.

Don't bless a choice just because the design rationalized it in prose. **A plausible written justification is the single most common way a wrong idiom survives review**: the reviewer reads "respects X", checks that X is indeed respected, and never asks whether that was the right tool at all. Treat every "Why" as a claim to test against the code, not a reason to stop looking.

**This applies to the briefs you write, too.** A decision already taken goes to the reviewer as **context**, never as a scope exclusion: *"X is decided — tell me what consequences it has that we have not seen"*, never *"do not report X"*. Excluding a topic also excludes everything that hangs off it, which is where the consequences live.

## 3. Reinforcements by area

Only what the §2 skill **doesn't** already cover. If the feature touches specific areas, additionally launch **in parallel**:

- **Any repeated call that leaves the process** (external API, HTTP, cache, filesystem) → use the `agents.performance` sub-agent from `FLOW.md` on the changed files; if empty, skip this reinforcement. Have it cover what **each failed iteration** sets off downstream — what it publishes, enqueues, disables or logs — not just the cost of the happy path. **Queries are not covered here** — they get their own pass in §3.6, because a general performance reviewer reads the query and its justification and almost never reads its plan.
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

## 3.6 Data-access duel (queries are tried on their plan, not their prose)

**The one review category a reading reviewer structurally cannot cover.** A query's correctness is visible in the code; its cost is visible only in the **execution plan**, and the plan depends on facts that are nowhere in the diff — which index exists, in what column order and **direction**, the type and collation of both sides of a join, how many rows a key really has. So a panel of readers approves a query that reads a hundred thousand rows to return fifteen, and does it faster when the design wrote down a plausible reason for it.

**When it runs**: whenever the diff **adds or modifies** a query — raw SQL, the ORM's query language, a query-builder chain, a repository finder, a relation traversed in a loop, an aggregate/count, a bulk write, a migration or index change, or the equivalent read against a search engine or key-value store. **Any size, XS included**: this is not a depth tier but a category with no other owner, and a one-line change to an `ORDER BY` is exactly the kind of one-line change that costs a full sort of the result set. Skip it — saying so in one line — for renames, reformats, or a query moved without changing its filter, order, bound, joins or columns.

**How it runs**: follow the mechanics of `/flow-work-query` over the queries in the diff — its **§2 fact sheet** (call site and frequency, filter, order **with direction**, bound and whether it is global or per key, both sides of every join with their real types and collations, heavy columns, expected cardinality with its source, and the indexes that actually exist, read from the schema and not the mapping), its **§3 duel** (a challenger blinded to the design's rationale walking the twelve-item checklist, a defence that answers with plans and numbers rather than intent, and the main agent judging), its **§4 measurement** when the schema alone cannot settle it, gated as that command gates it, and its **§5 verdict** shape — one recommendation with the number behind it. Three of its judging rules matter most here: **no number, no win** (an unresolved point is recorded unresolved, never split in prose); **no dogma in either direction** (neither "N small queries is an N+1" nor "one batched query always wins" survives without a measurement); and a defect that **predates the diff** is declared and ticketed separately, never used to bless the diff nor dragged into it.

Verdicts map onto this phase as findings: **change** is a blocker like any other, **schema / follow-up** goes to the output as a proposed ticket, **unresolved** is recorded literally with the question left open. Do not send a `change` verdict resting on a measured plan to a skeptic — a measured finding is already confirmed.

## 4. Over-engineering audit (fit + YAGNI)

**Second barrier against over-engineering** (the first is the challenger in `/flow-feat-design`). Independent of the multi-agent code review: here we look at the diff for what **doesn't belong**, not what's missing.

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

## 5.5 Idiom / primitive audit (blind to the design's rationale)

The structural review (§2-§3) checks whether the code **respects the design's boundaries**; it doesn't ask whether the design **picked the right primitive**. That's a distinct blind spot: a piece can respect every layer and still be the wrong tool (a "Command" that only reads, a handler injecting the bus just to call another handler, a service dressed as something else). Structural reviewers miss it because it's **locally coherent and justified in writing** — and they read that justification. This pass is the naïve, first-read question a fresh senior reviewer asks, deliberately **biased** to be blind to the design's prose, exactly like §5.

**When to run**: only if the diff **introduces new architectural pieces** (new classes, new wiring, new use of a stack primitive — not renames or tweaks). Then: **always on M/L**; on **S** only if it introduces such pieces or touches a sensitive surface; **skip on XS**. When it runs, launch the architecture sub-agent from `FLOW.md` (`agents.architecture`, or a general-purpose sub-agent if empty) with this self-contained brief:

> You audit the **idiom** of the new code — not its correctness, not whether it respects the design. You receive ONLY: (1) the new/changed architectural pieces of this diff (new classes, their constructor dependencies, how they're wired), and (2) the project's primitive vocabulary from its conventions (see `FLOW.md` `conventions`). **You do NOT receive the design document or its justifications.** If a choice was rationalized in prose elsewhere, that rationale is exactly what you must not inherit — your value is asking "why does this exist?" *without* the paper answer.
>
> For each new piece, ask what a fresh senior reviewer asks on first read:
> - **Does this class do what its role/name promises?** A `Command`/`Query` doing the opposite (a command that only reads, a query that mutates); a `Service`/`Finder` that is a thin pass-through; a `Handler` with no handling logic.
> - **Why does it depend on what it depends on?** Especially: an entry-point primitive (bus, dispatcher) injected only to call *another* handler (handler-to-handler dispatch); a bus used as glue between two internal pieces instead of as an entry point; an interface whose only consumer is another handler.
> - **Is there a simpler, more honest primitive?** If the piece is a service disguised as something else, name the primitive it should be.
> - **Lost type/contract**: a return typed `mixed`/`object` patched with a docblock is a signal the wrong seam was chosen.
>
> Output: per finding, `file:line`, the smell in one line, and the honest alternative primitive. Say nothing about pieces that are idiomatic. Don't invent smells to fill space — "the new pieces are idiomatic" is a valid, good result. Under 250 words.

Findings from this pass enter the normal flow: they go through §6 (adversarial verification) and into the output like any other. **Why blind**: as in §5, if you feed it the design's rationale it rationalizes the smell away ("ah, it uses the bus to respect bounded contexts") instead of asking whether the bus belonged there at all.

## 6. Adversarial finding verification (parallel sub-agents, optional)

Reviewers tend to **over-report**: a "plausible" finding isn't always real, and fixing false positives costs time and can worsen the code. This is a filter, not a second review — and it is the one place where a fan-out runs away by multiplication, so the gate is deliberately narrow. All three conditions must hold:

| Condition | Threshold |
|---|---|
| Size | `meta.json.size` is **M or L** |
| Diff | the MR/PR diff is **over 150 changed lines** (`git diff --stat` against the target branch — the real diff, not the recorded size) |
| Findings | **≥ 4 ambiguous** findings from §2-§5 |

**Only the ambiguous ones get verified.** A finding whose defect is visible in the diff is already confirmed; re-reading it buys nothing. Verify only those resting on an assumption about code *outside* the diff, on a runtime behaviour, or on an unverified convention.

Then offer the filter ("Want to verify the ambiguous findings with skeptics in parallel? Discard false positives before you take them to fix."). In **`guided`/`auto`, do not ask** — run it and note in the artifact that you did; sending the user off to fix false positives is the worse outcome.

**How wide.** Read `agents.fanout_max` from `FLOW.md` (empty → **4**): **one** skeptic per ambiguous finding, in parallel, capped at `fanout_max`. If more findings are ambiguous than the cap allows, verify the most consequential and send the rest through unverified, marked as such. Leave `agents.fanout_tool` empty — it names a harness-specific orchestrator opencode does not have.

For each finding `{id, file, description, proposal}`, launch **one** sub-agent:

> You are a skeptic. Code review finding in the project:
> File: {file}
> Problem: {description}
> Proposal: {proposal}
>
> Try to REFUTE it: read the actual code and say whether the problem is NOT real (refuted=true) or it is (refuted=false). When in doubt, refute — the burden of proof is on the finding. Be concrete about why.

A finding is **discarded** when its skeptic refutes it. Discarded findings come off the blockers/suggestions list and go into the output under "Discarded by verification" with the reason, so there is a trace of what was filtered and why. **One skeptic, not a voting panel**: this filter's failure mode is cheap — a wrongly-discarded finding is recorded in the artifact and stays visible to you — whereas three voters per finding multiplied the cost by every finding found.

Not run for XS/S, for small diffs, or with fewer than 4 ambiguous findings: the cost doesn't justify it. When you skip it, say so in one line — skipped and clean are not the same result.

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
- Sub-agents launched: <ran vs defined — `N/M` of the `review_skill`/`reviewers` roster, naming any that did not run (with the reason) and any substitution; "built-in only" if the depth ladder selected no panel>
- Completeness rounds (M/L): N
- Critical findings (block ship): N
- Suggestion findings: M

## Areas not covered after 2 rounds
<only if §3.5 had remaining gaps after the limit; literal list with reason, or "none">

## Data-access duel
<one row per query added or modified by the diff, per §3.6; "no queries touched", or "renames only" when filter/order/bound/joins/columns did not change>

| Query (file:line) | Bound | Index used / plan | Rows read → returned | Verdict | Evidence |
|---|---|---|---|---|---|

- Measured: <realistic data set / dev database / schema only / not measured, and why>
- Unresolved: <the specific question left open, or "none"> · Schema / follow-up: <predating defects and schema-level fixes with the proposed ticket, or "none">

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
<if there are blockers: "resolve and return to /flow-feat-review">
<if none: "/flow-feat-validate">
```

## 9. Close

- If there are blockers: **don't advance `phase`**. Leave `phase = "build"` and let the user resolve them.
- If there are no blockers: `phase = "review"`, add to `phases_done`. **In a multi-MR/PR work**, also add `review` to the current `in_progress` MR/PR's own `phases_done` (its `mrs[]` entry) — this is exactly what `/flow-feat-ship §1` gates on per MR/PR, so without it the ship gate would pass on a stale sibling's review.
- Summarize findings and next step to the user.
- **Autonomy handoff** — only with no blockers and no unresolved high-severity findings; either one stops the flow in every mode. In `manual`, propose `/flow-feat-validate` as a question; in `guided`/`auto`, **chain into `/flow-feat-validate` automatically** in this same turn. Never chain into `/flow-feat-ship` from here, in any mode.
