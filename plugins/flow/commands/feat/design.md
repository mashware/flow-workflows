---
description: Design the technical solution (architecture, DB, APIs, risks) before touching code
---

# `/feat:design`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Technical design phase. **Still no production code is written.** The output is a plan that the next step executes.

## 1. Pre-flight

- Load `meta.json` by current branch. If it does not exist, ask the user to start with `/feat:start`.
- Read `01-context.md` and (if it exists) `02-brainstorm.md`.
- If `size` is `XS`, suggest jumping to `/feat:build` and stop unless the user insists.

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
- **If it touches critical performance or hot paths**: `agents.performance` agent (or `Agent general-purpose` if empty) to anticipate N+1 or load risks.
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
<If this change touches a surface consumed from outside (another repo, another module, a deployed client, a worker, a migration referenced by name, a metric/dashboard, a domain event, an HTTP route), declare **each contract as a literal** here, not in prose. Any contract left in prose is ambiguous and will be a source of failures at build time. If there is no external surface, write "none" and move on.>

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
- **Known consumer**: <consumer name + path where it reads this contract, if known>
- **Pattern deviation**: <if this contract does NOT follow how other similar controllers/events/etc. in the repo do it, ANNOUNCE it explicitly here: "the other controllers return X, this one does NOT follow that pattern, it returns Y because Z">.

### Contract N+1: …

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
>
> Read `01-context.md` for the business goal. Output: markdown table `| Angle | Finding | Type (unnecessary/missing) | Severity |` with severities `high`/`medium`/`low`. Under 500 words. Do not invent problems to fill space — if an angle has no findings, say "no findings". It is perfectly valid (and desirable) for the result to say "the design is tight, nothing unnecessary or missing".

If the feature touches a **sensitive domain** (payments, authentication, personal data, usage/tracking counters), launch **in parallel** a second `Agent general-purpose` focused on that domain:

> Challenge the design from the <domain> angle: what abuse cases are possible? What consistency guarantees are needed that the current design does not provide? What decisions may have regulatory or support consequences? Same table format.

Consolidate findings at the end of `03-design.md` under:

```markdown
## Design challenges

| Angle | Finding | Type | Severity | Response |
|-------|---------|------|----------|----------|
| Fit/need | … | unnecessary | high | <empty at first — user fills in> |
| Assumption | … | missing | medium | … |
| Operation | … | missing | low | … |
```

**If there is a `high` severity without a response**: show the findings to the user and ask with `AskUserQuestion`. Options depend on the type:

- If the finding is **"unnecessary"** (fit/YAGNI): **Cut it** (remove the piece from the design — default option), or **Keep and justify** (fill in "Response" with the real scenario that requires it — if you cannot name one, it is unnecessary).
- If the finding is **"missing"** (assumption/operation): **Reopen brainstorm/design** to incorporate it, or **Assume and document** (fill in "Response" with the conscious assumption — `"We assume X because Y"`).

Do not advance to close with unresolved high severities. Medium and low ones are informational — they stay on record so code review has them in view. **A challenger that returns "nothing unnecessary or missing, the design is tight" is a good result, not a failure** — do not force findings.

## 7. Is the size still correct?

Design is when the real complexity of the work becomes visible (migrations, cross-module, integrations). If what comes out in `03-design.md` does not fit `meta.json.size`:

- Propose reclassifying to the user (`AskUserQuestion`).
- If confirmed, update `meta.json.size` and note in `meta.json.notes`.
- **Consequences**: moving from M to L activates the full flow. Moving from M to S removes `/feat:plan` from the path. Explicitly inform the user of the flow change.

## 8. Domain findings staging

If `domain_memory.enabled` is `true` in `FLOW.md`: review the decision table (ADR-light) and the challenges to detect **non-obvious domain decisions** — things a future reader of the repo could not deduce just by reading the code. Typical examples:

- "We decided not to use X because the external integration only guarantees Y under Z."
- "We coupled A with B because legal/fiscal requirements demand that..."
- "The handler is intentionally non-idempotent because the domain allows it and simplifies the flow."

**Silence by default**: if there is nothing non-obvious, do not ask. If there are 1+ findings with a clear signal:

- Call `mcp__domain-memory__stage_finding` with the finding and the context. One call per finding.
- Briefly inform the user: "Staged X domain finding(s) to consolidate in `/feat:ship`".

Do not invoke `save_knowledge` here — the final save is in `/feat:ship` with a prior `read_staging`. If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 9. Close

- Update `meta.json`: `phase = "design"`, add to `phases_done`.
- Ask the user to review the design. If they request changes, edit the artifact before advancing.
- Next step by size:
  - **XS / S**: suggest `/feat:build` (1 single MR/PR, no need to plan splitting).
  - **M / L**: suggest `/feat:plan` to decide how to split the work into independently mergeable MRs/PRs before implementing.
