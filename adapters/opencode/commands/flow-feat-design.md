---
description: Design the technical solution (architecture, DB, APIs, risks) before touching code
---

# `/flow-feat-design`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

Technical design phase. **Still no production code is written.** The output is a plan that the next step executes.

## 1. Pre-flight

- Load `meta.json` by current branch. If it does not exist, ask the user to start with `/flow-feat-start`.
- Read `01-context.md` and (if it exists) `02-brainstorm.md`.
- If `size` is `XS`, suggest jumping to `/flow-feat-build` and exit unless the user insists.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before inventorying the code, call `mcp__domain-memory__search_knowledge` with queries oriented at the **affected module** and **integrations** the design will touch. This often surfaces invisible domain decisions (legal constraints, integration assumptions, reasons behind a historical coupling) that cannot be inferred from the code alone.

Run 2-4 queries in parallel. Maximum wait time 2 s; if it fails, continue. Relevant results go at the top of the design under "Additional domain context" (§4 template). If `domain_memory.enabled` is `false` or empty, skip silently.

## 3. Prior inventory (reuse before creating)

**Before** launching the design subagents, identify what the feature needs that **already exists** in the code or database. This prevents subagents from proposing duplicate pieces. Launch a subagent (exploration mode) with an assignment along the lines of:

> For feature `<title>` (see `.claude/work/<TICKET>/01-context.md`), search the repo for related pieces that already exist and could be reused: domain entities, value objects, repositories, services, events, columns or tables, CQRS commands/queries, and similar endpoints. Do not propose design — just list each finding with one line and its location. If the feature mentions concepts like `<concept1>`, `<concept2>`, search for those specifically.

Save the result at the top of `03-design.md` under "## What already exists" (see §3). The design subagents read that section and only propose new pieces when they find no equivalent; if they propose a deliberate duplicate, they justify it.

## 4. Work

First, load the relevant project conventions (see `FLOW.md` section `conventions`).

Launch in **parallel** the subagents appropriate for the feature and project type. Subagents are invoked via `@name` as declared in `agents/` for the project (see `FLOW.md` fields `agents.*`); if the field is empty, use a general-purpose subagent with the role indicated in the prompt:

- **Always**: architecture subagent tasked with proposing: which module it lives in, new or modified entities/value objects, CQRS commands/queries (if applicable), events, repositories.
- **If it touches DB**: persistence subagent tasked with proposing mappings, required migrations, indexes, and the appropriate entity manager. **And filling the "Access paths" table** of the output: for every read or write the feature needs, the filter, the order **with its direction**, the bound and whether it is per key or global, the expected rows per key, and **the index that supports it** — checked against the schema that exists today, not assumed. An access path with no index behind it is a decision to take here, in writing, not a discovery to make in review: adding the index to the design is far cheaper than arguing about the query on an open MR/PR.
- **If it touches API/HTTP**: API subagent tasked with defining the endpoint, DTO, route, security, and response format (planning only, not implementation).
- **If it touches critical performance or high-traffic paths**: performance subagent to flag N+1, repeated out-of-process calls, or load risks.
- **If it touches security (authentication, payments, sensitive data)**: security subagent tasked with listing threats and mitigations in the proposed design.

Each subagent receives `01-context.md`, `02-brainstorm.md` (if it exists), and the "What already exists" section in its prompt. Explicit instructions in the assignment:

- **Before proposing a new entity/column/repository/service, check whether something from the inventory will do.** If a deliberate duplicate is introduced, justify it in the decisions table.
- **Do not add defensive mechanisms "just in case."** Every validation, guard, retry, lock, fallback, or cache proposed must be accompanied by the **real and present** scenario that requires it (with evidence: a `domain-memory` finding, a file, a known traffic pattern). If the scenario is hypothetical or the existing system already prevents it, **do not propose it**. Solve what the ticket asks for today, not future problems (YAGNI).

## 5. Output

Consolidate the outputs in `.claude/work/<TICKET>/03-design.md`:

```markdown
# Design <TICKET>

## Additional domain context
<focused search_knowledge results from §2, or "no findings">

## What already exists (inventory)
<list of reusable pieces located in §3, or "nothing equivalent found">

## Executive summary
<3-5 bullets on the chosen solution>

## Modules/layers affected
- <module/layer> — <what changes>

## Data model
- New / modified entities: <for each new one, state "no equivalent found" or "deliberate duplicate because...">
- Migrations:
- Indexes:

### Access paths
<one row per read or write the feature needs; "N/A — no data access" if it needs none. Filled from the schema that exists today, marking as `new` any index the design asks for. This table is what the data-access duel in review tries the finished query against.>

| Access | Filter | Order (with direction) | Bound | Rows per key (source) | Index that supports it |
|---|---|---|---|---|---|

- A bound that is **per key** never comes from a global limit: say which shape will carry it (one query per key, a union of per-key subqueries, a window function) and leave the choice to be measured later, not settled by preference now.
- For joins, state the type, length and charset/collation of **both** key columns when they are not obviously identical: a mismatch there silently costs the index and is invisible to every test.

## CQRS / Commands and Queries (if applicable)
- Commands:
- Queries:
- Handlers:
- Published events:

## API / HTTP (if applicable)
- Endpoint:
- DTO:
- Security:

## Identified risks
- Performance:
- Security:
- Compatibility:
- Online migrations:

## External contracts
<If this change touches a surface consumed from outside (another repo, another module, a deployed client, a worker, a migration referenced by name, a metric/dashboard, a domain event, an HTTP route), declare each contract as a literal here, not in prose. Any contract left in prose is ambiguous and will be a source of failures during build. If there is no external surface, write "none" and move on.

**Contracts received from another repo are not re-decided here.** If `01-context.md` has a `## Contracts received` section (`/flow-feat-start` §3.6), copy those contracts in **as-is**, marked `received from <repo>`. They are an input to this design, not an output of it: the other side may already be merged or deployed against them. If one looks wrong, raise it with that side — do not quietly design a better version, or the ticket ships two contracts and the disagreement surfaces at integration instead of here.>

### Contract N: <short description — e.g. "HTTP 402 quota_exceeded">
- **Type**: HTTP response body | header | route | domain event | DB column | metric | other.
- **Literal shape** (copy-pasteable format, not a description):
  ```json
  {"error":{"code":"quota_exceeded","message":"...","details":{"upgrade_url":"https://..."}}}
  ```
  or
  ```
  Header: X-Tracking-Id: <uuid>
  Route:  POST /api/internal/v1/resource:action
  Event:  ResourceWasCreated { resourceId, createdAt, userHash }
  Metric: resource.created — tags: [plan, status]
  ```
- **Known consumer**: <consumer name + path where it reads this contract, if known. If the consumer is one of the repos in `meta.json.related_repos`, **name it exactly as that entry's `repo`** — `/flow-feat-ship` §6 uses this field to decide which contracts to hand to which sibling, so an unnamed consumer forces the handoff to fall back to asking the user.>
- **Pattern deviation**: <if this contract does NOT follow how similar controllers/events/etc. in the repo do it, STATE IT EXPLICITLY here: "the other controllers return X, this one does NOT follow that pattern, it returns Y because Z">.

### Contract N+1: …

## Defensive mechanisms and their justification
<One row per validation, guard, retry, lock, fallback, cache, idempotency check, queue, or flag the design introduces. If you cannot name a REAL and PRESENT scenario that justifies it, the piece is unnecessary — remove it from the design.>

| Mechanism | Real scenario that justifies it (with evidence) | Needed now? |
|-----------|--------------------------------------------------|-------------|
| <e.g. lock on X> | <e.g. "two workers consume the same queue, see supervisor config"> | yes |
| <e.g. retry on API Y> | <if "just in case" with no scenario → OUT> | — |

## Implementation plan (order)
1. …
2. …

## Planned tests
- Unit:
- Integration:
- Functional:

## Decisions (ADR-light)
| Decision | Discarded alternative | Why |
|----------|-----------------------|-----|

## Design challenges
<filled in by §5 with the challenger table>
```

## 6. Design challenge (challenger)

Before closing, **challenge the design** by launching a general-purpose subagent with this assignment (self-contained):

> You are the critical reviewer of the design in `.claude/work/<TICKET>/03-design.md`. **Do not propose implementation.** Challenge the plan from 4 angles. The **first is the most important** and looks for the opposite of the others — it looks for what is UNNECESSARY.
>
> 1. **Fit and necessity (dominant angle — find what is unnecessary)**: review every defensive mechanism in the design (validation, guard, retry, lock, fallback, cache, idempotency, queue, flag). For each one ask:
>    - **Can that scenario actually occur in this project?** Do not assume — verify it: call `mcp__domain-memory__search_knowledge` and look at the relevant code. If the system already prevents that scenario (an upstream validates first, a constraint blocks it, the flow cannot reach that state, the external integration already guarantees it), the protection **is unnecessary** → finding "this is unnecessary".
>    - **Is it needed now, for what the ticket asks (YAGNI)?** If it solves a hypothetical future problem instead of today's → finding "this is unnecessary, YAGNI".
>    - Be specific about the reason: "X is unnecessary because in this project Y always happens first, see `<file>`/`<domain-memory finding>`".
> 2. **Fragile assumptions** (find what is missing): which beliefs in the design might not hold? What is the assumption, how could it fail, what would happen? **But before flagging it, confirm the failure is possible in the project** — do not invent theoretical fragilities.
> 3. **Simplification**: is there a simpler way to achieve the same result? Is any piece redundant with "What already exists"?
> 4. **Production operation**: rollback, observability, online migrations, side effects on workers/caches/queues. Only what genuinely applies to this change.
> 5. **Decision idiom (audit the "Decisions (ADR-light)" table)**: for each row `Decision | Discarded alternative | Why`:
>    - **False dichotomy**: the row frames the choice as exactly two options (A vs B). Is there an **option C** that was not considered? Name it. The classic trap: *"use the bus vs couple to the concrete class directly"* silently ignores *"expose a service behind an interface"* — which respects the boundary just as well without the downside. If the decision is binary, suspect a missing third path.
>    - **Rationale smell**: is the "Why" a *verifiable reason* or a *manual-sounding phrase* (*"respects bounded contexts"*, *"for consistency"*, *"follows the pattern"*)? If it can't be checked against a concrete constraint in this project, flag it — it must be made concrete, or marked as a claim to re-verify against the code in review. A justification that sounds like a textbook is how the wrong choice survives.
>    - **Primitive fit**: does each chosen primitive match its job by name and role (a Query that only reads, a Command that mutates state or emits events)? A primitive doing the opposite of its name is a design smell before it is a code smell.
>
> Read `01-context.md` for the business objective. Output: markdown table `| Angle | Finding | Type (unnecessary/missing/idiom) | Severity |` with severities `high`/`medium`/`low`. Under 550 words. Do not invent problems to fill space — if an angle has no findings, say "no findings". It is perfectly valid (and desirable) for the result to say "the design is tight, nothing unnecessary or missing".

If the feature touches a **sensitive domain** (payments, authentication, personal data, usage/tracking counters), launch **in parallel** a second general-purpose subagent focused specifically on that domain:

> Challenge the design from the angle of <domain>: what abuse scenarios are possible? What consistency guarantees are needed that the current design does not provide? What decisions may have regulatory or support consequences? Same table format.

Consolidate the findings at the end of `03-design.md` under:

```markdown
## Design challenges

| Angle | Finding | Type | Severity | Response |
|-------|---------|------|----------|----------|
| Fit/necessity | … | unnecessary | high | <empty at first — user fills it in> |
| Assumption | … | missing | medium | … |
| Decision idiom | … | idiom | high | … |
| Operation | … | missing | low | … |
```

**If there is a `high` severity with no response**: show the findings to the user and ask. The options depend on the type:

- If the finding is **"unnecessary"** (fit/YAGNI): **Cut** (remove the piece from the design — default option), or **Keep and justify** (fill in "Response" with the real scenario that requires it — if you cannot name one, it is unnecessary).
- If the finding is **"missing"** (assumption/operation): **Reopen brainstorm/design** to incorporate it, or **Accept and document** (fill in "Response" with the conscious assumption — `"We assume X because Y"`).
- If the finding is **"idiom"** (false dichotomy / rationale smell / primitive mismatch): **Adopt the third option or correct the primitive** (update the ADR row and the affected plan — default when option C is clearly better), or **Keep and make the "Why" concrete** (replace the manual-sounding phrase with a checkable reason; if you cannot, the decision is not justified). Do not leave the rationale as a textbook phrase.

Do not advance to wrap-up with unresolved high severities. Medium and low findings are informational. **A challenger that returns "nothing unnecessary or missing, the design is tight" is a good result, not a failure** — do not force findings.

## 7. Is the size still correct?

The design phase is when the real complexity of the work becomes visible (migrations, cross-module changes, integrations). If what emerges in `03-design.md` does not match `meta.json.size`:

- Propose reclassifying to the user.
- If confirmed, update `meta.json.size` and record in `meta.json.notes`.
- **Consequences**: moving from M to L activates the full flow. Moving from M to S removes `/flow-feat-plan` from the path. Explicitly warn the user of the flow change.

## 7.5 Cross-repo scope (refine)

Design is where a repo the conversation missed often surfaces (this change needs a consumer, a client, or a shared contract updated elsewhere). If `## Modules/layers affected` points at another repo, **add or update `meta.json.related_repos`** (`{ "repo", "scope", "status": "pending", "contract_handoff" }`); if a repo listed at `start` turns out not to be needed, drop it. flow only records it — the reminder fires at `/flow-feat-ship`.

This is also where `contract_handoff` gets its real value, because the contracts now exist: per entry, set it to `pending` if any contract in §"External contracts" names that repo as consumer, or `none` if the sibling's work touches nothing declared here. A `pending` is what makes `/flow-feat-ship` §6 offer the handoff; marking `none` on a repo that *does* consume a contract is exactly the silence this is meant to break.

## 8. Staging domain findings

If `domain_memory.enabled` is `true` in `FLOW.md`: review the decisions table (ADR-light) and the challenges to detect **non-obvious domain decisions** — things a future reader of the repo could not deduce by reading the code alone. Typical examples:

- "We decided not to use X because the external integration only guarantees Y under Z."
- "We coupled A with B because legal/tax requirements mandate that..."
- "The handler is intentionally non-idempotent because the domain allows it and it simplifies the flow."

**Evidence before staging.** Every finding carries one line of **evidence** — what you checked and against what. A finding is a claim about how *this project* behaves and will be read months later as settled fact by someone who will not re-derive it, so an unverified one is worse than none, because it is believed. **Claims about what the code does** are verified against `git.default_base` from `FLOW.md` — never your working branch, and never a train/integration branch: diffing against the parent shows your siblings' changes as though they were the baseline, so "the code already handles X" can be true where you stand and false on the default base. **Claims about generated output** — a query the ORM builds, a serialized payload, a rendered template, a resolved config — are verified against the output **actually produced**: dump it, log it, execute it. Reading the builder and predicting what it emits is precisely how a confident, wrong finding gets written down. If you cannot produce that line, **do not stage the finding**: say it did not survive verification and move on.

**Silence by default**: if there is nothing non-obvious, do not ask. If there are 1+ findings with a clear signal:

- Call `mcp__domain-memory__stage_finding` with the finding, its evidence line, and context. One call per finding.
- Briefly notify the user: "Staged X domain finding(s) to consolidate in `/flow-feat-ship`".

Do not invoke `save_knowledge` here — the final save is in `/flow-feat-ship` with a prior `read_staging`. If `domain_memory.enabled` is `false` or empty, skip silently.

## 9. Wrap-up

- Update `meta.json`: `phase = "design"`, add to `phases_done`.
- Ask the user to review the design. If they request changes, edit the artifact before advancing. **In `manual`/`guided`** this review is asked for; **in `auto` it is not** — record the design as accepted per the handoff below. Do not read this bullet as an unconditional stop: that contradiction is what turns an unattended run into a manual one.
- Next step based on size:
  - **XS / S**: suggest `/flow-feat-build` (single MR/PR, no need to plan a split).
  - **M / L**: suggest `/flow-feat-plan` to decide how to break the work into independently mergeable MRs/PRs before implementing.
- **Autonomy handoff.** Reviewing the design is a genuine decision point: in `manual` and `guided`, ask for that review before advancing. In `auto`, record the design as accepted in the artifact and **chain into the command for the size automatically** in this same turn. Unresolved `high`-severity findings stop the flow in **every** mode — do not chain over them.
