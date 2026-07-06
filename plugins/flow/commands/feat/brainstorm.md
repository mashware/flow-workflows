---
description: Generate options, angles, and risks for the feature before designing
---

# `/flow:feat:brainstorm`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Exploration phase. **No code is written.** Only opens the option space so that design does not start from the first idea.

## 1. Pre-flight

- Locate the active `meta.json`: search first by current branch (`git branch --show-current`), otherwise ask the user for the ticket.
- If `meta.json.phase` is not `context`, warn and ask whether to continue anyway.
- If `size` is `XS` or `S`, suggest jumping to `/flow:feat:design` or `/flow:feat:build` directly and stop (unless the user insists).
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before generating options, call `mcp__domain-memory__search_knowledge` with queries focused on the **concept/pattern** the feature covers, not the generic title (that was already queried in `/flow:feat:start`). Examples by area:

- If the feature touches tracking → `"tracking deduplication"`, `"hash collision"`.
- If it touches payments → `"trial expiration"`, `"plan downgrade flow"`.
- If it touches external integrations → `"attachment handler"`, `"tax rules integration"`.

Launch 2-3 queries in parallel. Timeout 2 s; if it fails, continue without context and do not notify the user. Record relevant hits in `02-brainstorm.md` under "Additional domain knowledge" (do not repeat what is already in `01-context.md`). If `domain_memory.enabled` is `false` or empty, skip without notifying.

## 3. Work

### 3.0 Multi-agent panel or single agent?

- If `meta.json.size` is **M or L**: offer the **parallel-approach panel** with `AskUserQuestion` ("Generate options with a parallel multi-agent panel? Higher token cost, less single-line-of-thought bias."). If accepted → §3.A. If declined → §3.B.
- If **S** (or the user declined): §3.B directly. The panel is not offered for XS/S — the cost does not justify it.

### 3.A Approach panel (parallel Workflow — LLM-council pattern)

Call the `Workflow` tool. This follows the **LLM-council** shape (Karpathy): independent advisors from different angles → a **cross-critique (peer-review)** round → a chairman synthesizes. The peer-review round is what keeps the chairman from ranking on presentation instead of substance: each advisor sees the full set and attacks the others' reasoning before anyone wins. Base script:

```js
export const meta = {
  name: 'brainstorm-panel',
  description: 'Parallel approach panel for a feature + peer-review + synthesis',
  phases: [{ title: 'Approaches' }, { title: 'Peer-review' }, { title: 'Synthesis' }],
}
const TICKET = args.ticket
const LENSES = [
  { k: 'minimum',    p: 'the SMALLEST approach that solves the declared use case, nothing more (strict MVP)' },
  { k: 'reuse',      p: 'the approach that MOST reuses existing pieces in the affected module or neighbors' },
  { k: 'operations', p: 'the most production-solid approach (observability, external integration failure, data at scale)' },
  { k: 'reframe',    p: 'challenge the premise: what if the problem is solved without building what is requested, or elsewhere?' },
]
const OPTION = {
  type: 'object',
  properties: {
    nombre: { type: 'string' }, queEs: { type: 'string' },
    modulos: { type: 'string' }, riesgo: { type: 'string' }, porQueMala: { type: 'string' },
  },
  required: ['nombre', 'queEs', 'modulos', 'riesgo', 'porQueMala'],
}
const CRITIQUE = {
  type: 'object',
  properties: {
    strongest: { type: 'string' },   // which approach best fits THIS project, from this lens, and why
    weakest:   { type: 'string' },   // which is worst and why
    perApproach: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          nombre:    { type: 'string' },
          fatalFlaw: { type: 'string' },   // the biggest hole this lens sees, or "none"
        },
        required: ['nombre', 'fatalFlaw'],
      },
    },
  },
  required: ['strongest', 'weakest', 'perApproach'],
}
// Round 1 — advisors, blind to each other → real diversity.
const approaches = (await parallel(LENSES.map(l => () =>
  agent(
    `Propose ONE approach to solve ticket ${TICKET} (see project conventions in FLOW.md), from this lens: ${l.p}. ` +
    `Read .claude/work/${TICKET}/01-context.md for context. Do not write code. Be specific about real project modules and layers.`,
    { label: `approach:${l.k}`, phase: 'Approaches', schema: OPTION, model: 'sonnet' }
  )))).filter(Boolean)
// Round 2 — peer-review. Each advisor now sees ALL approaches and attacks the others from its lens.
const critiques = (await parallel(LENSES.map(l => () =>
  agent(
    `You are the "${l.k}" advisor. Here are ${approaches.length} proposed approaches for ${TICKET}:\n` +
    `${JSON.stringify(approaches, null, 2)}\n` +
    `Read .claude/work/${TICKET}/01-context.md. From your lens (${l.p}), critique the OTHER approaches — not your own bias. ` +
    `For each approach name its single biggest flaw for THIS project (or "none"), and say which is strongest and which weakest. ` +
    `Be concrete and grounded in the project; do not invent flaws to fill space.`,
    { label: `peer-review:${l.k}`, phase: 'Peer-review', schema: CRITIQUE, model: 'sonnet' }
  )))).filter(Boolean)
// Round 3 — chairman. Synthesizes across proposals AND critiques, surfacing consensus and disagreement.
const synthesis = await agent(
  `You are the chairman. Approaches for ${TICKET}:\n${JSON.stringify(approaches, null, 2)}\n\n` +
  `Peer-review from the advisors:\n${JSON.stringify(critiques, null, 2)}\n\n` +
  `Read .claude/work/${TICKET}/01-context.md. Rank the approaches from best to worst for THIS case (project fit + simplicity, not generic), ` +
  `weighing the fatal flaws the peer-review surfaced. State explicitly where the advisors AGREED and where they DISAGREED, ` +
  `then give an initial recommendation with 2-3 lines of justification. Output markdown.`,
  { label: 'synthesis', phase: 'Synthesis', model: 'opus' })
return { approaches, critiques, synthesis }
```

Pass `args: { ticket: "<TICKET>" }`. With the result, fill §4 (each approach → one "Option", the chairman's consensus/disagreement + recommendation → "Initial recommendation"). Fold each approach's surfaced `fatalFlaw` into its "Why it could be a bad idea" line. If an approach came back `null` (agent down), it is already filtered out; if the whole peer-review round comes back empty, the chairman still synthesizes from the approaches alone.

### 3.B Single agent (default case)

Launch a `general-purpose` subagent with this brief (short, self-contained):

> Generate 3-5 distinct approaches to solve `<title>` following the project conventions (see `FLOW.md` and `.claude/work/<TICKET>/01-context.md`). For each approach: a one-sentence description of what it is, modules/layers affected, main risk, and why it could be a bad idea. Do not write code. Report in markdown, under 400 words.

If the feature touches a sensitive domain (payments, authentication, tracking), launch **in parallel** a second `general-purpose` subagent focused on "what can go wrong" for that domain.

## 4. Output

Create `.claude/work/<TICKET>/02-brainstorm.md`:

```markdown
# Brainstorm <TICKET>

## Additional domain knowledge
<hits from the focused search_knowledge, or "no findings">

## Options considered
### Option A: <name>
- What it is:
- Modules/layers affected:
- Main risk:
- Why it could be a bad idea:

### Option B: …
### Option C: …

## Cross-cutting risks
<bullets>

## Initial recommendation
<one option, with 2-3 lines of justification. If the panel ran (§3.A), prefix with a one-line
"Panel consensus / disagreement:" summarizing where the advisors' peer-review agreed and where it split.>
```

## 5. Emerging questions

Reviewing options often surfaces new questions that `/flow:feat:start` did not catch (e.g. "does this only apply to paid plans?", "what happens if the user already has N of these?"). If they appeared, **ask the user before closing** with `AskUserQuestion`. Record the answers at the end of `02-brainstorm.md` under "Decisions clarified in /flow:feat:brainstorm".

## 6. Is the size still correct?

After reviewing the options, assess whether `meta.json.size` still matches the real scope:

- If the brainstorm suggests the feature is much simpler or more complex than assumed, **propose reclassifying** to the user (`AskUserQuestion`) with the new estimate and a one-line justification.
- If confirmed, update `meta.json.size` and note the change in `meta.json.notes` (`"size: M→S after brainstorm — chosen option does not require migration"`).
- If the user keeps the size, continue.

## 7. Close

- Update `meta.json`: `phase = "brainstorm"`, add to `phases_done`, update `updated_at`.
- Show the user the options and ask them to choose (or request adjustments) **before** moving to `/flow:feat:design`. If they choose one, record it in `meta.json.notes`.
