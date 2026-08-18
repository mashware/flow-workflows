---
description: Multi-agent code review of the fix before submitting
---

# `/flow:bug:review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a panel, challengers, a skeptic filter or a parallel fan-out, how wide it goes, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

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

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion or idle notifications never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**If it is a question, it is `AskUserQuestion`.** Never end a message with a question in prose: in `manual` it hides among the text, and in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve the menu, it is not a question — it is a decision you take and record.

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

- Load `meta.json`. Require `fix` in `phases_done`. For `size` ≥ S also require `validate`.
- If `git diff` shows no changes, warn and stop.

## 2. Run the code reviews

Scope for every reviewer below: the fix against the base (committed + uncommitted working tree).

### 2.0 Resolve review depth (scale to the work size and the risk)
Read `quality.review_depth` from `FLOW.md` (`proportional` | `full`; empty → `proportional`) and `meta.json.size`. A minimal fix does not need a full specialized panel; the riskiest fixes earn the top effort tiers. The built-in `code-review` exposes an effort ladder **low < medium < high < xhigh < max** (lower = fewer, higher-confidence findings; higher = broader coverage):

- **`full`** (any size): built-in `code-review` (**xhigh**) + the project panel. Pre-0.7 behavior; skip the tiering below.
- **`proportional`** (default), base effort by size:
  - **XS**: built-in `code-review` **only**, at **medium** effort. No project panel.
  - **S**: built-in `code-review` at **high** effort. Project panel **only if** the diff touches a **sensitive surface** (auth/authorization, secrets, payments/billing, personal/sensitive data, a public API/contract shape, or a DB migration/schema change); otherwise built-in only.
  - **M**: built-in `code-review` (**high**) + the project panel.
  - **L**: built-in `code-review` (**xhigh**) + the project panel.
- **Sensitive-surface bump** (proportional, any size): if the diff touches a sensitive surface, **raise the built-in effort one tier** (medium→high→xhigh→**max**) and always run the panel — so an XS/S security or migration fix gets a far deeper pass than its line count suggests.

Record in `06-review.md` which tier and effort ran and why. Note fixes skew XS/S, so most fixes get the built-in pass alone — but a sensitive-surface fix escalates regardless of size.

### 2.1 Launch and consolidate
Launch the reviewers selected in §2.0 and **consolidate their findings into a single deduplicated report**:

1. **Built-in `code-review`** (the Claude Code one, no prefix), at the effort resolved in §2.0. Single pass over the local diff: correctness issues + simplification/efficiency.
2. **Project panel** (only when §2.0 selected it): skill `quality.review_skill` from FLOW.md, invoked as `<review_skill> branch`. If `quality.review_skill` is empty and `quality.reviewers` has entries, launch those agents in parallel as a review panel. If both are empty, the built-in `code-review` above is the whole review. Launch the panel **as defined** — whole roster, no subset, no substitutions; if an agent cannot run, record it in §7 `Agents launched` with the reason.

Deduplicate overlaps (correctness/simplification flagged by both; count once). Specific focus for the fix beyond generic analysis:
- The change must genuinely resolve the problem from `02-diagnose.md` / `03-investigation.md`.
- There must be no expanded scope (hidden refactor). If there is, list it.
- The regression test from `05-validation.md` must cover the case.

Pass as context: `03-investigation.md` and `04-fix.md`. **But treat their justifications as hypotheses, not axioms**: the root cause and the contracts are truth, yet any *"why I chose this approach"* prose in `04-fix.md` is a claim to test against the code — do not bless a choice merely because the fix rationalized it in writing. Same for the briefs you write: a settled decision is context (*"this is decided; what consequences does it have?"*), never a scope exclusion.

## 2.2 Idiom / primitive audit (only if the fix introduces new architectural pieces)

A minimal fix rarely adds new classes — but when it does (a new service, handler, command/query, interface, or a new bus/dispatch wiring), run the same blind idiom check as `/flow:feat:review §5.5`: launch the `agents.architecture` agent from `FLOW.md` (or `Agent general-purpose` if empty) with **only** the new pieces + their wiring and the project's primitive vocabulary (from `FLOW.md` `conventions`), **without** the fix's justifications. It asks the naïve first-read question per piece: does this class do what its name/role promises? Why does it depend on what it depends on (a bus injected only to call another handler, a service dressed as something else, an interface with a single handler consumer)? Is there a simpler, more honest primitive? Findings enter the flow like any other. If the fix adds no new architectural pieces, skip this.

## 3. Reinforcements by area

Only what the skill in §2 does not already cover. Launch additionally in parallel if applicable:

- A repeated call that leaves the process (external API, HTTP, cache, filesystem) → `agents.performance` agent from FLOW.md; if empty, use `Agent general-purpose` with a performance role in the prompt. Ask what **each failed iteration** sets off downstream, not just what the happy path costs. **Queries have their own pass** in §3.5.
- Workers / dead-letter queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence; if empty, use `Agent general-purpose` with a messaging role in the prompt.

## 3.5 Data-access duel (any size, whenever the fix touches a query)

If the fix **adds or modifies** a query — raw SQL, the ORM's query language, a query-builder chain, a repository finder, a relation traversed in a loop, an aggregate/count, a bulk write, a migration or index change, or the equivalent against a search engine or key-value store — run the mechanics of **`/flow:work:query`** over it: its **§2 fact sheet** (filter, order **with direction**, bound and whether it is per key or global, both sides of each join with real types and collations, heavy columns, cardinality with its source, the indexes that actually exist), its **§3 blinded challenger** over the twelve-item checklist with the main agent judging, its **§4 measurement** when the schema cannot settle it, and its **§5 verdict** shape. **Any size, XS included** — a one-line change to an `ORDER BY` or a `LIMIT` is precisely the change whose cost is invisible in the diff, and a reading reviewer has no way to catch it.

Two things are specific to a fix. First, **if the bug being fixed is itself about slowness or timeouts, the duel is the fix's proof**, not a review formality: the verdict must show the plan before and after, or the fix is unproven whatever the tests say. Second, a fix is where a **trick** gets added under pressure (a cast to align a collation, a hint, a hand-written column order) — checklist item 11 applies with full force: it ships with a comment saying why it is there and what removes it, plus the ticket for the root cause, or it does not ship. Verdicts map as findings: **change** blocks, **schema / follow-up** becomes a proposed ticket, **unresolved** is recorded literally.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also smuggle in excess defenses ("since I'm fixing this, I'll add a retry/guard/fallback just in case"). Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"What real, present scenario in this project justifies it?"*. Verify against the code — can the flow actually reach that state, or is there already something that prevents it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` if it depends on domain rules.
- A fix must be **minimal**: anything that does not directly attack the root cause from `03-investigation.md` and does not respond to a present scenario is unnecessary. Add to Blockers with a trim proposal.

## 4.5. Completeness check (M/L, no loop)

A fix is minimal by design (§4), so here **one** check is enough — no loop. **M/L only**: after consolidating findings from §2-§3, contrast `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file from the fix was not looked at by any reviewer, give it a targeted pass with the applicable reviewer and merge. If the diff is small (normal for a fix), this resolves in seconds or does not apply.

## 5. Adversarial finding verification (parallel fan-out, optional)

Same as `/flow:feat:review` §6 — its gate, its ceiling and its autonomy rule, unchanged. In short: only when the size is **M or L**, the diff is **over 150 changed lines**, and there are **≥ 4 ambiguous** findings (the ones resting on an assumption about code outside the diff, on a runtime behaviour, or on an unverified convention — not the ones whose defect is visible in the diff). **One skeptic per ambiguous finding, in parallel, capped at `agents.fanout_max`** (empty → 4), refute-by-default. In **`manual`** offer it with `AskUserQuestion`; in **`guided`/`auto` run it without asking** and note it in the artifact. Refuted findings come off the list and go into the output under "Discarded by verification" with the reason. When the gate does not open, say so in one line — skipped and clean are not the same result.

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
- Review tier: <full | proportional — which reviewers ran, at what built-in effort (medium/high/xhigh/max), and why, per §2.0>
- Agents launched: <ran vs defined — `N/M` of the `review_skill`/`reviewers` roster, naming any that did not run (with the reason) and any substitution; "built-in only" if §2.0 selected no panel>
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
- **Autonomy handoff.** Only without blockers — with blockers, stop in every mode. For **M/L**: in `manual`, propose `/flow:bug:postmortem` with a single `AskUserQuestion`; in `guided`/`auto`, **chain into it automatically** in this same turn. For **XS/S**, the next step is `ship`, which pushes and opens the MR/PR — a hard gate in **every** mode: stop here and propose `/flow:bug:ship` with a single `AskUserQuestion`, never chaining into it on its own.
