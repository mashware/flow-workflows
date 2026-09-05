---
description: Generate options, angles, and risks for the feature before designing
---

# `/flow:feat:brainstorm`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context. **Models key for this command: `study`.**

Exploration phase. **No code is written.** Opens the option space so design does not start from the first idea.

## 1. Pre-flight

- Locate the active `meta.json`: by current branch (`git branch --show-current`), otherwise ask the user for the ticket.
- Read `meta.json` and `00-summary.md`; open in full only `01-context.md`. (flow-core §5)
- `meta.json.phase` not `context` → warn and ask whether to continue anyway.
- `size` `XS` or `S` → suggest `/flow:feat:design` or `/flow:feat:build` directly and stop (unless the user insists).

## 2. Focused knowledge query

`knowledge.search` is set → before generating options, call `knowledge.search` with 2-3 parallel queries on the **concept/pattern** the feature covers, not the generic title (already queried in `/flow:feat:start`). Examples:

- tracking → `"tracking deduplication"`, `"hash collision"`.
- payments → `"trial expiration"`, `"plan downgrade flow"`.
- external integrations → `"attachment handler"`, `"tax rules integration"`.

Timeout 2 s; on failure continue silently. Record relevant hits in `02-brainstorm.md` under "Additional domain knowledge" (do not repeat `01-context.md`). `false` or empty → skip silently.

## 3. Work

### 3.0 Multi-agent panel or single agent?

- `meta.json.size` **M or L**: in **`manual`**, offer the **parallel-approach panel** with `AskUserQuestion` ("Generate options with a parallel multi-agent panel? Higher token cost, less single-line-of-thought bias."). Accepted → §3.A; declined → §3.B. In **`guided`/`auto`, do not ask** (flow mechanics): take the panel for M/L, note it in one line of `02-brainstorm.md`, go to §3.A.
- **S** (or the user declined) → §3.B. The panel is never offered for XS/S.

### 3.A Approach panel (parallel fan-out — LLM-council pattern)

**Launch the advisors as parallel subagents** — one per lens, single round, each blind to the others (LLM-council: independent advisors, then a chairman synthesizes; a **cross-critique (peer-review)** round in between for **L** only).

**How wide the fan-out goes** — `agents.fanout_max` from `FLOW.md` (empty → **4**): never launch more than that many subagents in one round. Rounds are **proportional**, like `review_depth`:

| Size | Rounds |
|---|---|
| M | Advisors → you synthesize |
| L | Advisors → cross-critique → you synthesize |

**You are the chairman.** Round 1 (and round 2 for L) are subagents; the synthesis and ranking are yours, never a subagent — you hold the work's context and write `02-brainstorm.md`.

**Round 1 — advisors (parallel, blind to each other).** One subagent per lens, up to `fanout_max`. M → the first three lenses; L → add `operations`, also when the feature touches a sensitive surface (authentication/authorization, payments, personal data, public contract, migration):

| Lens | Brief |
|---|---|
| `minimum` | The **smallest** approach that solves the declared use case, nothing more (strict MVP) |
| `reuse` | The approach that **most reuses** existing pieces in the affected module or its neighbours |
| `reframe` | **Challenge the premise**: what if the problem is solved without building what was asked, or somewhere else? |
| `operations` | The most production-solid approach (observability, external integration failure, data at scale) |

Each advisor gets this brief, with the lens substituted:

> Propose ONE approach to solve ticket `<TICKET>`, from this lens: `<lens brief>`. Read `.claude/work/<TICKET>/01-context.md` for context and `FLOW.md` for project conventions. Do not write code. Be specific about real modules and layers of this project. Report: name, what it is (one sentence), modules/layers affected, main risk, and why it could be a bad idea. Under 250 words.

**Round 2 — cross-critique (L only, parallel).** Each advisor gets the full set and attacks the *others* from its own lens:

> You are the "`<lens>`" advisor. These are the approaches proposed for `<TICKET>`: `<the round-1 set>`. Read `.claude/work/<TICKET>/01-context.md`. From your lens (`<lens brief>`), critique the OTHER approaches — not your own. For each one name its single biggest flaw for THIS project, or "none". Then say which is strongest and which weakest, and why. Be concrete and grounded in the project; do not invent flaws to fill space.

**Round 3 — you synthesize.** Rank the approaches best to worst *for this case* (project fit + simplicity, not generic), weighing the fatal flaws the critique surfaced. State explicitly where the advisors **agreed** and where they **disagreed** — the disagreement is the useful part.

`agents.fanout_tool` set in `FLOW.md` → run the rounds through that tool instead of plain parallel subagents; the rounds, the briefs and the `fanout_max` ceiling do not change (see `agents` in `FLOW.md` and `examples/FLOW.template.md`).

Fill §4: each approach → one "Option"; consensus/disagreement reading + recommendation → "Initial recommendation"; each approach's biggest surfaced flaw → its "Why it could be a bad idea" line. **A subagent that comes back empty is asked once for its answer and then dropped, never relaunched** (flow-core §6 — an empty result is as often a truncated report as an advisor with nothing to say) — synthesize from those that answered and note in `02-brainstorm.md` how many launched advisors reported (`N/M`). Empty critique round → rank from the approaches alone.

### 3.B Single agent (default case)

Launch a `general-purpose` subagent with this brief (short, self-contained):

> Generate 3-5 distinct approaches to solve `<title>` following the project conventions (see `FLOW.md` and `.claude/work/<TICKET>/01-context.md`). For each approach: a one-sentence description of what it is, modules/layers affected, main risk, and why it could be a bad idea. Do not write code. Report in markdown, under 400 words.

Sensitive domain (payments, authentication, tracking) → launch **in parallel** a second `general-purpose` subagent focused on "what can go wrong" for that domain.

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

New questions `/flow:feat:start` did not catch (e.g. "does this only apply to paid plans?", "what happens if the user already has N of these?") → **ask the user before closing** with `AskUserQuestion`. Record the answers at the end of `02-brainstorm.md` under "Decisions clarified in /flow:feat:brainstorm".

## 6. Is the size still correct?

Reassess `meta.json.size` against the real scope:

- Much simpler or more complex than assumed → **propose reclassifying** to the user (`AskUserQuestion`) with the new estimate and a one-line justification.
- Confirmed → update `meta.json.size` and note the change in `meta.json.notes` (`"size: M→S after brainstorm — chosen option does not require migration"`).
- User keeps the size → continue.

## 7. Close

- Update `meta.json`: `phase = "brainstorm"`, add to `phases_done`, update `updated_at`.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- Show the options and ask the user to choose (or request adjustments) **before** moving to `/flow:feat:design`. Record the chosen one in `meta.json.notes`.
- **Autonomy handoff.** Choosing between options is a genuine decision point: in `manual` and `guided` ask for the choice, then move on. In `auto`, pick the recommended option, **record the choice and why in `meta.json.notes`** and **chain into `/flow:feat:design` automatically** in this same turn. In `manual`, propose the next command with a single `AskUserQuestion`.
