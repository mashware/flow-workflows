---
description: Design the technical solution (architecture, DB, APIs, risks) before touching code
---

# `/flow:feat:design`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

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

Technical design phase. **Still no production code is written.** The output is a plan that the next step executes.

## 1. Pre-flight

- Load `meta.json` by current branch. If it does not exist, ask the user to start with `/flow:feat:start`.
- Read `01-context.md` and (if it exists) `02-brainstorm.md`.
- If `size` is `XS`, suggest jumping to `/flow:feat:build` and stop unless the user insists.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before inventorying the code, call `mcp__domain-memory__search_knowledge` with queries oriented at the **affected module** and **integrations** the design will touch. This often uncovers domain decisions invisible from the code (legal constraints, integration assumptions, reasons for a historical coupling).

Launch 2-4 queries in parallel. Timeout 2 s; if it fails, continue. Relevant hits go at the top of the design under "Additional domain context" (§4 template). If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 3. Prior inventory (reuse before creating)

**Before** launching the design subagents, identify what the feature needs that **already exists** in the code or database. This prevents architects from proposing duplicate pieces. Launch an `Agent` with `subagent_type: Explore` with a brief like:

> For feature `<title>` (see `.claude/work/<TICKET>/01-context.md`), search the repo for related pieces that already exist and could be reused: domain entities, value objects, repositories, services, events, columns or tables, CQRS commands/queries, and similar endpoints. Do not propose design — only list what is found with one line each and its location. If the feature mentions concepts like `<concept1>`, `<concept2>`, search for those specifically.

Save the result at the top of `03-design.md` under "## What already exists" (see §3). Design subagents read that section and only propose new things when nothing equivalent is found; if they knowingly propose a duplicate, they justify it.

## 4. Work

Load the relevant skills for the project first (see `FLOW.md` section `conventions`).

Launch the appropriate subagents **in parallel** based on the feature and project type:

- **Always**: `agents.architecture` agent (or `Agent general-purpose` if empty) tasked with proposing: module where it lives, new or modified entities/value objects, CQRS commands/queries (if applicable), events, repositories.
- **If it touches DB**: `agents.persistence` agent (or `Agent general-purpose` if empty) tasked with proposing mappings, required migrations, indexes, and appropriate entity manager.
- **If it touches API/HTTP**: `agents.api` agent (or `Agent general-purpose` if empty) tasked with defining endpoint, DTO, route, security, and response format (planning only, no implementation).
- **If it touches critical performance or hot paths**: `agents.performance` agent (or `Agent general-purpose` if empty) to anticipate N+1, repeated out-of-process calls, or load risks.
- **If it touches security (authentication, payments, sensitive data)**: `agents.security` agent (or `Agent general-purpose` if empty) tasked with listing threats and mitigations for the proposed design.

For each area, use the agent defined in `agents.<role>` in `FLOW.md`; if that field is empty, use `Agent general-purpose` with the role in the prompt.

Each subagent receives `01-context.md`, `02-brainstorm.md` (if it exists) and the "What already exists" section in its prompt. Explicit instructions in the brief:

- **Before proposing a new entity/column/repository/service, check whether something from the inventory works.** If duplicating knowingly, justify in the decision table.
- **Do not add defensive mechanisms "just in case".** Every proposed validation, guard, retry, lock, fallback, or cache must be accompanied by the **real and present** scenario that requires it (with evidence: a `domain-memory` finding, a file, a known traffic pattern). If the scenario is hypothetical or the current system already prevents it, **do not propose it**. Solve what the ticket asks for today, not future problems (YAGNI).

## 5. Output

Consolidate outputs into `.claude/work/<TICKET>/03-design.md`:

```markdown
# Design <TICKET>

## Additional domain context
<hits from the focused search_knowledge in §2, or "no findings">

## What already exists (inventory)
<list of reusable pieces located in §3, or "nothing equivalent found">

## Executive summary
<3-5 bullets of the chosen solution>

## Acceptance criteria
<The WHAT: observable, verifiable conditions that must hold for the feature to be "done", distinct from the design's HOW. The feature is done **iff** every criterion holds. Each criterion gets a stable ID (`AC1`, `AC2`, …), is written given/when/then or as a clear assertion, and uses the **literal** values from "External contracts" / "Internal behavioral contracts" below for its concrete result — never prose like "works correctly". Proportional to size: XS/S → a couple of criteria covering what the ticket asks today, no hypothetical futures; M/L → one per distinct observable behavior. Do not manufacture criteria to fill space — the same restraint as the challenger.>

| ID | Given / When / Then (or clear assertion) | Proof |
|----|------------------------------------------|-------|
| AC1 | Given <state>, when <action>, then <observable result with literal value> | test \| manual |
| AC2 | … | … |

`Proof` is a hint at how the criterion will be demonstrated in `/flow:feat:validate`: `test` (an automated test can prove it) or `manual` (UI / end-to-end flow verified together with the user). It is a hint, not a commitment — `/flow:feat:validate` builds the real criterion→test mapping and gates against it.

## Modules/layers affected
- <module/layer> — <what changes>

## Data model
- New / modified entities: <for each new one, indicate "no equivalent found" or "knowingly duplicated because...">
- Migrations:
- Indexes:

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
<If this change touches a surface consumed from outside (another repo, another module, a deployed client, a worker, a migration referenced by name, a metric/dashboard, a domain event, an HTTP route), declare **each contract as a literal** here, not in prose. Any contract left in prose is ambiguous and will be a source of failures at build time. If there is no external surface, write "none" and move on.

**Contracts received from another repo are not re-decided here.** If `01-context.md` has a `## Contracts received` section (`/flow:feat:start` §3.6), copy those contracts into this section **as-is** and mark them `received from <repo>`. They are an input to the design, not an output of it: the other side may already be merged or deployed against them. If one looks wrong, raise it with that side — do not quietly design a better version, because the result is two repos shipping two contracts for one ticket, and the disagreement surfaces at integration instead of here.>

### Contract N: <short description — e.g. "HTTP 402 quota_exceeded">
- **Type**: HTTP response body | header | route | domain event | DB column | metric | other.
- **Literal shape** (copyable format, not a description):
  ```json
  {"error":{"code":"quota_exceeded","message":"...","details":{"upgrade_url":"https://..."}}}
  ```
  or
  ```
  Header: X-Tracking-Id: <uuid>
  Route:  POST /api/internal/v1/resource:action
  Event: ResourceWasCreated { resourceId, createdAt, userHash }
  Metric: resource.created — tags: [plan, status]
  ```
- **Known consumer**: <consumer name + path where it reads this contract, if known. If the consumer is one of the repos in `meta.json.related_repos`, **name it exactly as that entry's `repo`** — `/flow:feat:ship` §6.3 uses this field to decide which contracts to hand over to which sibling, so an unnamed consumer means the handoff has to fall back to asking the user.>
- **Pattern deviation**: <if this contract does NOT follow how other similar controllers/events/etc. in the repo do it, ANNOUNCE it explicitly here: "the other controllers return X, this one does NOT follow that pattern, it returns Y because Z">.

### Contract N+1: …

## Internal behavioral contracts
<Same anti-ambiguity rigor as "External contracts", applied to behavior with **no** external surface: a domain rule, a service's pre/postconditions, a calculation's expected outputs, a state transition. Express each as a concrete, **checkable** statement — literal inputs → literal outputs, or an exact invariant — never prose like "calculates the discount correctly". Each one should map directly to an acceptance criterion above (it is what gives that criterion its literal teeth). If the change has no non-trivial internal behavior (pure wiring, a rename), write "none" and move on — do not invent rules to fill space.>

- **Rule / postcondition**: <e.g. "discount(plan=pro, seats=5) → 15% off; discount(plan=free, *) → 0%">
- **Invariant**: <e.g. "after assignTo(user), ticket.assignee == user AND ticket.status != 'unassigned'">
- **Edge / boundary**: <e.g. "empty input list → returns 0, does not throw">

## Defensive mechanisms and their justification
<One row per validation, guard, retry, lock, fallback, cache, idempotency, queue, or flag the design introduces. If you cannot name a REAL and PRESENT scenario that justifies it, the piece is unnecessary — remove it from the design.>

| Mechanism | Real scenario that justifies it (with evidence) | Needed now? |
|-----------|--------------------------------------------------|-------------|
| <e.g. lock on X> | <e.g. "two workers consume the same queue, see supervisor config"> | yes |
| <e.g. retry on API Y> | <if "just in case" with no scenario → OUT> | — |

## Implementation plan (order)
1. …
2. …

## Planned tests
<Map each planned test to the acceptance criteria it proves (AC ids). A test that proves no criterion and guards no contract is a candidate to cut. Criteria marked `manual` above need no automated test here — they are verified with the user in `/flow:feat:validate`.>
- Unit:
- Integration:
- Functional:

## Decisions (ADR-light)
| Decision | Discarded alternative | Why |
|----------|-----------------------|-----|

## Design challenges
<filled in by §5 with the challenger table>
```

When filling **"Acceptance criteria"**: start from the provisional list in `01-context.md` (pinned from the ticket in `/flow:feat:start`), fold in the clarifications and the internal/external contracts decided here, and promote it to the canonical, enumerated list. This is the list `/flow:feat:validate` gates against — keep it observable, verifiable, and proportional to size.

## 6. Design challenge (challenger)

Before closing, **challenge the design** by launching an `Agent general-purpose` with this brief (self-contained):

> You are the critical reviewer of the design in `.claude/work/<TICKET>/03-design.md`. **Do not propose implementation.** Challenge the plan from 4 angles. The **first is the most important** and looks for the opposite of the others — it looks for what is UNNECESSARY.
>
> 1. **Fit and need (dominant angle — look for what is unnecessary)**: review every defensive mechanism in the design (validation, guard, retry, lock, fallback, cache, idempotency, queue, flag). For each one ask:
>    - **Can that scenario actually happen in this project?** Do not assume — verify: query `mcp__domain-memory__search_knowledge` and look at the relevant code. If the system already prevents that scenario (an upstream validates first, a constraint blocks it, the flow does not allow that state, the external integration already guarantees it), the protection is **unnecessary** → finding "this is unnecessary".
>    - **Is it needed now, for what the ticket asks (YAGNI)?** If it solves a hypothetical future problem instead of today's → finding "this is unnecessary, it is YAGNI".
>    - Be concrete about the why: "X is unnecessary because in this project Y always happens first, see `<file>`/`<domain-memory finding>`".
> 2. **Fragile assumptions** (look for what is missing): what beliefs in the design might not hold? What is each one, how could it fail, what would happen? **But before flagging it, confirm the failure is possible in the project** — do not invent theoretical fragilities.
> 3. **Simplification**: is there a simpler way to achieve the same? Is any piece redundant with "What already exists"?
> 4. **Production operation**: rollback, observability, online migrations, cross-effects with workers/caches/queues. Only what truly applies to this change.
> 5. **Decision idiom (audit the "Decisions (ADR-light)" table)**: for each row `Decision | Discarded alternative | Why`:
>    - **False dichotomy**: the row frames the choice as exactly two options (A vs B). Is there an **option C** that was not considered? Name it. The classic trap: *"use the bus vs couple to the concrete class directly"* silently ignores *"expose a service behind an interface"* — which respects the boundary just as well without the downside. If the decision is binary, suspect a missing third path.
>    - **Rationale smell**: is the "Why" a *verifiable reason* or a *manual-sounding phrase* (*"respects bounded contexts"*, *"for consistency"*, *"follows the pattern"*)? If it cannot be checked against a concrete constraint in this project, flag it — it must be made concrete, or marked as a claim to re-verify against the code in review. A justification that sounds like a textbook is how the wrong choice survives.
>    - **Primitive fit**: does each chosen primitive match its job by name and role (a Query that only reads, a Command that mutates state or emits events)? A primitive doing the opposite of its name is a design smell before it is a code smell.
>
> Read `01-context.md` for the business goal. Output: markdown table `| Angle | Finding | Type (unnecessary/missing/idiom) | Severity |` with severities `high`/`medium`/`low`. Under 550 words. Do not invent problems to fill space — if an angle has no findings, say "no findings". It is perfectly valid (and desirable) for the result to say "the design is tight, nothing unnecessary or missing".

If the feature touches a **sensitive domain** (payments, authentication, personal data, usage/tracking counters), launch **in parallel** a second `Agent general-purpose` focused on that domain:

> Challenge the design from the <domain> angle: what abuse cases are possible? What consistency guarantees are needed that the current design does not provide? What decisions may have regulatory or support consequences? Same table format.

Consolidate findings at the end of `03-design.md` under:

```markdown
## Design challenges

| Angle | Finding | Type | Severity | Response |
|-------|---------|------|----------|----------|
| Fit/need | … | unnecessary | high | <empty at first — user fills in> |
| Assumption | … | missing | medium | … |
| Decision idiom | … | idiom | high | … |
| Operation | … | missing | low | … |
```

**If there is a `high` severity without a response**: show the findings to the user and ask with `AskUserQuestion`. Options depend on the type:

- If the finding is **"unnecessary"** (fit/YAGNI): **Cut it** (remove the piece from the design — default option), or **Keep and justify** (fill in "Response" with the real scenario that requires it — if you cannot name one, it is unnecessary).
- If the finding is **"missing"** (assumption/operation): **Reopen brainstorm/design** to incorporate it, or **Assume and document** (fill in "Response" with the conscious assumption — `"We assume X because Y"`).
- If the finding is **"idiom"** (false dichotomy / rationale smell / primitive mismatch): **Adopt the third option or correct the primitive** (update the ADR row and the affected plan — default when option C is clearly better), or **Keep and make the "Why" concrete** (replace the manual-sounding phrase with a checkable reason; if you cannot, the decision is not justified). Do not leave the rationale as a textbook phrase.

Do not advance to close with unresolved high severities. Medium and low ones are informational — they stay on record so code review has them in view. **A challenger that returns "nothing unnecessary or missing, the design is tight" is a good result, not a failure** — do not force findings.

## 7. Is the size still correct?

Design is when the real complexity of the work becomes visible (migrations, cross-module, integrations). If what comes out in `03-design.md` does not fit `meta.json.size`:

- Propose reclassifying to the user (`AskUserQuestion`).
- If confirmed, update `meta.json.size` and note in `meta.json.notes`.
- **Consequences**: moving from M to L activates the full flow. Moving from M to S removes `/flow:feat:plan` from the path. Explicitly inform the user of the flow change.

## 7.5 Cross-repo scope (refine)

Design is where a repo the conversation missed often surfaces (this change needs a consumer, a client, or a shared contract updated elsewhere). If `## Modules/layers affected` points at another repo, **add or update `meta.json.related_repos`** (`{ "repo", "scope", "status": "pending", "contract_handoff" }`); if a repo listed at `start` turns out not to be needed, drop it. flow only records it — the reminder fires at `/flow:feat:ship`.

This is also where `contract_handoff` gets its real value, because the contracts now exist: for each entry, set it to `pending` if any contract in §"External contracts" names that repo as its consumer, or `none` if the sibling's work touches nothing declared here (a UI-only change, an independent migration). A `pending` here is what makes `/flow:feat:ship` §6.3 offer the handoff; leaving it `none` on a repo that does consume a contract is exactly the silence this is meant to break.

## 8. Domain findings staging

If `domain_memory.enabled` is `true` in `FLOW.md`: review the decision table (ADR-light) and the challenges to detect **non-obvious domain decisions** — things a future reader of the repo could not deduce just by reading the code. Typical examples:

- "We decided not to use X because the external integration only guarantees Y under Z."
- "We coupled A with B because legal/fiscal requirements demand that..."
- "The handler is intentionally non-idempotent because the domain allows it and simplifies the flow."

**Evidence before staging.** Every finding carries one line of **evidence** — what you checked and against what — recorded with it in the call. A finding is a claim about how *this project* behaves, and it will be read months from now as settled fact by someone who will not re-derive it; an unverified finding is worse than no finding, because it is believed. Two rules on what counts:

- **Claims about what the code does** are verified against `git.default_base` from `FLOW.md` — not against your working branch, and **never against a train/integration branch**. On a stacked branch, diffing against the parent shows your siblings' changes as though they were the baseline, so "the code already handles X" can be true where you are standing and false on the default base, which is the only place the claim will matter.
- **Claims about generated output** — a query the ORM builds, a serialized payload, a rendered template, a resolved config — are verified against the output **actually produced**: dump it, log it, execute it. Reading the builder and predicting what it emits is precisely how a confident, wrong finding gets written down.

If you cannot produce that line for a finding, **do not stage it**: tell the user it did not survive verification and move on. A finding withdrawn here costs nothing; one that lands in the store wrong gets trusted.

**Silence by default**: if there is nothing non-obvious, do not ask. If there are 1+ findings with a clear signal:

- Call `mcp__domain-memory__stage_finding` with the finding, its evidence line, and the context. One call per finding.
- Briefly inform the user: "Staged X domain finding(s) to consolidate in `/flow:feat:ship`".

Do not invoke `save_knowledge` here — the final save is in `/flow:feat:ship` with a prior `read_staging`. If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 9. Close

- Update `meta.json`: `phase = "design"`, add to `phases_done`.
- **Confirm the acceptance criteria** as part of the design review: present the enumerated list to the user. If every criterion is unambiguous and verifiable, the design review covers them — no separate prompt. Escalate to `AskUserQuestion` **only** when a criterion is ambiguous, not verifiable, or you suspect one is missing for what the ticket asks today (same restraint as the challenger — do not invent criteria). The user can edit/add/remove; apply their edits to `03-design.md` before advancing.
- **In `manual`/`guided`**, ask the user to review the design; if they request changes, edit the artifact before advancing. **In `auto`, do not ask** — record it as accepted per the handoff below. Do not read this bullet as an unconditional stop: that is the contradiction that turns an unattended run into a manual one.
- Next step by size:
  - **XS / S**: suggest `/flow:feat:build` (1 single MR/PR, no need to plan splitting).
  - **M / L**: suggest `/flow:feat:plan` to decide how to split the work into independently mergeable MRs/PRs before implementing.
- **Autonomy handoff.** Reviewing the design is a genuine decision point, so in `manual` and `guided` ask for the review before advancing. In `auto`, record the design as accepted in the artifact and **chain into the command for the size automatically** in this same turn. In `manual`, propose that command with a single `AskUserQuestion` (recommended option by default) rather than leaving it as a written suggestion. Unresolved `high`-severity findings in §8 stop the flow in **every** mode — do not chain over them.
