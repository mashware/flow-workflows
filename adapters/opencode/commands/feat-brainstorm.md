---
description: Generate options, angles, and risks for the feature before designing
---

# `/feat-brainstorm`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Exploration phase. **No code is written.** The goal is to open the solution space so the design does not start from the first idea that comes to mind.

## 1. Pre-flight

- Locate the active `meta.json`: search first by the current branch (`git branch --show-current`), otherwise ask for the ticket.
- If `meta.json.phase` is not `context`, warn and ask whether to continue anyway.
- If `size` is `XS` or `S`, suggest jumping directly to `/feat-design` or `/feat-build` and exit (unless the user insists).
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled` is `true` in `FLOW.md`: before generating options, call `mcp__domain-memory__search_knowledge` with queries focused on the **concept/pattern** the feature covers, not the generic ticket title (that was already queried in `/feat-start`). Examples by area:

- If the feature touches tracking → `"tracking deduplication"`, `"hash collision"`.
- If it touches payments → `"trial expiration"`, `"plan downgrade flow"`.
- If it touches external integrations → `"attachment handler"`, `"tax rules integration"`.

Run 2-3 queries in parallel. Maximum wait time 2 s; if it fails, continue without context and do not notify the user. Record relevant results in `02-brainstorm.md` under "Additional domain knowledge" (do not repeat what is already in `01-context.md`). If `domain_memory.enabled` is `false` or empty, skip silently.

## 3. Work

### 3.0 Multi-agent panel or single subagent?

- If `meta.json.size` is **M or L**: offer the user the **parallel-perspectives panel** ("Generate options with a parallel subagent panel? Higher token cost, less single-line-of-thinking bias."). If they accept → §3.A. If they decline → §3.B.
- If it is **S** (or the user declined): §3.B directly. The panel is not offered for XS/S — the cost does not justify it.

### 3.A Perspectives panel (parallel subagents)

Launch several subagents via `@name` (per `agents.architecture` and equivalents in `FLOW.md`, or general-purpose subagents if those fields are empty) in `mode:subagent`, **in parallel without seeing each other** — real diversity. Each subagent generates **one** approach from a distinct lens:

- **Minimum**: the SMALLEST approach that solves the declared use case, nothing more (strict MVP).
- **Reuse**: the approach that MOST reuses existing pieces in the affected module or neighboring ones.
- **Operations**: the most production-solid approach (observability, external integration failure, data at scale).
- **Reframe**: challenges the premise — what if the problem can be solved without building what is requested, or somewhere else entirely?

For each lens, the subagent receives: the ticket title, the path to `01-context.md`, and the specific lens. No code is written. Report in markdown: what the approach is, modules/layers affected, main risk, why it could be a bad idea.

Once all approaches are received, run a **peer-review round** (the LLM-council step that keeps synthesis from ranking on presentation instead of substance): relaunch the same lens subagents in parallel, now each one **seeing all the approaches**, and ask it to critique the OTHERS from its lens — for each approach the single biggest flaw for THIS project (or "none"), plus which it thinks is strongest and weakest. Grounded in the project; no invented flaws.

Then **synthesize yourself** (the main agent): rank from best to worst for THIS case (fit in the project + simplicity, not generically), weighing the fatal flaws the peer-review surfaced; state explicitly where the advisors agreed and where they disagreed; and give an initial recommendation with 2-3 lines of justification. If a subagent did not respond, simply omit it.

### 3.B Single subagent (default case)

Launch a general-purpose subagent with this assignment (brief, self-contained):

> Generate 3-5 distinct approaches to solve `<title>` following project conventions (see `FLOW.md` and `.claude/work/<TICKET>/01-context.md`). For each approach: one sentence on what it is, modules/layers affected, main risk, and why it could be a bad idea. No code. Report in markdown under 400 words.

If the feature touches a sensitive domain (payments, authentication, tracking), launch **in parallel** a second general-purpose subagent focused on "what can go wrong" in that domain.

## 4. Output

Create `.claude/work/<TICKET>/02-brainstorm.md`:

```markdown
# Brainstorm <TICKET>

## Additional domain knowledge
<focused search_knowledge results, or "no findings">

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

Looking at options often surfaces new questions that `/feat-start` did not catch (e.g. "does this only apply to paid plans?", "what happens if the user already has N of these?"). If any have appeared, **ask the user before closing**. Record the answers at the end of `02-brainstorm.md` under "Decisions clarified in /feat-brainstorm".

## 6. Is the size still correct?

After seeing the options, evaluate whether `meta.json.size` still matches the real scope:

- If the brainstorm suggests the feature is much simpler or more complex than assumed, **propose reclassifying** with the new estimate and one line of justification.
- If confirmed, update `meta.json.size` and record the change in `meta.json.notes` (e.g. `"size: M→S after brainstorm — chosen option requires no migration"`).
- If the user keeps the size, continue.

## 7. Wrap-up

- Update `meta.json`: `phase = "brainstorm"`, add to `phases_done`, update `updated_at`.
- Show the user the options and ask them to choose (or request adjustments) **before** moving to `/feat-design`. If they choose one, record it in `meta.json.notes`.
