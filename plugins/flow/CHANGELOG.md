# Changelog

All notable changes to the **flow** plugin, newest first. This file is bundled with the
plugin and is what `/flow:news` reads to show you what changed since your previous version.

The canonical, richest notes live in the [GitHub Releases](https://github.com/mashware/flow-workflows/releases).

## v0.34.0 — The plugin was handing out models it did not own  ·  2026-08-18

Two lines in this plugin picked models for you. A bullet in `/flow:work:README` split the work between "opus" and "sonnet" by judgment level, and `/flow:feat:review §3.5` launched its completeness critic with "(opus model — this is judgment, not tracking)". Both were wrong in the same three ways. **No command applied them** — not one `Agent` call in twenty commands ever passed a model, so the bullet described a policy that existed only in prose. **The names are not portable**: the same commands run on Codex, Gemini CLI and opencode, where `opus` means nothing, so a plugin that ships one vendor's tiers is lying to three of the four harnesses it claims to support. And **it is not the plugin's call**: which model is good at what changes every few months, differs per account and per budget, and belongs to whoever pays for the tokens.

**`models` in `FLOW.md`, five keys, by what a step does.** `study` (start, brainstorm, design, plan, diagnose, investigate, postmortem) · `code` (build, fix, green) · `test` (validate) · `review` (review, query, respond triage) · `workers` (the parallel fan-out rounds only, so breadth can be made cheap without touching the rest). Every key is empty by default and **empty means the step runs with the model you launched the command with** — a repo that ignores the section behaves exactly as it did before it existed. The values are free text passed straight to the harness: flow does not validate a model name, does not rank models, and never picks one.

**Two limits, stated instead of glossed over.** An agent **cannot switch its own model**, so for the steps the main agent performs itself — reading the ticket, designing, and writing the code (`build`/`fix` are single-thread on XS/S/M by design) — a configured value is *reported, not enforced*: when it differs from the running model, the phase handoff says so in one line with the command that fixes it, records it in the artifact, and **continues**. Making that a gate was the tempting version and the wrong one: a stop at every phase boundary demanding a `/model` is individually defensible and collectively turns an unattended run back into an attended one, which is the exact degradation the never-ask list in the phase preamble exists to prevent. And a **named agent keeps its own model** — when `agents.<role>` points at a real agent, that agent's own definition decides, because a setting must not be overridden from two places; the keys apply where flow *improvises* the agent and to the fan-out workers.

**Which model runs where is read, not inferred.** The keys are named by kind of step, and which step falls under which key lives inside the commands — so `/flow:config` now prints the resolved map: key, value, the commands it covers, a mark on the two whose steps the main agent performs itself, and who decided each one. `/flow:init` writes the section empty and does **not** ask about it unless you bring up models first.

Mirrored across the opencode, Gemini CLI and Codex adapters, where all three declare a subagent's model in the subagent's own definition rather than at the call site — each adapter's `PRIMITIVES.md` now says where, and says plainly that the conductor's own model is beyond reach there too.

## v0.33.0 — Ten lines about a class nobody had opened  ·  2026-08-18

v0.26.0 gave every stop a header: ticket, size, phase, `MR #n of N`, the plan state, one line of what just finished, one line of what is needed from you. That fixed the **order** of a report — you no longer had to read to the end to find out where you were. It did not fix the other two things that make a stop unreadable to the person it is written for.

**The ten-line limit turned out to be a ceiling, not a shape.** "At most ~10 lines of body" is satisfied perfectly by ten lines of paragraph, and ten lines of paragraph are still a wall of text — subordinate clauses, a "for context" opening, a recap of what the previous stop already said. Nothing in the contract asked for short lines, so nothing produced them. The body is now a headline of one or two lines and then two to five bullets, one idea each, and the limit is stated as a ceiling rather than a target.

**And nothing in it asked for the right altitude.** The only rule about wording was `Zero-context`, which says that when a class or method appears it carries four to six words of what it is. That rule assumes the identifier belongs there. Usually it does not. When the agent is the one writing the code, the human on the other side of the stop is doing product — deciding what the software should do, for whom, and what it must not break — not archaeology on a diff they have not read. Ten lines about `AttachmentUploader` are a report about the agent's afternoon; *"attachments over 25 MB no longer break the send — they upload separately and the mail carries a link"* is a report about their software. So the body now speaks in the language of what changed for whoever uses this thing, and a class, file or error code earns a line only when the user has to **decide** about it, asked something technical, or named it first. The mechanics are not lost — they go where they were always more useful, the phase artifact.

**What this is not.** It is not a licence to answer shallowly. The two rules govern the report the flow writes *unprompted*, at a stop; a technical question still gets a technical answer, at whatever length the subject needs.

Both rules sit in the shared **Reporting** preamble, so all 18 phase commands inherit them, and mirrored in the opencode, Gemini CLI and Codex adapters.

## v0.32.0 — The query passed every gate; nobody read its plan  ·  2026-08-18

A query shipped through `design`, `build` and a full `review` panel, and not one of those gates ever looked at an execution plan. A human reviewer did, in a comment: *"why is the limit in the code and not in the query?"*. The flow answered from theory — the bound is per key, a global `LIMIT` cannot express that, the ORM's query language has no window function — which was all true and all beside the point. When someone finally built a data set and ran `EXPLAIN`, the cost was somewhere else entirely: two tables joined on columns with **different character sets**, so the join could not use an index and the engine scanned 63,000 rows to return fifteen. 449 ms. The same defect was already sitting in a neighbouring query that had been in production for a year, and the shape that finally won was the one the flow had dismissed as obviously worse — one small indexed query per key.

Three separate failures, and none of them is a reviewer being careless.

**A query's cost is invisible to reading.** Correctness is in the code; cost is in the plan, and the plan depends on facts that appear nowhere in the diff — which index exists, in what column order and **direction**, the type and collation of both sides of a join, how many rows a key really has. A mixed-direction `ORDER BY` (`a ASC, b DESC`) over a single-direction index does not half-use it: it sorts the whole result set. Join keys with different collations lose the index entirely. Both are invisible to tests too — same rows, same assertions, green suite, collapsed plan. So no amount of reviewer attention finds them, and a plausible sentence in the design makes the reviewer stop looking sooner.

**New: `/flow:work:query`, the query duel.** A standalone, repeatable command that puts one query on trial. It states the facts first (call site and frequency, filter, order with direction, bound and whether it is per key or global, both sides of every join with their real types and collations, heavy columns, rows per key **and where that number came from**, and the indexes that actually exist — read from the schema, never the ORM mapping). Then a challenger **blinded to the design's rationale** attacks it over twelve classic failures, each attack required to name the data scenario that triggers it. Then the main agent judges, under three rules: **no number, no win** (an unresolved point is recorded unresolved, never split in prose), **no dogma in either direction** ("N small queries is an N+1" and "one batched query always wins" are both preferences until measured), and **the objector's variant gets measured next to yours** — especially when your theory says it will lose. Verdicts are `ok` / `change` / `schema-follow-up` / `unresolved`, and the last one is a real verdict, not a failure to produce one.

**Wired into the phases that let it through.** `feat:review` §3.6 and `bug:review` §3.5 run the duel whenever the diff adds or changes a query, at **any size, XS included** — it is not a depth tier but a category no other reviewer owns, and a one-line change to an `ORDER BY` is exactly the change whose cost is invisible. `feat:design` gains an **Access paths** table (filter, order with direction, bound, rows per key, and the index that supports it) so a missing index is a decision taken when adding one is still cheap. `feat:build` records the plan as the query is written. `feat:validate` measures against real volumes, because a green suite proves rows and never plans. `bug:investigate` treats slowness as a plan problem until proven otherwise — and notes that several of its causes leave the code untouched, where `git blame` cannot find them.

**`work:respond` gets a new thread category, `G`, and one rule.** A performance objection is answered with a plan, never with reasoning. A reasoned reply that has not looked at one is the most expensive answer the flow can produce: it sounds authoritative, so it costs the reviewer a round trip to disprove; it is grounded in the design's own rationale, so it feels verified when nothing was. The reviewer's variant is measured beside yours, a defect that predates the MR/PR is declared and ticketed rather than used to bless or widen the diff, and the reply leads with **one** recommendation and the number behind it — a reply that agrees and then hedges in three directions reads as "I don't know" and makes the reviewer decide twice.

**New optional `data` section in `FLOW.md`**: `explain_cmd`, `schema_cmd`, `sandbox_cmd`, `seed_cmd`, `volumes`. All empty by default — the duel still runs on the schema alone and **says** what it could not prove. `volumes` is the cheapest key of the five and worth filling even with the commands empty: an adversarial reviewer with no volumes invents them. Creating or seeding a database is a hard gate in every autonomy mode, never against production. And the corollary the flow now states out loud: the functional test database, with its handful of fixture rows, proves nothing about a plan — "not measured" is a legitimate verdict, a plan measured there reported as evidence is not.

Mirrored in the opencode, Gemini CLI and Codex adapters.

## v0.31.0 — 36 agents on a 69-line MR, in a dialect only one harness spoke  ·  2026-08-07

Three steps in the flow widen into several agents — the approach panel in `feat:brainstorm` §3.A, the hypothesis sweep in `bug:investigate` §3.A, the finding verification in `feat:review` §6 / `bug:review` §5. All three were written as calls to Claude Code's **`Workflow` tool**, with its JavaScript DSL embedded in the command files: `export const meta`, `parallel()`, per-agent schemas. Two problems, and the second is the expensive one.

**The plugin claimed to be harness-agnostic and was not.** `Workflow` exists in Claude Code and nowhere else. The three adapters each carried a row in `PRIMITIVES.md` translating it back into "launch N subagents in parallel" — which is what the flow wanted in the first place. The core now says that directly: rounds, briefs, and who synthesizes, in prose. The DSL scripts are gone from the plugin, and `Workflow` is no longer named anywhere in it except as an example of what `agents.fanout_tool` can point at.

**Nothing capped the width.** `review` §6 launched **3 skeptics per finding** with no upper bound, gated only on `size` M/L: 12 findings meant 36 agents, on a diff of any size — and a work *labelled* M ships a 70-line MR/PR often enough. Measured on one real feature, four phases of a single MR came to ~1M tokens across 16 agents. What changed:

- **`agents.fanout_max`** (new, empty → **4**) caps any single parallel round, and **what a cap drops gets said** — a sweep that investigated 4 of 7 hypotheses reports `4/7`, because a silently truncated fan-out reads as full coverage.
- **The verification gate is narrow now**: size M/L **and** a diff over **150 changed lines** (the real `git diff --stat`, not the recorded size) **and** ≥ 4 **ambiguous** findings — those resting on an assumption about code outside the diff, a runtime behaviour, or an unverified convention. A finding whose defect is visible in the diff is already confirmed and skips the pass. **One** skeptic, not three: this filter's failure mode is cheap, since a wrongly-discarded finding stays recorded in the artifact, whereas three voters multiplied the cost by every finding found.
- **The panel is proportional**, like `review_depth` already was: for **M**, advisors then synthesis; the cross-critique round runs for **L** only. Three lenses by default, `operations` added for L or a sensitive surface.
- **The synthesis is no longer a subagent.** Ranking approaches, converging on a root cause, judging findings — that returns to the main agent, which already holds the work's context and writes the artifact. Delegating it cost an agent and a context hop to get markdown copied back. Delegate the gathering, keep the deciding.

**Opting back into heavier orchestration is one line.** `agents.fanout_tool: Workflow` in `FLOW.md` runs the same rounds through Claude Code's tool, with its typed schemas and deterministic phases. Empty is the default and the portable path; a tool named there that the running harness does not expose falls back to plain subagents rather than failing.

`bug:investigate`'s **quarantine boundary** survives the rewrite and is now stated rather than left implicit in a schema: the hypothesis agents are the ones that touch raw logs and traces, they report findings instead of pasting log text, and the agent that decides the root cause never takes raw log content into its own context.

All three adapters were updated to match, including the ones that were already using plain subagents but still spawned a synthesizer agent.

## v0.30.3 — The hook the last release recommended checked nothing  ·  2026-08-07

v0.30.2 added `script/check.py` and told you to wire it in with `ln -s ../../script/check.py .git/hooks/pre-commit`. Doing exactly that produced `not a git checkout — nothing to check` and a green exit on every commit.

Reached through the symlink, `abspath(__file__)` resolves inside `.git/hooks`, so the script took `.git` for the repo root and ran `git ls-files` against a directory git does not track. Empty list, nothing to check, exit 0 — a hook that guards nothing while looking like it does, which is worse than no hook, because the previous release's own instructions installed it.

It now resolves the symlink and asks `git rev-parse --show-toplevel` where the tree actually starts, falling back to the script's own parent outside a checkout. Verified through all three entry points: as the installed hook, from another working directory, and with a defect reintroduced to confirm it still fails.

No changes to any command.

## v0.30.2 — A tree that would not load can now say so before the tag does  ·  2026-08-07

v0.30.1 restored a manifest that had been empty for two releases. This adds the check that would have caught it, plus the ones that would catch its neighbours.

There is no CI in this repo and a release is a tag on whatever is in the tree, so `script/check.py` is what stands between a broken tree and a permanent tag. It refuses: an **empty tracked file** (the actual failure — nothing else reads the manifest, so every other check passed while the plugin could not start), a manifest that does not parse or has no `name`/`version`, a **manifest version that disagrees with the newest `CHANGELOG.md` heading** (`/flow:news` reads one and the loader reads the other; when they drift the release notes describe a version nobody is running), a command without frontmatter, a `.toml` that does not parse, an embedded `json` example that does not parse, a `panel.json` example using a `mark`, `style` or inline URL **the reader would not understand**, and a plugin command **missing from any of the three adapters**.

The last two are worth their place because neither breaks anything loudly. An unknown `mark` is not an error in the panel — the line quietly loses its symbol and its column and renders as plain text — and adapter parity is maintained by hand, one file at a time, so the failure mode is a command that silently stops being mirrored rather than one that breaks.

Each check was verified by reintroducing the defect it targets and confirming it fails, which is how the first two versions of the embedded-json check turned out to be worthless: one skipped every block containing an ellipsis (which is all of the panel examples) and the next choked on blocks that quote a single field of a larger object.

No changes to any command — `/flow:*` behaviour is exactly v0.30.0's.

## v0.30.1 — The manifest was truncated to zero bytes  ·  2026-08-06

`plugins/flow/.claude-plugin/plugin.json` shipped **empty** in v0.29.1 and stayed empty through v0.30.0, so Claude Code could not load the plugin at all: no manifest, no commands.

The cause was a scripted version bump written as `open(p, "w").write(open(p).read().replace(...))`. Python opens the file for writing — truncating it — before it evaluates the argument that reads it, so the read returned the empty file it had just created. The v0.29.0 bump had done the same edit in two statements and was fine; the one-liner that replaced it was not. Nothing flagged it: the file is not read by any command, only by the loader, and v0.30.0's diff did not list it because by then it was already empty.

Restored from v0.29.0 and versioned 0.30.1. No content changes — `/flow:*` behaviour is exactly v0.30.0's.

## v0.30.0 — The line says what it *is*; the panel decides how to draw it  ·  2026-08-06

The reader gained a vocabulary, and writing against it turns out to be both simpler and more honest than the columns flow was hand-building in v0.29.1.

**`mark` replaces the state column.** Each line declares what it is — `done` · `current` · `pending` · `wait` (shipped or asked, now waiting on someone else) · `block` · `info` — and the panel picks the symbol and the colour. That kills the last place where flow was making a presentation decision it had no business making, and it fixes the v0.29.1 compromise honestly: an open MR/PR is `wait`, not "done" and not "in progress", which is exactly what it is in a train.

**`ref` need not be a number.** `#1` and `#3–#6`, but equally `Now`, `Next`, `Decision` — the panel aligns them into a column either way, so the labels below the train get the same treatment as the train. Widths are computed **per block**, and blocks are separated by blank lines, so the two groups no longer drag each other wide. Blank lines are now load-bearing.

**`link` is a field, not text.** The panel shortens the URL to `!9977 ↗`, makes it clickable and pins it right, or hangs it underneath when it does not fit. flow no longer writes a raw 60-character URL on its own indented line, which is what the v0.29.0 layout did.

**`stale_after_minutes`** raises the 30-minute staleness threshold for a stretch known to run long. `/flow:work:watch` sets it to about twice its cycle interval: the default would let a dead monitoring loop pass for a live one through five missed cycles, and a watcher that has stopped watching is precisely what has to be visible.

**One correction to v0.29.1.** The "keep every line under ~55 characters" rule was written from a misread screenshot: the reader *does* align a wrapped line's continuation under its text. Length is now a matter of saying less, not of measuring columns — the rule is gone.

## v0.29.1 — The header said `build` while the body said "validating"  ·  2026-08-06

First run of the panel against a real work, three fixes it earned in the first ten minutes.

**The header was a phase behind.** `meta.json.phase` only advances when a phase *closes*, so a reader drawing the phase from it shows `build` for as long as `validate` takes — with the panel body, one line below, saying "validating". `panel.json` now carries its own **`phase`**: the phase being executed right now. The reader prefers it when present and falls back to `meta.json` when absent, so it costs older works nothing.

**"Done  #1 …  MR open" contradicted itself.** Grouping the train under `Done` / `Now` / `Left` is the obvious layout and it is wrong for the way flow actually ships: in a train an MR/PR that has shipped is *open, waiting to merge*, not done, and in a four-MR train almost nothing is merged until the end. A heading that calls it done states something false in the one place the user is trusting at a glance. The headings are gone; each entry carries its real state as its last column, and the not-yet-started ones collapse into a single `#a–#z` line — which also buys back the height the URLs need.

**Lines were written long enough to wrap.** The reader wraps rather than truncates, so an overflowing line takes two ragged lines and its continuation does not inherit `indent` — the column breaks and a trailing `#2` ends up alone. The rule is now explicit: each line short enough not to wrap (~55 characters), and say less rather than say it in two lines.

Also: the panel is written **in the language the work's artifacts use**, which was left implicit and produced one panel in English over a Spanish work.

## v0.29.0 — Every stop is a file too, so something other than the chat can answer "where is this?"  ·  2026-08-06

### The chat is a stream; the question is a state
Three works in flight, each in its own pane, and the question you actually have about any of them is always the same: which MR/PR is this on, how many are left, is it waiting for me, and what is the link. All of it is already known — `meta.json` has the train, the states and the URLs — and none of it is *readable* without scrolling back through a session or typing the question at the agent. So the agent gets asked for the link to an MR/PR it opened forty minutes ago, which is the clearest sign that the state was never anywhere you could look.

flow already had the shape of the answer. The **Reporting** preamble fixes what a stop looks like — ticket, size, phase, `MR #n of N`, the plan state, one line of what just finished, one line of what is needed from you. That header is written into the chat and then scrolls away.

### `panel.json`
Every phase command now writes that same state to `.claude/work/<work>/panel.json`, a small file any external reader can poll — a terminal pane, a status bar, a dashboard. It carries the MR/PR train read from `meta.json.mrs` with the **URLs of the ones still open**, one line of prose on what is running right now, what comes next, an `accent` line when the flow is parked on a decision of yours, and `warn` lines for blockers: a sibling repo whose `contract_handoff` is still `pending`, a red pipeline, a dependency that has not merged.

Lines carry **semantic** styles — `normal` `dim` `title` `accent` `ok` `warn` `error` — never colours, so the reader owns the palette and stays right when the theme changes. `header: true` (the default) lets the reader draw ticket, type, phase and age itself from `meta.json`, which is why those four never appear in the lines.

**Two properties make it trustworthy rather than decorative.** It is overwritten **whole**, never patched, so it can never be half of an old state and half of a new one. And it is written **before** a long stretch — a subagent fan-out, a full test suite, a CI poll — rather than after it, with an honest `updated_at` taken from the real clock: a file written only when a step succeeds keeps showing as finished a step that in fact died halfway, and that is the failure mode a panel makes *worse* than no panel. Written beforehand, a stale timestamp is something the reader can flag instead.

### Where it is written
In pre-flight, before every stop, before any long unattended stretch, and at each `## Close` — the four points where the Reporting preamble already governs what the user is told. Plus the places that hold something the generic rule cannot know: `/flow:feat:ship` and `/flow:bug:ship` write the MR/PR URL into `meta.json` **and** the panel the instant it exists, before the pre-deploy thread and before anything else can fail; `/flow:feat:plan` gives the panel its train when the split is first recorded; `/flow:work:resume` rebuilds it after a break, which is when it is most likely to be lying; `/flow:work:watch` refreshes it every monitoring cycle, since an unattended watcher is otherwise invisible; and `/flow:work:abandon` leaves a terminal state before archiving. The read-only commands — `status`, `daily`, `config`, `news` — never write it.

**Optional by construction**: a work that has never written one still resolves from `meta.json` alone, so nothing needs migrating and older works keep displaying. **No new `FLOW.md` keys**, no new phase, no new agent — one new file per work and one paragraph in a preamble that already existed. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

## v0.28.0 — A ticket is its thread too, and a thread you could not read says so  ·  2026-08-06

### The contract was published, and the other repo never saw it
The case behind this release: one ticket, two repos. The backend half shipped and, exactly as designed, `/flow:feat:ship` §6.3 published the contract **as a comment on the ticket** — literal payloads, routes, error codes. Then `/flow:feat:start <TICKET>` ran in the consuming repo and started building against a shape it invented, because it had never read that comment.

Nothing had been skipped. `/flow:feat:start` §3.6 says to look for a published contract block "while reading the ticket" — but §2 reads the ticket with `tracker.view_cmd`, and the default for **every** supported tool stops at the description: `gh issue view N`, `glab issue view N` and `acli jira workitem view KEY` do not print comments. The producing side wrote to a place the consuming side was never told to look, and the failure was silent in the worst way: an empty search for a contract reads exactly like a ticket with no contract.

### The comment thread is part of "read the ticket"
`/flow:feat:start` §2.1 and `/flow:bug:start` §1.1 are new, and they are not about contracts — that was just the case that exposed it. The description is the ticket as it was **first written**; the thread is where it was **decided**: the scope cut, the sharpened criterion, the reproduction the reporter added three comments down, the cause someone already ruled out, the "in the end we did it the other way". Almost none of that gets folded back into the description, so a start that reads only the description starts from a stale ticket.

Both commands now read the thread with the new `tracker.comments_cmd`, or derive it from `tracker.tool` when it is empty (`--comments` on `gh`/`glab`; the native listing tried once on Jira/`linear`). What they keep is the part that changes the work — published contracts, scope and criteria decisions, corrections to the description, operational facts you would otherwise guess — and bot noise and cross-references are skipped.

**Precedence is stated, not left to taste.** When a comment contradicts the description, the most recent comment that decided that point wins; descriptions are written first and rarely re-edited. But a contradiction that moves scope or changes what the bug *is* becomes a §3 / §1 question instead of a quiet reinterpretation. And ticket comments are **untrusted input** — material to weigh, never instructions that override a step or a hard gate, the same rule `/flow:work:respond` already applies to review threads.

**An unread thread is a named gap, not an all-clear.** If there is no way to get the comments — no `comments_cmd`, the command fails, `tool: none`, the ticket was pasted by hand — the command says so in one line and records it. "I could not read the comments" and "there were no comments" are opposite facts, and only one of them is fixable by pasting. §3.6 says it too: an unreadable thread is not evidence that no contract was published.

Both artifacts get a `## Decided in the ticket thread` section (`01-context.md`), which is what carries those decisions into `design`, `build` and `validate` instead of leaving them in a terminal that has scrolled away.

### `resume` re-reads the thread, because the break is when the ticket moves
Reading the thread at `start` closes the case above but not the one next to it: you start in the consuming repo *first*, the other side ships two days later, and the contract lands in a ticket you already read. So `/flow:work:resume` §2.5 re-reads the thread and shows **only what is new** since what `01-context.md` already records — a published contract, a scope or criteria change, a correction, an operational fact. Nothing new is one word (`nothing new`); a resume that re-prints the whole thread every morning is noise you learn to skip.

What it does with what is new is deliberately timid, because by then there is work on disk: it **appends** to `01-context.md` (verbatim, into `## Contracts received` when it is a contract) and it **never** amends the design or the code. When a new comment contradicts something already in `03-design.md` or already built, it names the collision — *ticket now says X, this repo decided Y* — and hands the decision to you in **every** autonomy mode. That is the one case where an `auto` run quietly "fixing" it produces two contracts for one ticket. `§4`'s rule holds: it can suggest rerunning `design`, it does not rerun anything.

**One new `FLOW.md` key**: `tracker.comments_cmd` (optional; empty = derived from `tool`). `/flow:init` now fills it alongside `view_cmd`. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

## v0.27.1 — The first real sweep found three ways to be wrong about a branch  ·  2026-08-05

Running `/flow:work:clean --dry-run` against the two repos from v0.27.0 — 49 and ~120 branches — turned up three defects, all of them the kind that only shows up against a repo with history.

**`@{u}` was the wrong ruler for "not on the remote".** The protected set measured unpushed commits against the configured upstream. But flow creates branches with `git worktree add --no-track`, so a branch that was pushed, reviewed and merged still has **no upstream configured** — and every one of them read as "exists only here" and got protected. In the larger repo that was most of the table: branches whose `origin/<branch>` ref was sitting right there. It now measures against `refs/remotes/origin/<branch>` and only falls back to counting the branch's own commits when there is no remote ref at all.

**A closed MR/PR is not the absence of one.** An MR/PR closed without merging is neither `merged` nor in flight, and the previous version folded it into `unknown` alongside branches that never had an MR/PR. Same non-action, opposite meaning: one says a decision was made about this work, the other says nobody ever looked. `closed` is now its own verdict — never a candidate, always named in the report.

**The 100-MR/PR page is not the whole forge.** In a high-turnover repo most finished branches are older than the list window, and the local patch-equivalence check in §4c misses a squash whose MR/PR absorbed review changes — the patch that landed is no longer the patch on the branch. So when **25 or fewer** branches are still `unknown`, the sweep now asks the forge about each one directly (`--source-branch` / `--head`). That is the one place per-branch queries earn their cost: the list already answered for everything it covers, and what is left is bounded and named. Above 25 it skips the pass and reports how many went unresolved.

## v0.27.0 — The flow sweeps up after itself, and "merged" is a verdict rather than a guess  ·  2026-08-05

### Two repos, 36 worktrees, and 13 of 14 already merged
The case behind this release: after a few weeks of steady use, two repos of the same project were carrying **22 and 14 git worktrees**. In the smaller one, exactly **one** of the fourteen was still live — the other thirteen were full checkouts of branches whose MR had already merged. The same repo had **16 work folders in `.claude/work/` and zero in `_archive/`**. Nobody had done anything wrong; the plugin simply had no moment at which any of it got cleaned up.

It looked like it did. `/flow:feat:ship` and `/flow:bug:ship` offer to archive the work folder and remove the worktree, `/flow:work:abandon` does the same, and `/flow:work:status` §4 flags folders whose branch is gone. But every one of those is a **prompt at the end of a long command**, easy to answer past — and in a train it never fires at all, because an intermediate MR/PR does not set `phase = "done"` and the branch is the base of the next one. The plugin's whole cleanup story depended on reaching the last question of the one command that asks it, in the one mode where it asks.

### `/flow:work:clean` — the sweep, and what it refuses to do
The new command takes all three inventories at once — worktrees, local branches, `.claude/work/` folders — joins them on the branch name, and decides each row's fate from evidence rather than from age.

**The evidence is the forge, and it is asked exactly twice.** One call for merged MRs/PRs, one for open, joined locally against the inventory. Twenty worktrees is still two calls, not twenty. A branch in neither list falls through to local checks; absence from a paginated list is not a verdict, and when the sweep cannot cover everything it says so instead of reading as "checked everything".

**`git branch --merged` is the wrong tool and this is where it shows.** A squash-merged branch is an ancestor of nothing: its commits were replaced by one new commit with a different sha, so ancestry-based checks miss every single one. In the repo above, 8 of the 13 finished branches were invisible that way. So when the forge cannot answer, `clean` replays the branch's tree onto its merge-base with `git commit-tree` and asks `git cherry` whether that patch is already upstream — the standard patch-equivalence trick, which catches squashes without needing the forge at all.

**And the refusals, which are most of the design.** `unknown` is never a candidate — silence is not a merge. A worktree with uncommitted changes is protected even when its MR merged (that case gets its own line in the report: the MR went in, the edits never left the checkout). A branch with commits not on the remote is protected. There is no `--force`, ever, and `git branch -D` only runs on a verdict that came from the forge, never on one inferred locally. Work folders are **archived, never deleted**. The remote is never touched — deleting merged remote branches is the forge's job, not a cleanup sweep's. And **`autonomy.mode` does not authorize deletion**: `auto` governs flow mechanics, not the one action in the plugin that can destroy work existing nowhere else, so it confirms the list like every other mode. `--dry-run` shows the whole table and touches nothing.

One row type is deliberately awkward: a work whose `mrs[]` are all merged but whose `phase` never reached `done` — the train whose last `ship` never ran. It is confirmed **individually**, never folded into a bulk yes, and on confirmation `phase` is set before the folder moves, so the archived record does not sit there claiming it is mid-build.

`.claude/work/_archive/` is outside the sweep — that history is often the only record of why something was abandoned. `--purge-archive <N>d` is a separate opt-in pass that only removes folders **already committed to git** (`git log -- <path>` brings them back); untracked ones are the only copy there is, so they are listed with that said out loud rather than deleted.

**`/flow:work:status` §4 and `/flow:work:daily` §4 now surface the residue as a count** and point here — a cheap local check, no extra forge calls, one line at the end and only when there is more than a handful. Neither deletes anything; counting and deciding stay separate. `/flow:feat:ship` says the same thing once per work when shipping an intermediate train MR/PR, at exactly the point where the prompt it *would* have shown does not exist.

**No new `FLOW.md` keys.** Mirrored across the opencode / Codex CLI / Gemini CLI adapters, with the confirmation adapted to a plain numbered choice. Two fixes came along for the ride: the adapter command indexes had been missing `/flow:work:green` since v0.24.0, and `install.sh` now counts the commands it copies instead of printing a hardcoded number that had drifted.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.26.0...v0.27.0

## v0.26.0 — Every stop says where you are, and `auto` stops asking about itself  ·  2026-08-03

### 16 questions in four hours, in the mode whose promise is "without pausing"
The case behind this release: a 7-MR/PR feature run end to end with `autonomy.mode: auto`, in one of four panes each holding a different work. Two complaints came out of it, and they turned out to be the same crack seen from both sides — **the agent's context and the user's are not the same context**, and nothing in the plugin said so.

**`auto` was degrading into `manual` one reasonable-looking question at a time.** Not at the phase boundaries — v0.25.0 fixed those — but inside the phases. Four of the sixteen questions were the flow asking about **its own machinery**: whether to launch the brainstorm panel, whether to launch the challengers, whether to commit the WIP, whether to start the next MR/PR of a train. Each individually defensible, and together an attended run the user had configured to be unattended. The causes were three, all in the files:

- **A mode-less "ask" beats a mode-aware handoff.** Exactly the v0.25.0 lesson, still live one level down: `plan` §6 said *"show the summary table and ask for approval"* and then, three lines below, *"in `auto`, record the plan as accepted and chain into `build`"*. `design` §9 did the same with the design review. A specific instruction with no condition on it wins over a conditioned one, so `auto` asked. Both are now conditioned on the mode where they sit.
- **Flow mechanics is not the user's decision.** The panel offers in `brainstorm` §3.0, `feat:review` §6, `bug:investigate` §3.0 and `bug:review` §5, and the size confirmation in `start` §4, were written as unconditional prompts. They are calls on **cost and latency**, which is the agent's judgement, and each step already carries the recommended default. In `manual` they are still offered; in `guided`/`auto` they are taken, noted in one line of the artifact, and left behind.
- **Hard gates had no symmetric half.** Every phase command listed what **always** stops (push/MR-PR, ambiguous base, migrations, high-severity findings) and nothing listed what **never** does. The preamble now carries both. Never asked in `guided`/`auto`: flow mechanics, WIP commits, continuing a train when `train_chain` resolves to `always` — and in particular never offering to *wait for the merge*, which only `train_chain: wait` asks for — size confirmation, and **anything already decided and recorded**. That last one was the expensive one in the run: a decision settled at 14:07 was reopened at 14:29. Reopening a settled decision is not prudence; it makes the user decide twice and costs the flow their trust that a decision stays decided. Only new evidence contradicting the premise reopens it, and then the evidence leads, not the question.

**And when it did stop, the user could not tell where they were.** Seventeen stops, averaging ~1,500 characters and peaking at 2,580, and not one of them opened with the state: no ticket line, no phase, no "MR #2 of 7", no "one shipped, five waiting on it". The plan state appeared in 2 of 17, unprompted and late. Meanwhile four full stops were spent explaining that some subagents *had become free*. The reason is plain in hindsight: **no command said a single word about how to report.** They all specified what to do and what to write to the artifact; the audience of the stop itself was never specified, so each report opened on whatever detail was freshest in the agent's head — a rehydration method, a voter attribute map, a `§4.2` — for a reader who had read none of it.

The phase commands now share a **Reporting** preamble that fixes the shape of a stop before any prose: `<TICKET> · <size> · phase · MR #n of N`, the plan state read from `meta.json.mrs`, one line of what just finished, one line of what is needed — then **at most ~10 lines of body**, and only what could change a decision. Three rules come with it. **Narrating your own process** — mistakes made, subagent reports corrected, how `meta.json` was located — goes to the artifact, where it is useful later, and not into the stop. **Subagent idle/completion notices never earn a turn of their own**; they are absorbed into the next real stop. And the **zero-context rule**: write for someone who just sat down, so the first mention of a class, method or error code carries four to six words of what it is, and a section number is never cited without naming it.

Two places got the state treatment specifically, because they are where "how many are left" is actually lost: `plan` §6 now prints the execution as `Wave 1: #1 ∥ #2 → Wave 2: #3 → Wave 3: #4 ∥ #5` **before** the table (`∥` parallel, `→` waits for the merge) instead of leaving the user to decode two columns, and `work:resume` §2 gained the `MR/PRs:` and `Waves:` lines it never had — after a break, which one am I on and how many remain is the first thing gone.

**What deliberately still stops in `auto`**: the two per MR/PR from v0.25.0 — the **business brief** and all of **`ship`**. The brief now carries the full stop header, because in a 7-MR/PR work a brief with no "#3 of 7, two shipped" above it is unreadable, and those two stops are the only points where the user sees the work at all.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters, with the questions adapted to plain numbered choices (no `AskUserQuestion` menu there). **No new `FLOW.md` keys** — the stop contract is not configurable, and the never-ask list is `autonomy.mode` finally being symmetric.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.25.0...v0.26.0

## v0.25.0 — `auto` chains, and choosing `auto` is the commit authorization  ·  2026-07-30

### An unattended mode that stopped at every phase boundary was never unattended
The report: with `autonomy.mode: auto`, a build ended with *"nothing committed — the 5 files are in the working tree for you to validate first. When you want: commit and `/flow:feat:review`"*. Two stops in one sentence, in the mode whose whole promise is *"chaining phases without pausing"*. Nothing in the plugin had changed — both instructions were months old. What changed is which one wins when a prompt contradicts itself, and the flow contradicted itself in two places.

**A named next command is not a handoff.** The autonomy preamble, repeated at the top of all twelve phase commands, promised that `guided`/`auto` "chain into the recommended next command automatically". But only `feat:start` and `bug:start` said so in their closing section; the other ten closed with *"and next command: `/flow:feat:review`"* and nothing else. A closing line that merely **names** the next command is a specific instruction to stop, and a specific instruction beats a general preamble. So `auto` stalled at every phase boundary while claiming to chain. Every `## Close` now ends with an explicit **autonomy handoff**: `manual` stops and proposes the next command as a one-click confirmation (never leaving you to type it); `guided`/`auto` chain into it **in the same turn**. The exceptions are stated where they apply rather than left to inference — `validate`, `bug:review` (XS/S) and `bug:postmortem` never chain into `ship`, because pushing and opening the MR/PR is a hard gate in every mode, and nothing chains downstream of a red gate (blockers in review, red tests or unproven criteria in validate, unresolved `high` findings in design).

**Choosing `auto` *is* the commit authorization.** `build` §2.2 and `fix` §2.1 carried a *hard rule* with no exception per mode: the agent never commits on its own and **waits** for you at every step. Against `auto` that is not a preference, it is a contradiction — and it is the one the system rule (*never commit unless the user explicitly asks*) reinforces, so it won every time. The rule is now gated by the mode, with the authorization made explicit instead of assumed: `manual` — you decide per step, nothing is committed without your word; `guided` — asked **once** at the first step, then applied for the rest; `auto` — the agent commits each step's WIP and keeps going, because **setting `autonomy.mode: auto` and typing the command is the explicit ask**. Same reasoning that already made the commits in `ship` authorized (it is the command's stated purpose) and the `Workflow` fan-out opt-in valid (typing the command is the authorization). It covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode. `work:green` and `work:respond` follow suit: in `guided`/`auto` they commit the round and go straight to the push gate, instead of asking twice for the same round.

**What deliberately still stops in `auto`.** The **business brief** before any code is written (`build` §2, `fix` §2) — it is the last point where the scope can be corrected before there is a diff to argue with, and scope creep is invisible in code review once mixed into everything else. And all of `ship`. An `auto` run now goes from `start` to a validated branch without intervention, and ends where it always should have: asking whether to publish.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. No new `FLOW.md` keys — this is `autonomy.mode` finally doing what it already documented.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.24.0...v0.25.0

## v0.24.0 — The contract crosses to the other repo, and green means a count  ·  2026-07-29

### One epic, two repos, and four incidents that turned out to be two holes
The case behind this release: an epic delivered across a backend and its MCP consumer, six MRs on an integration branch. Four things went wrong, and grouping them cut the list in half.

**The literal contracts never reached the other repo.** `related_repos` was already well wired — captured at `start`, refined at `design`, reminded at `ship`, surfaced by `daily`/`resume`/`status`. But it carried `{repo, scope, status}`: *that* a sibling has pending work, never *against what shape*. Meanwhile the contracts themselves live in `03-design.md`, inside **git-ignored** `.claude/work/`. So the most expensive artifact of the whole flow died with the session while the cheapest — `scope`, one line of prose — was the only half that crossed. The consuming repo then started from a ticket saying "expose an endpoint", and invented the routes, payload keys and error codes that had already been decided. `design` even had a **`Known consumer`** field for exactly this, and nothing read it.

Now the handoff is symmetric, because publishing without a reader fixes nothing. `/flow:feat:ship` §6.3 offers to publish the **literal** contracts — only the ones whose `Known consumer` names that sibling — to the anchor both sides already share: the tracker ticket (fallback to a versioned file when there is no tracker). Mandatory preview in **every** autonomy mode, like the MR/PR preview: it publishes prose the whole team reads. Acceptance criteria and ADRs deliberately do **not** cross — they are this repo's *how*, and in the sibling's ticket they bury what matters. On the receiving end, `/flow:feat:start` **§3.6** picks that block up into `01-context.md` as **received, not negotiable**, and `design` carries it in verbatim instead of re-deriving it. When a ticket points at another repo with *no* published contract, `start` now says so out loud — an absent contract is otherwise invisible, and what fills the silence is invention that reads like knowledge. New `contract_handoff` per entry in `meta.json.related_repos` (`none` / `pending` / `published → <location>`), so "never handed over" is something `status`/`daily`/`resume` show you rather than something you remember. `bug:ship` gets the same handoff for a fix that *changes* a consumed surface — worse than a new contract, since the sibling has working code and no reason to suspect the shape moved.

**The other three incidents were one failure wearing three hats: accepting a plausible signal as a verified one.** A test that never ran because the filter did not match. A `catch` copied from a neighbouring file without checking it applied. And two domain findings reported that turned out false once checked against `origin/master` and against the generated DQL. Three places where flow took the cheap signal:

- **Green is a count, not an exit code.** `build` §4 said "run them individually with `quality.test_one`" and trusted the exit status — but nearly every runner exits `0` when a filter matches nothing (`OK, 0 tests`, `No tests ran`). A typo, a renamed class or a test outside the filtered suite was indistinguishable from a pass, and *more* convincing than silence, because a command ran and succeeded. The run is now judged by the executed **count and names**: zero, or your new tests absent, is a failure. No count reported → drop the filter and run the whole file.
- **Borrowed code carries its reason.** §2.0bis protected against pattern drift for *contracts* only, so a lifted `catch` fell outside the perimeter. `build` §2.1 now asks, for any structure taken from another file, what makes it apply *here* — the exception is actually thrown on this path, the guard's precondition can actually be false. If you cannot name it, do not copy it. Borrowed-and-plausible reads as deliberate, so a reviewer spends real attention before finding it was never chosen.
- **Evidence before staging.** `design` §8 called `stage_finding` with no evidence requirement at all — odd, since §7 already made the *challenger* verify its findings. A finding is now staged with one line of evidence, and two rules on what counts: claims about the code are checked against `git.default_base`, **never a train/integration branch** (diffing against the parent shows your siblings' work as if it were the baseline), and claims about generated output are checked against the output **actually produced**, not predicted from reading the builder. No evidence line → the finding is withdrawn, not stored. An unverified finding is worse than none, because it gets believed.

Deliberately untouched: the `review` panel, which **caught** the two mistakes that got through. The lesson was to make detection cheaper upstream, not to thicken the net that already worked.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. **No new FLOW.md keys**, no new phase, no extra agent — one new `meta.json` field and one new numbered section.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.23.0...v0.24.0

## v0.23.0 — The review panel runs whole, and a settled decision never fences off the reviewer  ·  2026-07-29

### A full flow, a green suite, and a human reviewer still found four things
The case that motivated this release: the whole flow ran on a read-time endpoint that called an external API **inside a loop** over up to 100 items, with a per-item `catch` that returned `null`. Suite green, static analysis clean, MR opened. A human reviewer then found four problems — three of them hanging off that same loop. Every failed iteration published a message to a queue *and* emitted an event that enqueued one job per item downstream; 100 sequential external calls in a synchronous request had no cap; and the generic `catch` swallowed all of it. Three fixes, none of which invents a new phase.

**Performance stopped meaning "database".** The reinforcement trigger in `review` §3 was literally *"DB / heavy queries"*, and `validate` §2's brief was a closed list of persistence patterns (N+1, indexes, unbounded queries, flush in a loop). A change that touches no database fell outside that vocabulary entirely. Both now cover **any repeated call that leaves the process** — external API, HTTP, cache, filesystem — and, more importantly, ask what **each failed iteration sets off downstream**: what it publishes, enqueues, disables or logs, and whether N failures multiply it. The cost of the happy path was never the whole question. Same widening in `design`'s performance pass, `bug:review` §3, and the `performance` role in `FLOW.template.md`.

**A decision already taken is context for the reviewer, never a scope exclusion.** §2.2 already warned against inheriting `03-design.md`'s rationalizations — but only for the artifact handed to reviewers. Nothing stopped the *conductor* from turning a design decision into a veto inside the agent's own prompt ("this cost is accepted, don't report it, look for something else"), which is the same pathology through the other door — and it silently excludes everything hanging off the vetoed topic. §2.2 now covers the briefs you write: *"X is decided — tell me what consequences it has that we have not seen"*, never *"do not report X"*. The rule reaches every place that briefs a reviewer — `bug:review` §2.1, `work:respond` §6.1, `work:green` §5 — and it is deliberately narrow: don't fence the reviewer off, not doubt everything.

**A panel that runs at 2-of-6 says so in the artifact.** `quality.review_skill` / `quality.reviewers` define a roster whose members own whole categories that the rest of the flow explicitly does not revisit — so a skipped reviewer is a category with no owner at all. `Agents launched:` was free text and never asked what *should* have run. §2.1 now says to launch the panel **as defined** — whole roster, no hand-picked subset, no substitutions — and the output field asks for **ran vs defined** (`N/M`, naming who did not run and why, and any substitution). A partial panel is now visible in `06-review.md`, before the MR/PR opens.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. **No new FLOW.md keys**, no new phase, no extra agent.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.22.0...v0.23.0

## v0.22.0 — `/flow:work:green` means *mergeable*, not just a green pipeline  ·  2026-07-27

### A green pipeline on an MR you cannot merge, reported as "you're good to go"
`/flow:work:green` only ever looked at the CI pipeline. So on an MR with **conflicts** it fetched the jobs, saw them green, and stopped — telling you everything was fine about a request that was impossible to merge. Conflicts, a branch behind base, a forgotten draft, missing approvals: none of it was in the command's field of view.

Now the command reads **both halves** of the state, every round:

- **The forge's own merge verdict** (§2.1) — `detailed_merge_status`, `has_conflicts`, `draft`, `blocking_discussions_resolved`, `approvals_left` on GitLab · `mergeable`, `mergeStateStatus`, `reviewDecision` on GitHub. `UNKNOWN`/`checking` is **not** an answer: both forges compute mergeability asynchronously, so it re-queries before concluding anything and never reports "no conflicts" from an unknown verdict.
- **The pipeline** (§2.2) — unchanged: failing jobs, logs, blocking vs allowed-failure.

And it decides on the **combination**: pipeline green but blockers remaining is no longer "green, you're good" — it reports the green, lists the blockers, and keeps working.

Two new triage categories join lint/test/type/flaky/gate:

- **C — conflict / behind base.** Treated as a **code decision, not a git chore**: it merges the base into the branch (**default `git merge`** — no history rewrite, no force-push, review comments stay anchored; rebase only if you ask, with `--force-with-lease`) and resolves each conflict **on its merits**, reading what the base changed *and* what `03-design.md` intended. Generated artifacts (lockfiles, snapshots) get **regenerated**, not hand-edited. Then it verifies **wider than the conflict** — the full local gate — because a marker-free merge can still be semantically broken. Cannot resolve on the merits? `git merge --abort` and hand it back with the question.
- **H — human blocker.** Draft, approvals missing, unresolved threads: **never worked around**. It names the blocker, says what is needed and from whom, and routes it (threads → `/flow:work:respond`). The closing summary lists the H blockers still standing.

**New hard gates**: integrating the base (any `merge`/`rebase` of the base branch, and any force-push it implies) always asks, in every mode. And green-washing now explicitly covers conflicts — no `--ours`/`--theirs` shortcut, no discarding the base's side to make the red go away.

- **`/flow:work:daily`** gained the same signal: an MR/PR that **cannot merge** is flagged separately from red CI, with the reason.
- **`/flow:work:respond`** nudges toward `green` for conflicts too, not just a red pipeline.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. **No new FLOW.md keys.**

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.21.0...v0.22.0

## v0.21.0 — flow moves your tickets: in-progress on start, done on ship, won't-do on abandon  ·  2026-07-23

### Tickets sat stale in the backlog while the work was already flowing
flow read the tracker but never wrote to it, so the ticket stayed in "To Do" while you were mid-feature and stayed "open" after you shipped — you had to move it by hand, or it rotted. Now flow can drive the ticket's state through the work, keeping the plugin **stack-agnostic**: you give it the commands, it runs them.

New **optional** `tracker` keys in `FLOW.md` (empty = current behavior, nothing runs):

- `start_cmd` — run on `/flow:feat:start` & `/flow:bug:start` to move the ticket to **in progress** and assign it (`{TICKET}` and `{ASSIGNEE}` substituted).
- `done_cmd` — run on ship **when the work actually completes** (`phase` reaches `done`, i.e. the completing MR/PR is merged) to move it to **done**. Tied to real completion, **not** to archiving the folder — so a shelved-but-not-shipped work never gets marked done.
- `abandon_cmd` — run on `/flow:work:abandon` to move the ticket to **won't-do / cancelled**, never "done".
- `assignee` — the tracker account for `{ASSIGNEE}` (falls back to `git.assignee`).

The three transitions are **best-effort, idempotent, and gated**: outward-facing, so they ask before running in `autonomy.mode: manual` and run automatically in `guided`/`auto`; a failure or an already-in-state ticket warns and continues — **never blocks** the flow. They only run in ticket mode with a real tracker id.

- **GitHub/GitLab leave `done_cmd` empty** — `Closes #N` in the MR/PR body already auto-closes the issue on merge; the transitions are for trackers that don't move from git (Jira, Linear). `/flow:config` flags the redundancy and other incoherences (transition set but `tool: none`, `{ASSIGNEE}` with no assignee).
- **`/flow:init`** offers the transition commands with Jira/Linear defaults **only** when the tracker is `acli`/`linear`.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.20.0...v0.21.0

## v0.20.0 — work folders carry a slug: you can tell them apart on disk  ·  2026-07-23

### `.claude/work/MT-1234/` told you nothing when you had five of them open
In ticket mode the work folder was named just `<TICKET>` (`MT-1234`), so with several works in flight at once you couldn't tell which was which without opening each `meta.json`. Ticket-less works already had a readable slug; ticket mode didn't.

Now the folder is named `<TICKET>-<slug>` (e.g. `MT-1234-fix-login-validation`), reusing the **same** slug already derived for the branch — so branch and folder read alike. `meta.json` gains a `slug` field, and `meta.json.ticket` stays the **pure identifier** that feeds the tracker view, the issue link and `{TICKET}` in the branch — the id is never polluted with the slug.

- **`/flow:feat:start` & `/flow:bug:start`** — derive the slug once and name the directory `<TICKET>-<slug>` (ticket mode) or `<slug>` (ticket-less local-only). The "already exists" check globs both `<TICKET>/` and `<TICKET>-*/`.
- **Backwards compatible** — works created before this are still named `<TICKET>` and keep working: every other command locates a work by matching `meta.json.branch`/`ticket`, not by the folder name. `/flow:work:watch`, `/flow:work:status` and `/flow:work:abandon` were adjusted to glob/match instead of assuming the exact `<TICKET>` path, and `status` now shows the title next to the ticket.

Docs/command-logic only — no new FLOW.md keys, still stack-agnostic. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.19.0...v0.20.0

## v0.19.0 — cross-repo scope: flow stops forgetting the other project  ·  2026-07-22

### The other repo fell off the map
flow is **per-repo**: the `.claude/work/<TICKET>/` lives in the repo where you start. But plenty of tasks span two projects (a backend change plus its consumer, an API plus its client). Since the debate and the ticket usually start in one repo, the slice that belongs to the *other* repo was recorded **nowhere** — you'd `ship` the first part and the second was silently forgotten. `/flow:work:daily` (v0.17) was per-repo too, so it couldn't catch it either.

New `related_repos` field in `meta.json` (`[{ "repo", "scope", "status": "pending"|"in_progress"|"done" }]`), woven through the flow:

- **Capture** — `/flow:feat:start` and `/flow:bug:start` add a **Cross-repo scope** step: if signals point to another repo (the ticket names it, the conversation settles it), they ask once and record it. **Silent by default** — no signal, no question. `/flow:feat:design` and `/flow:feat:plan` refine the list when the design reveals a repo the conversation missed (a plan slice that lands in another repo goes to `related_repos`, not to this repo's `mrs`).
- **Recorded in the ticket too** — in **ticket-less** mode, when flow drafts and creates the issue, the *repos affected* go in the issue body, so the multi-repo scope lives in the tracker for the whole team, not only in the local `meta.json`.
- **Remind** — `/flow:feat:ship` and `/flow:bug:ship` call out any non-`done` entry after creating the MR/PR ("the `<repo>` part still needs `<scope>` → start the work there"). `/flow:work:daily`, `/flow:work:resume` and `/flow:work:status` surface them.

flow **only notes and reminds** — it never scans or touches the sibling repo (that would break the per-repo model). No new FLOW.md keys. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.18.0...v0.19.0

## v0.18.0 — `FLOW.md` is personal config: gitignore it, don't commit it  ·  2026-07-22

### "Team config, not secrets" was only half right
`FLOW.md` was documented as committable team config. But it mixes three different natures: **repo facts** (tracker, quality commands, conventions — genuinely shared), **your machine's environment** (`domain_memory.enabled`, which `agents.*` exist on *your* box, worktree paths), and **your flow tastes** (`autonomy.mode`, `assignee`, `review_depth`, per-command `notes`). Committing it as-is imposes one developer's preferences on everyone who clones and assumes their machine has the same tools installed — the same `FLOW.md` on another box can point at agents or an MCP that isn't there.

So `FLOW.md` is now treated as **personal config, not team config**:

- `/flow:init` no longer says "can be committed". It explains the file is personal, holds **no secrets**, and — if `FLOW.md` isn't already git-ignored — **offers to add it to `.gitignore`** (a confirmed edit, since it touches a tracked file).
- The `FLOW.template.md` header and the README say the same, and point you to gitignore it.
- Escape hatch preserved: a team that deliberately wants to share the repo-fact subset can still commit it by hand.

Documentation + `/flow:init` behavior only — no command logic or FLOW.md keys changed. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.17.1...v0.18.0

## v0.17.1 — `/flow:work:daily` stops nagging about threads you already answered  ·  2026-07-22

### The signal was "unresolved", and it should have been "awaiting *you*"
The first cut of `/flow:work:daily` flagged every **unresolved** review thread as *"go respond"*. But on both GitLab and GitHub a thread stays unresolved until the **reviewer** closes it — and `/flow:work:respond` **never resolves threads** by design (that call is the reviewer's). So a thread you already answered stays unresolved forever, and the daily kept telling you to respond to MRs you'd already handled. Real report from the field: `!9707` was fully answered, yet the briefing still put it under *"respond today"*.

The forge layer now keys off the right signal — **whose comment is last**:

- **Threads whose latest comment is *not* yours** (someone left you something unanswered) → the real `/flow:work:respond` signal, fetched per open MR/PR (`glab api …/discussions` · `gh api` review threads) and compared against `git.assignee` / `@me`.
- **Threads you already answered** (unresolved, but the last word is yours — waiting on the reviewer) → moved to a separate **Awaiting others** line, **informational only**, never in *Blockers*. *Blockers* is now strictly what **you** must act on.

No new FLOW.md keys; a `patch`. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.17.0...v0.17.1

## v0.17.0 — `/flow:work:daily` — your work assistant (the Scrum-style standup)  ·  2026-07-22

### The morning question the flow couldn't answer
You come back the next day and ask *"what was I working on?"*. Until now the flow had two half-answers: `/flow:work:status` (a technical control table — phases, MRs, artifact↔git divergence) and `/flow:work:resume` (the current branch, one work). Neither is the thing you actually want in the morning — a **cross-cutting, narrative catch-up** — and, more importantly, **both are blind to everything outside `.claude/work/`**. A ticket assigned to you overnight, a priority bumped while you were heads-down, an MR/PR awaiting *your* review, a pipeline that went red — none of that lives locally, so the flow never surfaced it.

New `/flow:work:daily [question]` — read-only, cross-cutting, combining **three sources**:

- **Local** (`.claude/work/` + git): what you were on, what was left mid-way, ordered by recency.
- **Forge** (via `git.cli`): your open MRs/PRs, the ones **awaiting your review**, **red CI**, and **unresolved threads**.
- **Tracker** (via `tracker.tool`): tickets **assigned to you**, **priority changes**, status drift.

The value is where the sources **cross**, turned into concrete *suggested* commands (never auto-run): a ticket assigned to you with **no local work** → `/flow:feat:start`; a local work in `done` whose ticket is still open → a divergence to close; **red CI** → `/flow:work:green`; **open threads** → `/flow:work:respond`; a **raised priority** → a possible refocus.

- **No argument** → a three-block briefing (*yesterday · today · blockers*) + a short list of next commands.
- **A question** (`/flow:work:daily what's left on the payment work?`) → answers just that, from the same sources.
- **Every external source is best-effort**: if a CLI is missing/unauthenticated or slow, it degrades with a one-line note (`(forge unavailable: …)`) and **never blocks** — the same discipline the flow already applies to `domain-memory`.
- **Read-only**, with a single documented exception: a `~/.claude/flow/daily-last-seen` marker (exactly like `/flow:news`) so *"since last session"* is precise across sessions.

**No new FLOW.md keys** — it reuses `tracker.tool`/`tracker.view`/`tracker.prefix` and `git.host`/`git.cli`/`git.assignee` the flow already needs. Scoped to the current repo (flow is per-repo). Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.16.0...v0.17.0

## v0.16.0 — `/flow:work:respond` gets the full review ladder  ·  2026-07-21

### Closing the quality gap in the review loop
`/flow:work:respond` implements code changes agreed in an MR/PR review round, but its quality gate was a **single** built-in `code-review` (or `review_skill`) pass — a fraction of what `/flow:feat:review` runs. So the exact place where a wrong primitive or an over-engineered mechanism slips in under pressure ("just extract it to a class to answer the comment") had the **weakest** gate in the whole flow, and the result went straight into an MR/PR already under human eyes — producing the *next* round of comments instead of closing the thread. The risk was inverted: highest-risk edits, flimsiest check.

`respond §6` now runs the **same ladder as `/flow:feat:review`**, scoped to the round's diff:

- **Trivial rounds** (nitpicks only, no new classes/wiring) keep the single `code-review` pass — no added latency.
- **Non-trivial rounds** run the review machinery scoped to the round: the **§2.0 depth ladder** (effort by size + sensitive-surface bump, panel when selected), the **§4 over-engineering / YAGNI audit**, the **§5.5 idiom / primitive audit (blind to the design's rationale)** — the two that catch exactly this loop's failure mode, with §5.5 **always** running when the round introduces new architectural pieces regardless of size — the **§5 contract check**, and the **§7 local gates** (`style_fix` / `static_analysis` / `test_one`).
- **Lightweight mode** (no `03-design.md`) degrades cleanly: §5 is skipped, §4 judges YAGNI against the code itself, and §5.5 runs unchanged (it needs no artifact). A blocker fix that reopens the debated approach loops back to §4 to re-agree the stance before editing again, instead of silently re-patching.

**No new FLOW.md keys** — it reuses the `quality.*` and `agents` keys the flow already needs. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.15.0...v0.16.0

## v0.15.0 — `/flow:work:green` — the CI-green loop between ship and merge  ·  2026-07-20

### The pipeline half of the between-ship-and-merge window
`/flow:work:respond` covered the **human** signal in an open MR/PR (review threads). But the same window carries a **machine** signal `respond` never touched: the CI pipeline going **red** — lint, tests, type-check, build. A red pipeline can happen with **zero** review comments (where `respond` just stops), and green is usually a *precondition* for review anyway. Different signal, different loop.

New `/flow:work:green [mr-iid-or-url]`:

- **Fetch** the latest pipeline for the branch/MR and its failing jobs + logs via `git.cli` (`glab ci` / `gh pr checks` + `gh run view --log-failed`).
- **Triage** each job into lint/style · test failure · type/build · flaky/infra · quality-gate, pulling the recorded design "why" so a test failing on the *old* behavior is told apart from a real regression.
- **Fix at the root** — delegating to the flow's `agents`, reproducing locally with your `quality.*` commands (`style_fix`/`test`/`static_analysis`…) so it does not burn CI cycles, with the review gate on non-trivial diffs.
- **Hard gates** on every push and rerun, plus the cardinal rule: it **never green-washes** — no blind reruns, no disabling/skipping a check or loosening a threshold to force green. That is the machine analog of `respond` never resolving a thread: a green must mean the code is actually correct.

Cross-cutting (feat or bug), repeatable, logged to `09-ci.md`; does not advance `meta.json.phase`. `respond` now glances at the pipeline and nudges you to run `green` first when CI is red. **No new FLOW.md keys** — it reuses `git.*`, `quality.*`, `agents`, `autonomy.mode`, `domain_memory.*`. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

### Comment discipline when writing code
The code-writing commands (`/flow:feat:build`, `/flow:bug:fix`, and now `/flow:work:green` / `/flow:work:respond`) now carry an explicit rule: add a comment only for a non-obvious *why* (a constraint, the reason for a workaround, a subtle invariant), never to narrate what the code already says, matching the surrounding file's comment density. And the ticket ID, task/step number, or "for MR #N" **never** go into a code comment — that traceability belongs in the commit, branch and MR/PR, where it stays accurate, not in the source, where it rots. Stated as a principle in the work README and enforced at each editing step. Mirrored across the adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.14.0...v0.15.0

## v0.14.0 — per-MR/PR review/validate gate (train shortcut closed)  ·  2026-07-17

### The ship gate is now per-MR/PR, not per-work
`/flow:feat:ship` refused to publish unless `review` (and, above `XS`, `validate`) had run — but it checked the **work-level** `phases_done`, a single list per ticket. In a multi-MR/PR feature that list accumulates and never resets, so once the **first** MR/PR completed review/validate the gate passed **for free** on every later MR/PR. A train MR/PR could ship unreviewed just because an earlier sibling had been reviewed — precisely the shortcut the flow exists to prevent, and it bit exactly on the MR/PR that carried a defect.

Now each `mrs[]` entry carries its **own** `phases_done`:

- `/flow:feat:build`, `/flow:feat:review` and `/flow:feat:validate` record `build`/`review`/`validate` into the **current `in_progress` MR/PR's** entry, and their pre-flights require the previous phase on **that** entry.
- `/flow:feat:ship §1` gates on the current MR/PR's own `phases_done` when the work has more than one MR/PR — a sibling's review no longer satisfies it.
- `/flow:feat:plan` seeds every entry with `phases_done: []`; a hot-cut in `/flow:feat:build §2.3` inserts the new entry the same way.

Single-MR/PR works (all `XS`/`S`, and the whole `bug` flow) are unaffected — they keep using the work-level list.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.13.0...v0.14.0

## v0.13.0 — ticket-less start + `/flow:news`  ·  2026-07-17

### `start` from a conversation, no ticket required
`/flow:feat:start` and `/flow:bug:start` now take an **optional** argument. Run them with **no argument** and, instead of stopping to demand a ticket, they synthesize the work from the conversation you just had — the same way `ship` builds the MR/PR body from the work log:

- **feat** distils title, summary, provisional acceptance criteria, the decisions you already closed while talking, and an estimated size.
- **bug** distils the symptom, severity/environment, reproduction, initial clues, and what you already found together investigating.

You confirm the draft, a slug becomes the work identifier, and it **offers to create the real tracker issue** from the draft (always asks — outward-facing, like the MR/PR gate). Decline, or no tracker configured → it proceeds local-only with the slug. Passing an identifier keeps the classic behavior unchanged.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

### `/flow:news` — what changed since your version
New command that reads this bundled changelog and prints everything new between the version you were last on and the installed one (jump three versions → see all three). No args → the delta since you last ran it; `vX.Y.Z` → since that version; `N` → the last N entries; `all` → the lot. It tracks your "last seen" version in `~/.claude/flow/news-last-seen`.

A **SessionStart hook** (`notify-update.sh`) also surfaces a one-line nudge the first session after the plugin version changes, so you know to run `/flow:news`. It uses a separate marker and never eats the delta. Mirrored to the opencode / Codex CLI / Gemini CLI adapters as a pull-only command (they read the changelog `install.sh` drops in `~/.claude/flow/`; the auto-nudge is Claude Code-only).

### Discoverability
`plugin.json` now carries `homepage`/`repository`, and this `CHANGELOG.md` ships with the plugin — so users updating from the marketplace have a path to the notes.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.12.0...v0.13.0

## v0.12.0 — review effort ladder scales to xhigh/max by size + risk  ·  2026-07-17

### Review effort scales to `xhigh`/`max` for the riskiest work

The size-scaled review (`§2.0`) capped the built-in `code-review` at `high`, leaving the two most thorough tiers unused. Now **risk — not just line count — buys the most thorough pass**.

#### Canonical (Claude Code)
`feat/review.md` and `bug/review.md` §2.0 use the full ladder `low < medium < high < xhigh < max`:

- Base by size: XS `medium`, S `high`, M `high`, **L `xhigh`** (was `high`).
- **Sensitive-surface bump** (auth/authorization, secrets, payments/billing, personal/sensitive data, public API/contract shape, DB migration): raise one tier and force the panel → S/M sensitive at **`xhigh`**, **L sensitive at `max`**.
- `full` mode bumps `high → xhigh`.
- The review output records the effort used, for traceability.

#### Adapters (opencode / Gemini CLI / Codex CLI)
Stay stack-agnostic: the flat "high effort" becomes *"escalated to the maximum thoroughness the tool supports for L-sized or sensitive-surface work"* — no Claude-specific flag names. Same graceful-degradation pattern as `work:watch`.

#### Notes
- No new `FLOW.md` keys — only the semantics of `review_depth` are enriched (documented in `FLOW.template.md`).
- The §6 adversarial verification is unchanged.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.11.0...v0.12.0

## v0.11.0 — /flow:work:respond, the review loop between ship and merge  ·  2026-07-17

### `/flow:work:respond` — the review loop between `ship` and `merge`

The flow ended at `:ship` (open the MR/PR). This release adds the phase that was missing: the MR/PR is open, reviewers comment, a discussion happens on the code, and only after agreement do you decide whether to change something, defer it, or hold your ground.

`/flow:work:respond [mr-iid-or-url]` runs that round:

- **Fetches** the open threads via `gh`/`glab` (host-agnostic).
- **Triages** each: question · nitpick · change request · design debate · out-of-scope · obsolete.
- **Debates** with a reasoned position per thread, grounded in the rationale the flow already recorded (`03-design.md` ADR-light + `domain-memory`) instead of re-deriving it.
- **Implements** the agreed changes reusing `build`/`fix` mechanics (with the review gate for non-trivial diffs).
- **Replies** — hard gates on every posting and push, and it **never resolves a thread** (the reviewer's call).

Cross-cutting (feat and bug), repeatable (one run per review round), logged to `08-feedback.md`. No new `FLOW.md` keys — reuses `git.*`, `tracker.*`, `quality.review_skill`, `autonomy.mode`, `domain_memory.*`. Ships the canonical command plus faithful opencode / codex / gemini adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.10.0...v0.11.0

## v0.10.0 — plan waves, MR-body ref hygiene, review idiom audit  ·  2026-07-13

topological wave numbering in `/feat:plan` (`n` is execution order, no more "start at #5"); never emit the plan's `#n` in MR/PR bodies (kills the `#5 (closed)` auto-link); blind idiom/primitive audit in `/feat:review` §5.5 + de-anchoring of reviewers from design rationale. Merged via #11.

## v0.9.0 — manual-mode one-click handoff + autonomy for codex/gemini  ·  2026-07-08

manual-mode one-click step handoff; autonomy ported to codex/gemini adapters. Merged via #10.

## v0.8.0 — the `flow` prefix  ·  2026-07-06

Every command across the Claude Code plugin **and** the three adapters now lives under a single `flow` prefix, so typing `/flow` lists them all. Naming is mechanically derivable from Claude Code.

| Claude Code | opencode / Codex | Gemini CLI |
|---|---|---|
| `/flow:feat:start` | `/flow-feat-start` | `/flow:feat:start` |
| `/flow:work:status` | `/flow-work-status` | `/flow:work:status` |
| `/flow:save-knowledge` | `/flow-save-knowledge` | `/flow:save-knowledge` |
| `/flow:init` | `/flow-init` | `/flow:init` |

#### Changes
- **Adapters (#8)** — renamed 67 command files; opencode/Codex re-prefixed (`:` → `-`), Gemini nested under `flow/` (directory → `:` namespace) so it's now identical to Claude Code. Updated every cross-reference, README table, tree diagram, `install.sh` banner, `PRIMITIVES.md` and `AGENTS.md`.
- **Plugin + docs (#9)** — fixed the root README per-tool syntax, and normalized 188 internal cross-references in the canonical plugin (which mixed `/flow:bug:diagnose` with bare `/feat:build`) to `/flow:*`.

#### Result
Plugin, adapters and docs all agree on every command name. Zero un-prefixed or double-prefixed references remain.

> ⚠️ Breaking for adapter users: old invocations (`/feat-start`, `/feat:start`) no longer exist — use the `flow`-prefixed names above.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## v0.2.0 — GitLab/GitHub issues as selectable trackers  ·  2026-06-23

First tagged release of the **flow** plugin.

### What's new in 0.2.0
- **GitLab issues** added as a first-class, selectable task tracker (`tracker.tool: glab`), alongside Jira (`acli`), GitHub issues (`gh`) and Linear.
- `/flow:init` now offers the tracker options **without preselecting** (the git host does not determine the tracker — a GitLab repo may still track in Jira) and auto-fills `tracker.view_cmd` from the chosen tool, warning if the `gh`/`glab` CLI is missing.
- `FLOW.template.md` documents per-tool `view_cmd` examples.

Tracker integration stays **read-only and symmetric with Jira**: the flow reads the ticket at start; you create/assign issues yourself.

### How to upgrade
- **Claude Code plugin**: update `flow` from the plugin manager (`/plugin`). Your repo's `FLOW.md` is untouched.
- **Adapters (opencode/gemini/codex)**: pull and re-run `adapters/install.sh`.

To switch a project to GitLab: set `tracker.tool: glab` and `tracker.view_cmd: glab issue view {TICKET}` in its `FLOW.md` (or re-run `/flow:init`).

