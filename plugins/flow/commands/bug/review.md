---
description: Multi-agent code review of the fix before submitting
---

# `/flow:bug:review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a panel, challengers, a skeptic filter or a `Workflow`, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

**Reporting — how every stop reads.** When this command stops — a question, a hard gate, or the end of the turn — the user is coming back to a screen they walked away from, often with other works running in other panes. They have **not** read your tool calls, your subagents' reports, or the artifacts you wrote. So every stop **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action you need from them, or "nothing, continuing with X">
```

Take every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #<n> of <N>` and `Plan:` lines when the work has no `mrs`. After the header, **at most ~10 lines of body**, and only what could change a decision the user might take. Everything else goes to the phase artifact, which is where it stays useful.

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
    {"text": "#1 batch read sources        MR open", "style": "ok"},
    {"text": "https://gitlab.com/…/merge_requests/9977", "style": "dim", "indent": 3},
    {"text": "#2 per-message grouping      validating"},
    {"text": "#3–#6 channel map · use case · detail · route", "style": "dim"},
    "",
    "Right now: unit suite and the test agent over #2",
    {"text": "Next: ship #2 — needs your confirmation", "style": "dim"},
    "",
    {"text": "Waiting on you: confirm the MR/PR body before I create it", "style": "accent"},
    {"text": "sibling-repo still needs the endpoint contract", "style": "warn"}
  ]
}
```

**What goes in, in this order.** (1) The work title. (2) The MR/PR train — one line per `meta.json.mrs[]` entry, `#n`, short title, and **its real state as the last column**, with the **URL indented underneath every entry that is still open**, because chasing you for a link is the single most common thing the user has to ask for; the ones not started yet collapse into a single `#a–#z` line; omit the block entirely when the work has no `mrs`. **Never group the entries under headings like "done" / "left"**: in a train an MR/PR that has shipped is *open, waiting to merge*, and a heading that calls it done states something false in the one place the user is trusting at a glance. The state column says it; nothing above it needs to. (3) `Right now:` — one line of prose on what is actually running, the one fact `meta.json` cannot hold. (4) `Next:` — what follows. (5) `Waiting on you:` in `accent`, **only** when the flow is parked on a decision of theirs, naming that decision. (6) Blockers in `warn`: a sibling repo whose `contract_handoff` is `pending` (from `related_repos`), a red pipeline, a dependency that has not merged. Styles are semantic — `normal` `dim` `title` `accent` `ok` `warn` `error` — the panel owns the palette.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a panel that reads the phase from it shows the previous one for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, age — and the phase, from `phase` when present — are already drawn by the panel; never repeat them in `lines`. Keep it under ~14 lines, and keep **each line short enough not to wrap** (~55 characters is the safe width): a wrapped line loses its column and its continuation does not inherit `indent`, so it is better to say less than to say it in two ragged lines. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

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

- DB / queries, or a repeated call that leaves the process (external API, HTTP, cache, filesystem) → `agents.performance` agent from FLOW.md; if empty, use `Agent general-purpose` with a performance role in the prompt. Ask what **each failed iteration** sets off downstream, not just what the happy path costs.
- Workers / dead-letter queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence; if empty, use `Agent general-purpose` with a messaging role in the prompt.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also smuggle in excess defenses ("since I'm fixing this, I'll add a retry/guard/fallback just in case"). Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"What real, present scenario in this project justifies it?"*. Verify against the code — can the flow actually reach that state, or is there already something that prevents it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` if it depends on domain rules.
- A fix must be **minimal**: anything that does not directly attack the root cause from `03-investigation.md` and does not respond to a present scenario is unnecessary. Add to Blockers with a trim proposal.

## 4.5. Completeness check (M/L, no loop)

A fix is minimal by design (§4), so here **one** check is enough — no loop. **M/L only**: after consolidating findings from §2-§3, contrast `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file from the fix was not looked at by any reviewer, give it a targeted pass with the applicable reviewer and merge. If the diff is small (normal for a fix), this resolves in seconds or does not apply.

## 5. Adversarial finding verification (Workflow, optional M/L)

Same as `/flow:feat:review` §6, including its autonomy rule: if `meta.json.size` is **M or L** and there are **≥ 4** findings across blockers and suggestions, in **`manual`** offer with `AskUserQuestion` to filter them with a panel of skeptics in parallel — in **`guided`/`auto` run the filter without asking** and note it in the artifact (same `Workflow` script `review-verify`: 3 skeptics per finding, refute-by-default, survives if fewer than 2 refute it). Discarded findings are removed from the list and noted in the output under "Discarded by verification" with the reason. Not offered for XS/S or with fewer than 4 findings.

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
