# `/flow-bug-review`

Mandatory code review of the fix.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion notices never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**A question is asked as a question.** Never end a message with one buried in prose: write it as an explicit numbered choice with the recommended option marked, and wait. In `manual` a question hidden in the text is invisible; in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve to be numbered and waited on, it is not a question — it is a decision you take and record.

- Load `meta.json`. Require `fix` in `phases_done`. For `size` ≥ S also require `validate`.
- If `git diff` shows no changes, warn and stop.

## 2. Invoke the two code reviews

Launch **both** over the fix scope against the base (committed + uncommitted working tree) and **consolidate their findings into a single deduplicated report**:

1. **Correctness review**: one pass over the local diff: correctness bugs + simplification/efficiency, at high effort — **escalated to the maximum thoroughness the tool supports when `meta.json.size` is L or the diff touches a sensitive surface** (auth/authorization, secrets, payments/billing, personal/sensitive data, a public API/contract shape, or a DB migration/schema change). If Codex has a code review tool configured, use it (at its highest effort tier for those cases); otherwise perform the review directly.
2. **Skill `quality.review_skill` from FLOW.md**: invoke it as `<review_skill> branch`. If `quality.review_skill` is empty and `quality.reviewers` has entries, launch those subagents in parallel as a review panel. If both are empty, the review in point 1 already covers this pass. Launch the panel **as defined** — whole roster, no subset, no substitutions; if a reviewer cannot run, record it in the output's `Reviewers launched` with the reason.

Deduplicate overlaps. Specific fix focus in addition to the generic analysis:
- The change must actually resolve the problem from `02-diagnose.md` / `03-investigation.md`.
- There must be no expanded scope (hidden refactor). If there is, list it.
- The regression test from `05-validation.md` must cover the case.

Pass as context: `03-investigation.md` and `04-fix.md`. **But treat their justifications as hypotheses, not axioms**: the root cause and the contracts are truth, yet any *"why I chose this approach"* prose in `04-fix.md` is a claim to test against the code — don't bless a choice merely because the fix rationalized it in writing. Same for the briefs you write: a settled decision is context (*"this is decided; what consequences does it have?"*), never a scope exclusion.

## 2.2 Idiom / primitive audit (only if the fix introduces new architectural pieces)

A minimal fix rarely adds new classes — but when it does (a new service, handler, command/query, interface, or a new bus/dispatch wiring), run the same blind idiom check as `/flow-feat-review §5.5`: launch the `agents.architecture` agent from `FLOW.md` (or a general subagent if empty) with **only** the new pieces + their wiring and the project's primitive vocabulary (from `FLOW.md` `conventions`), **without** the fix's justifications. It asks the naïve first-read question per piece: does this class do what its name/role promises? Why does it depend on what it depends on (a bus injected only to call another handler, a service dressed as something else, an interface with a single handler consumer)? Is there a simpler, more honest primitive? Findings enter the flow like any other. If the fix adds no new architectural pieces, skip this.

## 3. Reinforcements by area

Only what the §2 skill doesn't already cover. Launch additionally in parallel if applicable:

- DB / queries, or a repeated call that leaves the process (external API, HTTP, cache, filesystem) → `agents.performance` agent from FLOW.md; if empty, use a general subagent with a performance role. Ask what **each failed iteration** sets off downstream, not just what the happy path costs.
- Workers / failure queue → `agents.queues` agent from FLOW.md to confirm the fix prevents recurrence; if empty, general subagent with a messaging role.

## 4. Over-engineering audit (fit + YAGNI)

A fix can also sneak in unnecessary defenses. Review the diff for new defensive mechanisms (validation, guard, retry, lock, fallback, cache, idempotency, circuit breaker):

- For each one: *"what real and present scenario in the project justifies this?"*. Verify against the code — can the flow actually reach that state, or is there something that already prevents it? If `domain_memory.enabled`, query `mcp__domain-memory__search_knowledge` if it depends on domain rules.
- A fix must be **minimal**: anything that doesn't directly address the root cause goes to Blockers with a proposed cut.

## 4.5. Completeness check (M/L, no loop)

A fix is minimal by design, so here one check is enough. **M/L only**: after consolidating findings from §2-§3, compare `git diff --stat <git.default_base>...HEAD` against what was reviewed. If any changed file from the fix wasn't looked at by any reviewer, give it a targeted pass and merge any new findings.

## 5. Adversarial finding verification (optional M/L)

If `meta.json.size` is **M or L** and there are **≥ 4** findings across blockers and suggestions, offer the user to filter them with a parallel skeptics panel (3 skeptics per finding, with a refute-by-default instruction; survives if fewer than 2 refute it). Discarded ones are noted under "Discarded by verification" with the reason. Not offered for XS/S or with fewer than 4 findings. In **`guided`/`auto`, do not ask** — run the filter and note in the artifact that you did; sending the user off to fix false positives is the worse outcome.

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
- Reviewers launched: <ran vs defined — `N/M` of the `review_skill`/`reviewers` roster, naming any that did not run (with the reason) and any substitution; "built-in only" if the depth ladder selected no panel>
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
- Without blockers: `phase = "review"`, add to `phases_done`. Suggest `/flow-bug-postmortem` (M/L) or `/flow-bug-ship` (XS/S).
- **Autonomy handoff.** Only without blockers — with blockers, stop in every mode. For **M/L**: in `manual`, propose `/flow-bug-postmortem` as a question; in `guided`/`auto`, **chain into it automatically** in this same turn. For **XS/S** the next step is `ship`, which pushes and opens the MR/PR — a hard gate in **every** mode: stop and propose `/flow-bug-ship` as a question, never chaining into it.
