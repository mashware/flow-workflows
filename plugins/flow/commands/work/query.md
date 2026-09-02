---
description: Put a data-access query on trial — schema, indexes, execution plan and measured numbers decide it, never prose
argument-hint: "[file | pasted query | reviewer objection]  (empty: every query this work touched)"
---

# `/flow:work:query $ARGUMENTS`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context. **Models key for this command: `review`.**

**A query is approved by its plan, not by prose.** Fact sheet → challenger attacks → each point settled with a **plan or a number**. **Cross-cutting** (feat or bug), **repeatable**, does **not** advance `meta.json.phase`; runs with or without a work folder.

Invoked by `/flow:feat:review` and `/flow:bug:review` (duel over the diff), `/flow:work:respond` (a reviewer objected to a query), `/flow:feat:design` (access paths), `/flow:feat:build`, `/flow:feat:validate`. Invoke directly for any doubt outside them (chat question, comment on an open MR/PR, a year-old query).

**Autonomy.** Modes as in flow-core §2. The duel, challenger count and whether to measure are flow mechanics — never a question, in any mode. **Hard gates — stop and ask, in every mode:** (1) **creating, seeding or dropping any database, schema or table**, including a throwaway one (§4) — show exact commands and target, never a database the project uses; (2) **any DDL** on a real database (index, column, collation) — the flow's schema gate; (3) editing code (output is a verdict, not a patch); (4) posting anything to an MR/PR or ticket.

## 1. Resolve the subject

- **No argument** → every query **added or modified** by the current work: `git diff <git.default_base>...HEAD` plus working tree (what the review phases invoke).
- **A path** (`src/Foo/BarRepository.php`, optionally `:line`) → the queries in it, diff or not.
- **A pasted query** (SQL, DQL/HQL/JPQL, builder chain, ORM call) → that one, plus call sites if locatable.
- **An MR/PR thread or quoted objection** → the query under discussion **and** the objector's variant — a candidate like yours (§3, dogma rule).

**What counts as a query**, stack-agnostic: raw SQL, ORM query language, builder chain, repository finder, lazy relation traversed in a loop, aggregate/count, bulk write, migration or index change, any search-engine or key-value read behaving the same way. Diff only renames/reformats one → say so and stop.

## 2. The fact sheet (before anyone argues)

One per query, **facts, not opinions**; every unknown written down as unknown.

| Field | What goes in it |
|---|---|
| **Call site & frequency** | Where it runs, and **how many times per request/job** (once, once per row of a batch of N, inside a loop over an unbounded list) |
| **Target** | Entity/table(s), and which of them grow forever |
| **Filter** | Columns compared, and how (equality, range, prefix, function applied to the column, `IN` of how many values) |
| **Order** | Columns **and their direction** — this pair, not just the column names |
| **Bound** | Limit/offset, and whether the bound is **global or per key**; if the code cuts the result after the fact, say so — that bounds the payload, not the rows read |
| **Joins** | For each join, **both** sides: type, length, charset/collation, nullability — read from the real schema, not from the mapping |
| **Columns read** | And which are heavy (large text/blob/JSON/vector) |
| **Expected cardinality** | Rows per key, batch size, worst realistic key — with **where the number comes from** (`data.volumes`, a `COUNT`, a measurement). "Few rows" is not a number |
| **Indexes today** | The indexes that actually exist on those columns and their column order/direction, read with `data.schema_cmd` or from the schema definition — **never assumed from the mapping** |

`data.schema_cmd` empty and no schema definition readable → index and collation rows are **unknown**; the duel says so instead of guessing (checklist items 1 and 2 cannot be judged).

## 3. The duel

Three roles. **The judge is always the main agent** — never delegated.

**Challenger** — one subagent: `agents.performance` (or `agents.persistence`; both empty → `Agent general-purpose` with the role in the prompt). Gets fact sheet, schema and query code — **not** the design's rationale, ticket prose or your reasons (blinded as `/flow:feat:review §5.5`). **L** work or hot-path query → a **second** challenger with the checklist split (`agents.fanout_max`; empty → 4). Brief:

> You are attacking one data-access query. You receive its fact sheet, the real schema of the tables it touches, and the code — and deliberately **not** why it was written this way. Your job is to show how it degrades, not to approve it. Walk the checklist below and, **for every attack you make, name the concrete data scenario that triggers it** (which volume, which distribution, which key) and what the engine would then do. An attack without a scenario is noise; say "does not apply here" and move on. Do not propose a rewrite yet — first establish what breaks. Under 400 words.

**Checklist — the classic failures, in the order they bite.** The challenger walks all of it; the judge sees a line per item, including "does not apply".

1. **Is there an index that supports this access, as written?** Filter columns match a usable prefix **and** the `ORDER BY` is satisfiable by the same index, **including direction** — a mixed-direction order (`a ASC, b DESC`) over a single-direction index sorts the **whole** result set.
2. **Can the join keys use an index at all?** Different types, lengths, charset/collation, nullability, or a function/cast on the indexed side → the engine converts one side and **drops the index**, typically on the big table. **Invisible to tests** (same rows; only the plan changes). Read the schema of **both** columns, never the mapping; check even if the change did not introduce it (item 10).
3. **A per-key bound is not a global limit.** "Latest k per key" with a global `LIMIT n·k` returns nothing for the later keys — a silent partial answer. Put **every** candidate on the table: one query per key; a union of per-key subqueries; a window function; cutting in the process. Measure (§4); never rank from theory.
4. **Work the engine could do, done in the process** — filtering, ordering, grouping, deduplicating, counting or joining in application code; and its mirror: reading a whole set to keep a handful.
5. **Heavy columns in a pass that only decides.** Large text/blob/JSON/vector read for rows about to be discarded. Usual fix: two passes — a light one deciding which keys survive (still bounded: items 1 and 3), a keyed one fetching the weight.
6. **N+1, and its twin.** A query per row; and the batch grown past its usable size — an `IN` of thousands of values, a plan that flips on a long list, a parameter/packet limit. Same question: how many round trips, carrying how much.
7. **No bound at all.** No limit on a table that grows forever, a deep offset, an order over an unindexed column, an unbounded `COUNT(*)`, a "temporary" full read that outlives its data set.
8. **Queries inside loops, and writes one at a time.** A query, flush or commit per iteration; a transaction open across remote calls; and what **each failed iteration** sets off downstream (publishes, enqueues, disables, logs).
9. **A new index is not free.** Writes, space, possible redundancy with an existing prefix; on a large table it is DDL — the schema gate, and a pre-deploy step if `git.predeploy_gate` is true.
10. **Someone else's plan.** The same defect usually lives in neighbouring queries; a schema-level fix (collation, type, missing index) fixes all. **Say it and open a separate ticket** — not dragged into this diff, and the diff is not blessed because the problem predates it.
11. **Nothing pins this plan.** Performance resting on a trick (cast aligning a collation, a hint, a column order, a `STRAIGHT_JOIN`) turns nothing red when deleted. A trick ships with a comment on **why it is there and what removes it**, plus the root-cause ticket. Not worth that → say so; the trick-free alternative may be worth its cost.
12. **The cardinality is assumed, not counted.** Row counts from intuition are the first finding; `data.volumes` or a `COUNT` is the fix.

**Defender** — answer each attack with **evidence, not intent**: the plan, the index chosen, rows read, measured time. "Bounded because the batch is small" is not a defence; the number is. Use `agents.persistence` if set and the query is idiomatic to a stack it knows; otherwise the judge defends inline.

**Judge — the rules that decide the duel:**

- **No number, no win.** Attack without plan/measurement = defence without plan/measurement = unresolved → §4, or declared unresolved. Never split the difference in prose.
- **No dogma, in either direction.** "N small queries is an N+1" and "one batched query always wins" are both dogma; N indexed lookups of k rows routinely beat one scan of thousands. The simple shape stays a candidate until a number removes it.
- **The objector's variant is measured next to yours** — even when your theory says it is worse, especially then.
- **Measure before you argue.** Facts first (§2), plan second (§4), position third — a reasoned reply to a human's objection that has not looked at a plan is the failure this command prevents.
- **The verdict may be "the premise was wrong"** (objection about a bound, cost was a lost index). Lead with that, not with who was right.

## 4. Measure — when the schema alone cannot settle it

Read `data` from `FLOW.md`. **All optional, empty by default**; empty → the duel runs **dry** and the verdict says which points it could not settle — a legitimate result.

| Key | What it gives you |
|---|---|
| `explain_cmd` | Get the execution plan of a query (`{QUERY}` substituted) |
| `schema_cmd` | Show a table's real definition — types, charset/collation, indexes (`{TABLE}` substituted) |
| `sandbox_cmd` | Create a **throwaway** database to measure in |
| `seed_cmd` | Populate it with a representative data set |
| `volumes` | Free text: the real sizes of the hot tables (rows, growth, worst key) |

**Order of preference**: (a) plan on realistic volume — the only evidence settling items 1 and 2; (b) plan on the development database, noting its row counts may change the optimizer's choice; (c) schema alone — collation, types, index definitions and directions, not a plan; (d) nothing, declared.

**The functional test database proves nothing about a plan.** A handful of fixture rows makes the optimizer pick what is cheapest at that size. A plan measured there is not evidence — say "not measured".

When you measure: build the data set to the **shape** that matters, not just the size (one key with thousands of rows next to twenty thousand keys with one; the real batch size; heavy columns populated). Then a table, **three runs per variant**, plan next to time:

| Variant | Plan (access, index, rows read) | Time (3 runs) | Rows returned | Keys served |
|---|---|---|---|---|
| as written | … | … | … | … |
| challenger's proposal | … | … | … | … |
| reviewer's proposal | … | … | … | … |

`Keys served` catches a global limit pretending to be per-key: fastest but answering 40 of 50 keys is wrong, not faster.

Creating or seeding a database is a **hard gate** (§0): show commands and target name, never a database the project uses, offer the cleanup command with the result. If it stays up for follow-ups, say so and how to drop it.

## 5. The verdict — one recommendation, the number behind it, then the costs

Per query, exactly one of:

- **ok** — access supported and bounded; state the index used and rows read.
- **change** — **one** recommendation, not a menu, and the number that carries it. Alternatives in a line below, with why they lost.
- **schema / follow-up** — fix not in this diff (collation, type, missing index, neighbouring query). Propose the separate ticket; say what the diff does meanwhile.
- **unresolved** — not settleable without measuring, and measuring unavailable. Name the open question. A real verdict; a pretend "ok" is not.

**How it reads:** recommendation first, one sentence; then the number or plan carrying it; then **only** the costs that would change the decision (rest → artifact). "It depends" → name the condition and your default.

## 6. Where the output lands

- **Inside a phase** (work folder exists): queries table and verdicts go into that phase's artifact — `06-review.md` (review duel), `08-feedback.md` (`respond` round), `05-implementation.md` (query written during build), `07-validation.md` (measured criterion). A `change` enters the calling phase's normal flow: a review blocker like any other.
- **Standalone** (no work folder, or ad hoc): verdict in chat; an expensive measurement goes to `.claude/work/<work>/06-review.md` when a work exists, else offer to keep it as a note where the user wants.
- **Knowledge.** `knowledge.stage` is set and the duel produced a durable, non-obvious fact about this project's data (collation mismatch, real size of a hot table, index that cannot serve the obvious order, shape measurably faster here) → `knowledge.stage` it for this branch.

## Notes

- **This command judges, it does not patch.** The verdict goes back to the asking phase, which implements it with its own gates and reviewers. Standalone, it ends at the recommendation.
- **It applies past the relational case.** Search-engine query without a partition filter, key-value read in a loop, queue consumer fetching one row at a time, broker fan-out — same three questions: what does it read, how many times, what bounds it.
- **No new agent roles.** Reuses `agents.performance`, `agents.persistence`, `agents.fanout_max`. Only new configuration: the optional `data` section; empty, the command still runs and says what it could not prove.
