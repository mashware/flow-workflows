# `/feat-design`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Technical design phase. **Still no production code.** The output is a plan the next step executes.

## 1. Pre-flight

- Load `meta.json` by current branch. If it doesn't exist, ask the user to start with `/feat-start`.
- Read `01-context.md` and (if it exists) `02-brainstorm.md`.
- If `size` is `XS`, suggest jumping to `/feat-build` and stop unless the user insists.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before inventorying the code, call `mcp__domain-memory__search_knowledge` with queries aimed at the **affected module** and **integrations** the design will touch. This often uncovers domain decisions invisible from the code (legal constraints, integration assumptions, reasons for historical coupling).

Run 2-4 queries in parallel. Maximum wait time 2s; if it fails, continue. Relevant hits go at the start of the design under "Additional domain context" (§4 template). If `domain_memory.enabled` is `false` or empty, skip without comment.

## 3. Pre-inventory (reuse before creating)

**Before** launching the design subagents, identify what the feature needs that **already exists** in the code or database. Launch an exploration subagent with an assignment like:

> For the feature `<title>` (see `.claude/work/<TICKET>/01-context.md`), search the repo for related pieces that already exist and could be reused: domain entities, value objects, repositories, services, events, columns or tables, CQRS commands/queries, and similar endpoints. Don't propose a design — only list what you find with one line each and its location. If the feature mentions concepts like `<concept1>`, `<concept2>`, search specifically for those.

Save the result at the start of `03-design.md` under "## What already exists" (see §3). The design subagents read that section and only propose new things when they find no equivalent; if they knowingly propose duplication, they justify it.

## 4. Work

First load the relevant skills per the project (see `FLOW.md` section `conventions`).

Launch in **parallel** the subagents that apply based on the feature and project type:

- **Always**: agent `agents.architecture` (or general subagent if empty) assigned to propose: module where it lives, new or modified entities/value objects, CQRS commands/queries (if applicable), events, repositories.
- **If it touches DB**: agent `agents.persistence` (or general subagent if empty) assigned to propose mappings, necessary migrations, indexes, and appropriate entity manager.
- **If it touches API/HTTP**: agent `agents.api` (or general subagent if empty) assigned to define endpoint, DTO, route, security, and response format (planning only, no implementation).
- **If it touches critical performance or hot paths**: agent `agents.performance` (or general subagent if empty) to anticipate N+1 or load risks.
- **If it touches security (authentication, payments, sensitive data)**: agent `agents.security` (or general subagent if empty) assigned to list threats and mitigations of the proposed design.

For each area, use the agent defined in `agents.<role>` from `FLOW.md`; if that field is empty, use a general subagent with the role in the prompt.

Each subagent receives `01-context.md`, `02-brainstorm.md` (if it exists), and the "What already exists" section in their prompt. Explicit instructions in the assignment:

- **Before proposing a new entity/column/repository/service, check whether something from the inventory will do.** If duplicating knowingly, justify it in the decisions table.
- **Do not add defensive mechanisms "just in case".** Every proposed validation, guard, retry, lock, fallback mechanism, or cache must be accompanied by the **real and present** scenario that requires it (with evidence: a `domain-memory` finding, a file, a known traffic pattern). If the scenario is hypothetical or the current system already prevents it, **don't propose it**. Solve what the ticket asks for today, not future problems (YAGNI).

## 5. Output

Consolidate the outputs into `.claude/work/<TICKET>/03-design.md`:

```markdown
# Design <TICKET>

## Additional domain context
<hits from the focused search_knowledge in §2, or "no findings">

## What already exists (inventory)
<list of reusable pieces found in §3, or "nothing equivalent">

## Executive summary
<3-5 bullets of the chosen solution>

## Affected modules/layers
- <module/layer> — <what changes>

## Data model
- New / modified entities: <for each new one, indicate "no equivalent found" or "duplicated knowingly because...">
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
- Live migrations:

## External contracts
<If this change touches a surface consumed from outside (another repo, another module, a deployed client, a worker, a migration referenced by name, a metric/dashboard, a domain event, an HTTP route), declare each contract here as a **literal**, not prose. If there's no external surface, write "none" and move on.>

### Contract N: <short description>
- **Type**: HTTP response body | header | route | domain event | DB column | metric | other.
- **Literal shape** (copy-pasteable format, not a description):
  ```json
  {"error":{"code":"quota_exceeded","message":"...","details":{"upgrade_url":"https://..."}}}
  ```
- **Known consumer**: <consumer name + path where it reads this contract, if known>
- **Pattern deviation**: <if this contract does NOT follow how other similar controllers/events/etc. in the repo do it, ANNOUNCE it here explicitly>.

## Defensive mechanisms and their justification
<One row per validation, guard, retry, lock, fallback mechanism, cache, idempotency, queue, or flag the design introduces. If you cannot name a REAL and PRESENT scenario that justifies it, the piece is unnecessary — remove it from the design.>

| Mechanism | Real scenario that justifies it (with evidence) | Needed now? |
|-----------|--------------------------------------------------|-------------|

## Implementation plan (order)
1. …
2. …

## Planned tests
- Unit:
- Integration:
- Functional:

## Decisions (ADR-light)
| Decision | Discarded alternative | Why |

## Design challenges
<filled by §5 with the challenger table>
```

## 6. Design challenge (challenger)

Before closing, **challenge the design** by launching a general subagent with this assignment (self-contained):

> You are the critical design reviewer for `.claude/work/<TICKET>/03-design.md`. **Do not propose an implementation.** Challenge the plan from 4 angles. The **first is the most important** and looks for the opposite of the others — it looks for what is UNNECESSARY.
>
> 1. **Fit and necessity (dominant angle — look for what's unnecessary)**: review each defensive mechanism in the design (validation, guard, retry, lock, fallback, cache, idempotency, queue, flag). For each one ask:
>    - **Can that scenario actually happen in this project?** Don't assume — verify: query `mcp__domain-memory__search_knowledge` and look at the relevant code. If the system already prevents that scenario, the protection is **unnecessary** → finding "this is unnecessary".
>    - **Is it needed now, for what the ticket asks (YAGNI)?** If it solves a hypothetical future problem instead of today's → finding "this is unnecessary, it's YAGNI".
>    - Be specific about why.
> 2. **Fragile assumptions** (look for what's missing): what beliefs in the design might not hold? Confirm the failure is possible in the project — don't invent theoretical fragilities.
> 3. **Simplification**: is there a simpler way to achieve the same thing? Is any piece redundant with "What already exists"?
> 4. **Production operation**: rollback, observability, live migrations, cross-effects with workers/caches/queues. Only what genuinely applies to this change.
>
> Output: markdown table `| Angle | Finding | Type (unnecessary/missing) | Severity |` with severities `high`/`medium`/`low`. Under 500 words. Don't invent problems to fill space — if an angle has no findings, say "no findings".

If the feature touches **sensitive domain** (payments, authentication, personal data, usage/tracking counters), launch **in parallel** a second general subagent focused specifically on that domain.

Consolidate findings at the end of `03-design.md` under:

```markdown
## Design challenges

| Angle | Finding | Type | Severity | Response |
|-------|---------|------|----------|----------|
```

**If there are `high`-severity findings without a response**: show the findings to the user and ask. The options depend on the type:

- If the finding is **"unnecessary"**: **Cut** (remove the piece from the design — default option), or **Keep and justify** (fill "Response" with the real scenario — if you can't name one, it's unnecessary).
- If the finding is **"missing"**: **Reopen brainstorm/design** to incorporate it, or **Assume and document** (fill "Response" with the conscious assumption).

Do not advance to close with high-severity findings without a response. Medium and low are informational.

## 7. Is the size still right?

If what comes out of `03-design.md` doesn't fit `meta.json.size`:

- Propose reclassifying to the user.
- If confirmed, update `meta.json.size` and note in `meta.json.notes`.
- **Consequences**: going from M to L activates the full flow. Going from M to S removes `/feat-plan` from the path. Explicitly warn the user of the flow change.

## 8. Domain knowledge staging

If `domain_memory.enabled` is `true` in `FLOW.md`: review the decisions table (ADR-light) and challenges to detect **non-obvious domain decisions** — things a future reader of the repo could not deduce from reading only the code.

**Silence by default**: if there's nothing non-obvious, don't ask. If there are 1+ findings with a clear signal:

- Call `mcp__domain-memory__stage_finding` with the finding and context. One call per finding.
- Briefly notify the user: "Staged X domain finding(s) to consolidate in `/feat-ship`".

Do not call `save_knowledge` here — the final save is in `/feat-ship`. If `domain_memory.enabled` is `false` or empty, skip without comment.

## 9. Close

- Update `meta.json`: `phase = "design"`, add to `phases_done`.
- Ask the user to review the design. If they request changes, edit them in the artifact before advancing.
- Next step based on size:
  - **XS / S**: suggest `/feat-build` (1 single MR/PR, no need to plan splitting).
  - **M / L**: suggest `/feat-plan` to decide how to split the work into independently mergeable MRs/PRs before implementing.
