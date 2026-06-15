# `/feat-brainstorm`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Exploration phase. **Does not write code.** Only opens the solution space so the design doesn't start from the first idea.

## 1. Pre-flight

- Locate the active `meta.json`: look first by the current branch (`git branch --show-current`), otherwise ask the user for the ticket.
- If `meta.json.phase` is not `context`, warn and ask whether to continue anyway.
- If `size` is `XS` or `S`, suggest jumping directly to `/feat-design` or `/feat-build` and stop (unless the user insists).
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before generating options, call `mcp__domain-memory__search_knowledge` with queries focused on the **concept/pattern** the feature covers, not on the generic title (that was already queried in `/feat-start`). Examples by area:

- If the feature touches tracking → `"tracking deduplication"`, `"hash collision"`.
- If it touches payments → `"trial expiration"`, `"plan downgrade flow"`.
- If it touches external integrations → `"attachment handler"`, `"tax rules integration"`.

Run 2-3 queries in parallel. Maximum wait time 2s; if it fails, continue without context and do not notify the user. Note relevant hits in `02-brainstorm.md` under "Additional domain knowledge" (don't repeat what's already in `01-context.md`). If `domain_memory.enabled` is `false` or empty, skip without comment.

## 3. Work

### 3.0 Multi-agent panel or single agent?

- If `meta.json.size` is **M or L**: offer the **parallel approaches panel** ("Generate options with a parallel subagent panel? More token-expensive, less single-line-of-thought bias."). If accepted → §3.A. If declined → §3.B.
- If **S** (or user declined): §3.B directly. Panel is not offered for XS/S — the cost doesn't justify it.

### 3.A Approaches panel (subagents in parallel)

Launch **four subagents in parallel** (one per lens), without them seeing each other to ensure genuine diversity, then a fifth that synthesizes and orders the results:

Lenses:
- **minimal**: the SMALLEST approach that solves the declared use case, nothing more (strict MVP).
- **reuse**: the approach that MOST reuses existing pieces in the affected module or neighbors.
- **operations**: the most solid approach for production (observability, external integration failure, data at scale).
- **reframing**: questions the premise: what if the problem can be solved without building what's requested, or somewhere else?

Each lens agent receives: the ticket, the path to `.claude/work/<TICKET>/01-context.md`, and the lens assigned. Returns: approach name, what it is (one sentence), affected modules/layers, main risk, why it could be a bad idea.

The synthesizer agent receives the four structured verdicts and orders them from best to worst for THIS case (project fit + simplicity), with an initial recommendation of 2-3 lines of justification.

Using the result, fill §4 (each approach → one "Option", the synthesis → "Initial recommendation"). If a subagent fails, simply don't include it.

### 3.B Single agent (default case)

Launch a `general-purpose` subagent with this assignment (brief, self-contained):

> Generate 3-5 distinct approaches to solve `<title>` following the project conventions (see `FLOW.md` and `.claude/work/<TICKET>/01-context.md`). For each approach: one sentence of what it is, affected modules/layers, main risk, and why it could be a bad idea. Do not write code. Report in markdown under 400 words.

If the feature touches sensitive domain (payments, authentication, tracking), launch **in parallel** a second `general-purpose` subagent focused on "what can go wrong" for that domain.

## 4. Output

Create `.claude/work/<TICKET>/02-brainstorm.md`:

```markdown
# Brainstorm <TICKET>

## Additional domain knowledge
<hits from the focused search_knowledge, or "no findings">

## Options considered
### Option A: <name>
- What it is:
- Affected modules/layers:
- Main risk:
- Why it could be a bad idea:

### Option B: …
### Option C: …

## Cross-cutting risks
<bullets>

## Initial recommendation
<one option, with 2-3 lines of justification>
```

## 5. Emerging questions

Looking at options often surfaces new questions that `/feat-start` didn't catch (e.g. "does this only apply to paid plans?", "what happens if the user already has N of this?"). If any have emerged, **ask the user before closing**. Note the answers at the end of `02-brainstorm.md` under "Decisions clarified in /feat-brainstorm".

## 6. Is the size still right?

After seeing the options, evaluate whether `meta.json.size` still fits the actual scope:

- If the brainstorm suggests the feature is much simpler/more complex than assumed, **propose reclassifying** to the user with the new estimate and one line of justification.
- If confirmed, update `meta.json.size` and note the change in `meta.json.notes` (e.g. `"size: M→S after brainstorm — chosen option requires no migration"`).
- If they keep the current size, continue.

## 7. Close

- Update `meta.json`: `phase = "brainstorm"`, add to `phases_done`, update `updated_at`.
- Show the user the options and ask them to choose (or request adjustments) **before** moving to `/feat-design`. If they choose one, note it in `meta.json.notes`.
