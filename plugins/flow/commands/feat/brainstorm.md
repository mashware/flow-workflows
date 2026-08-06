---
description: Generate options, angles, and risks for the feature before designing
---

# `/flow:feat:brainstorm`

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

- If `meta.json.size` is **M or L**: in **`manual`**, offer the **parallel-approach panel** with `AskUserQuestion` ("Generate options with a parallel multi-agent panel? Higher token cost, less single-line-of-thought bias."). If accepted → §3.A. If declined → §3.B. In **`guided`/`auto`, do not ask** — this is flow mechanics (cost and latency), not a decision about the product: take the panel for M/L, note it in one line of `02-brainstorm.md`, and go to §3.A.
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
- **Autonomy handoff.** Choosing between options is a genuine decision point, so in `manual` and `guided` ask for the choice and only then move on. In `auto`, pick the recommended option, **record the choice and why in `meta.json.notes`** and **chain into `/flow:feat:design` automatically** in this same turn — that is what `auto` was asked for. In `manual`, propose the next command with a single `AskUserQuestion` instead of leaving it written for the user to type.
