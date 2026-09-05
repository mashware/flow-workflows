# Changelog

All notable changes to the **flow** plugin, newest first. This file is bundled with the
plugin and is what `/flow:news` reads to show you what changed since your previous version.

The canonical, richest notes live in the [GitHub Releases](https://github.com/mashware/flow-workflows/releases).

## v0.44.0 — The duel picked the best of three new queries and never asked about the old one  ·  2026-09-05

**In short**
- A **modified** query is now measured against **its own version on the merge base**, not only against the challenger's and reviewer's proposals.
- New `quality.bench_cmd` benchmarks a touched route, command, consumer or job on both sides — wall time and peak memory.
- Times are reported `min–max` across three runs, and **a difference inside that spread is "no measurable change", never a percentage**.
- The numbers reach the reviewer: a **comment** on the MR/PR, re-posted whenever a later push changes a measured path.

**The measurement table compared the wrong things.** `/flow:work:query` §4 seeds a sandbox, takes the plan, runs three times and reports rows read against rows returned — real evidence, and better than most review processes have. But its rows were *as written*, *challenger's proposal*, *reviewer's proposal*: three candidate implementations of the **new** query. There was no row for the query as it exists on `main`. So the duel answered "which of these three is best" and never "did this diff make things better or worse" — and a variant can win against its siblings while being slower than the code it replaces.

**Nothing outside queries was measured at all.** The performance agent in `review` and `validate` *reads* code: it detects N+1, unbounded queries, flush in a loop, per-iteration calls leaving the process. It runs nothing. No endpoint timing, no memory figure, no before and after for a route or a job. The only real measurement in the plugin was `/flow:work:watch`, and that runs **after deploy**, against production observability, when the code is already merged and live.

**And none of it reached the reviewer.** Every number landed in `06-review.md`, inside `.claude/work/`, which `/flow:init` offers to git-ignore and `ship` archives. The MR/PR carried prose.

**The base row.** For every query the diff *changes*, the duel measures the same query at `git merge-base HEAD <git.default_base>` — same sandbox, same seed, same three runs. A baseline on a different data set is not a baseline, and a base version that cannot be run is recorded as **not measured** with the reason, never estimated from reading the old code. New `regressed` verdict, blocking like `change` unless `03-design.md` justifies the trade. The bug chain demanded this for slowness bugs already; it now applies to any query a fix modifies, because a fix that quietly costs 40 ms is a regression whether or not the ticket mentioned speed.

**`quality.bench_cmd`** is how this repo exercises one entry point and reports time and memory, with `{TARGET}` substituted. Free text passed to the harness, like every other command key — the plugin ships no benchmarking tool and stays stack-agnostic. Empty → the phase says so once and skips, and **no timing claim is made at all**.

**The noise floor is a feature, not a caveat.** Three runs on a developer machine with containers up produce variance that reads happily as a 5% improvement. Publish those and the table is disbelieved within a fortnight — at which point the real regressions stop being read too. So: `min–max`, never a mean; a difference inside the spread is *no measurable change*; and when times overlap, the counts (rows read, queries executed) lead, because those are not noisy.

Mirrored across the opencode, Gemini CLI and Codex adapters by the generator.

## v0.43.0 — The one thing validate could not prove, it asked you to prove for it  ·  2026-09-05

**In short**
- `validate` now **drives the running app itself** over every `needs-manual` acceptance criterion, and only hands over what it genuinely could not — with the reason recorded.
- What it observed is captured under `.claude/work/<work>/evidence/`, and `ship` attaches it to the MR/PR description as before/after.
- `/flow:work:try` resolves the work behind the branch and **prints the manual test plan** once the environment is up, collecting Pass/Fail/Blocked there.
- A bug's original symptom is now re-run against the fixed app: still reproducible is a red gate, whatever the suite says.

**Everything else this phase produced was evidence the agent generated.** A named test, a green suite, a measured execution plan. `needs-manual` was the one bucket where the evidence was the *user's*, taken on the agent's word about what to go and look at — while a browser automation tool or a simulator sat unused on the same machine. New §3.5 exhausts that first: read `quality.functional_check` (or whatever `/flow:doctor` detects), drive the criterion's given/when/then, and record `proven-by-agent`, `needs-manual` **with the reason**, or a failure that blocks the gate exactly as a failed manual check does.

**Reading the code and concluding it must work is `needs-manual`, not proven.** The same rule the data-access duel already applies to an unmeasured plan, and the only thing that makes the new status worth anything.

**`ship` stops describing the result and shows it.** The description carried *Steps to test it* and a collapsed technical block — a reviewer meant to approve with full context and usually without reading code got instructions to reproduce, never the result. `## Evidence` now sits between what changes and how to test it, one entry per criterion, before next to after. Files are **uploaded to the forge**, never linked by a `.claude/work/` path that is git-ignored and renders as broken text for everyone else; when no upload route exists the section survives as a table and the stop says so.

**`try` stopped running blind.** `validate` §4 tells you to go run `/flow:work:try`, and `try` knew nothing about the work: it switched the checkout, re-synced, and left you to come back and ask for the plan again. It now finds the work by branch and prints what is already written — the `needs-manual`/`unproven` criteria in their given/when/then wording, or the acceptance criteria when `validate` has not run yet, or the reproduction steps for a bug — and offers to collect the verdicts into the validation artifact. `--back` closes the loop with what was verified and what is still open.

**A bug fix now has to survive its own reproduction.** `bug:validate` §2.5 re-runs the minimal reproduction from `02-diagnose.md` against the fixed code. The before was captured when the failure was first reproduced — the one moment it exists — so a bug fix ships with the pair that *is* the argument.

Two new `quality` keys: `functional_check` (how to drive this repo's app) and `evidence` (`on` by default; `off` disables capture and attachment). Both empty-safe: with nothing available every criterion stays `needs-manual` and you verify it exactly as before.

Mirrored across the opencode, Gemini CLI and Codex adapters by the generator.

## v0.42.0 — Every phase knew what it was choosing not to do, and told nobody  ·  2026-09-05

**In short**
- Work a phase deliberately parks — a neighbouring defect, an out-of-scope piece, an unmitigated risk, an unchecked edge case, a postmortem's prevention actions — is now a **record in `meta.json`**, not a line in an artifact that gets archived unread.
- `ship` triages the whole set **once**, at the end: *do it* · *not worth it* · *later*. Accepted ones get their tracker issue opened and an offer to start.
- Whatever is still open when the MR/PR is created is **named in its description**, so a reviewer sees what was consciously left out.
- `status`, `daily` and `next` surface the undecided ones — **including from `_archive/`**.

**"Note it as an idea for a separate ticket" appeared in six places and opened nothing.** `build` §2.4 sent it to a section of `05-implementation.md` nothing ever reads again — `ship` opens only that file's Brief. `design` wrote *Identified risks* that appeared in no other command. `validate` left `[ ]` edge cases and *Open risks* that `ship` never surfaced. `bug:validate` listed *other bugs detected* that `bug:ship` opened the file past. `postmortem` ended by literally saying *propose opening separate tickets (not done in this flow)*. And `plan` said *out of scope — idea for a separate ticket* **in the chat**, writing it nowhere at all: the one deferral that left no trace to find.

All of it inside `.claude/work/`, which `/flow:init` offers to git-ignore, and under `_archive/` the moment the work ships. The decision to not widen the diff was right every time. Everything after it was missing.

**The mechanism already existed, in one place.** `bug:fix`'s *Areas with similar risk* is the only deferral in the plugin that made the whole journey: written at `fix`, checked at `validate` for the same active symptom, published by `bug:ship` in the MR/PR description. That is the model this release generalises — no new idea, just the same one applied to the other six.

**`meta.json.followups[]`** (flow-core §7) carries `id`, `kind` (`prevention` · `audit` · `out-of-scope` · `risk` · `edge-case` · `other-bug`), `title`, `why`, `source`, `status`, and the `ticket`/`work` it turned into. The artifact keeps its human-readable section with the `F<n>` id in front of each row, so prose and record cannot drift.

**Nothing is asked when the note is written.** Mid-build is the worst moment to judge whether a neighbouring defect deserves a ticket, and a question there is exactly the interruption `guided`/`auto` exist to prevent. The triage happens once, at `ship`'s Close, batched up to four per question, with `title` and `why` as the entire prompt. *Later* keeps it open and visible; *not worth it* is recorded and never asked again. **Creating the tracker issue for an accepted one is outward-facing, so it asks in every mode**, `auto` included — the same category as the MR/PR gate.

**A work started from an accepted follow-up records `meta.json.origin`**, carries the recorded *why* into `01-context.md` instead of re-deriving it, and closes that entry when it reaches `done`.

Mirrored across the opencode, Gemini CLI and Codex adapters by the generator.

## v0.41.0 — The pull request said merged, and the branch it merged into was already gone  ·  2026-09-05

**In short**
- A stacked MR/PR whose parent is merged first lands its content **nowhere** — the forge says merged, the base branch never receives a line. `ship` now checks for it, at the Close and before the train moves on.
- The recovery is written down: re-target the child at `git.default_base` and rebase (hard gate), or, when it already merged into the dead branch, recover it as a fresh MR/PR.
- Confirming a merge now verifies the **tree**, not the badge: `git ls-tree` on the base for a path the MR/PR creates.
- `/flow:work:resume` and `/flow:work:green` check the same thing — a dead target branch is the one blocker a forge reports as green.

**PR 141 was merged into a branch `main` no longer descended from.** It targeted its parent branch in a train; PR 139 squash-merged that same parent into `main` **34 seconds earlier**, which replaced its commits with one new sha and left the parent branch off the base's history. GitHub marked 141 merged — and it was, into a branch that had stopped mattering. A whole decision-record entry and its guard were simply absent from `main`, and nothing surfaced it until somebody read the tree by hand.

**The train logic covered the wrong direction.** `/flow:feat:ship §6.2` already builds the next MR/PR of a train without waiting for the current one to merge — deliberately, so a train is not held back by review latency. What it never said is what to do when the **parent becomes mergeable before the child**. New §6.2.1: while a stacked MR/PR is open, check that its parent is still an ancestor of `git.default_base`; parent still open → the child merges first or is re-targeted before the parent goes in; parent already merged → re-target at the base and rebase (a force-push, so a hard gate in every autonomy mode); child already merged into the dead branch → recover it as a new MR/PR against the base, mark the old entry `superseded`, and say plainly what was missing and for how long.

**The window to fix it closes when the parent merges.** Merging the parent with `--delete-branch` deletes the child's target branch and the forge auto-closes the child — and a closed PR cannot be re-targeted, so a one-command fix turns into a new MR/PR and a lost review thread. §6.2.1 says to re-target first, and carries the fallback for when `gh pr edit --base` refuses (it fails with a GraphQL error on repos carrying the classic projects field): the REST API, on an open PR.

**A merged badge is not the tree.** Every confirmed merge in `ship` now asks git whether a path the MR/PR creates actually exists on `git.default_base`, and refuses to record `merged` when it does not. It is one command, and it is the only thing that would have caught this.

**Same check where a stale train is met again.** `/flow:work:resume` runs it in the repo-state block — the parent is most likely to have merged while you were away — and `/flow:work:green` captures it as a blocker row, because a dead target branch is precisely the state the forge does not report: mergeable, green, and worthless.

Mirrored across the opencode, Gemini CLI and Codex adapters by the generator.

## v0.40.0 — The flow told its agents what to read, never what to send back  ·  2026-09-05

**In short**
- Every brief a command writes itself now ends with a **report contract** — a word cap and a shape — because a report too long for the harness to carry is thrown away in transit and reaches the parent looking exactly like an agent that did nothing.
- Agents that produce volume (code, tests, a translation) are told **the file is the deliverable**, saved piece by piece, and the file is what gets verified.
- A fan-out now has a **deadline**: the harness signals an agent that finishes and never one that stops advancing, so every stop of a command checks the round it launched.
- Two new `agents` keys: `report_max_words` (empty = 250) and `stall_after_minutes` (empty = 25).

**Seventeen subagents, and not one delivered its report on its own.** In a single long session driven end to end with `/flow:feat:*`, four agents answered only when asked directly — fifteen minutes late — two more answered three hours late (with the best findings of the delivery, three real defects), and three produced nothing at all. The delivery itself took 73 minutes; the session spent another three hours waiting for reports that were never coming. Nothing tells a parent that a wait is futile.

**The truncation is invisible from the parent's side.** Claude Code discards a subagent result over ~16 000 characters and hands the parent a placeholder saying so. The agent finished, the report was written, and what arrives is indistinguishable from silence. Six of the seventeen hit exactly this, and every one of them had an uncapped brief. A stronger model makes it worse, not better: it writes more, so it truncates sooner.

**The flow already prevented this everywhere it wrote the prompt itself.** The briefs this plugin spells out — in `review`, `plan`, `design`, `investigate`, `brainstorm`, `query` — carry caps of 150 to 600 words, and not one agent launched from them failed. Every failure came from the places where the flow hands the pen to the calling agent and says nothing about the answer: the reviewer panel in `feat`/`bug` `review`, the delegated pieces in `build`, the testing and performance agents in `validate`, the design subagents in `design`. The rule was already the flow's; it just stopped at that boundary. It now lives once in **flow-core §6** and each of those steps points at it.

**Bulk work belongs on disk, not in a context.** One agent spent an hour on a 700-line chunk without touching a file while three siblings with larger chunks finished in twenty minutes each; when it was stopped, everything it had done was gone, because no brief had said the file was the deliverable. `build` now names the path the agent writes, requires a save after each finished piece, and verifies the artifact rather than believing the report.

**A stall raises no event.** The harness reports completion and never a stop, so a stuck round stays invisible unless somebody looks — which, in an unattended run, nothing prompts the parent to do. `flow-core §6` puts a deadline on every fan-out: record what the round should take, check it at **every** stop of the command, and stop, split and relaunch anything past `agents.stall_after_minutes` with nothing written to its path. An agent that went idle with an empty result is asked for it once before being dropped — in this session that question was worth three defects.

`stall_after_minutes: 25` is a first guess from one session and should be revisited once there are numbers from more. Mirrored across the opencode, Gemini CLI and Codex adapters by the generator.

## v0.39.0 — `init` only knew the stacks its author had used  ·  2026-09-02

**In short**
- `/flow:init` now detects Gradle/Maven (Android, Kotlin, Java), .NET (`*.sln`, `*.csproj`, EF Core migrations), Xcode/SwiftPM and Flutter, and proposes their test, lint, style and build commands.
- Multi-stack repos (a backend plus a mobile client) get one chained command per key, and `init` says so.
- The template's `quality` examples and the auto-discovery notes in `build`, `fix`, `review`, `config` and `doctor` name those stacks too.

**The flow was stack-agnostic; its wizard was not.** Nothing in the commands depends on a language — every quality gate is a command read from `FLOW.md` — but `/flow:init` only looked for a Makefile, npm, composer, pyproject, Cargo and go.mod, so an Android or C# repo got an empty `quality` section and a question, and lost the "auto-detects, you confirm" experience the wizard promises. It now recognises Gradle and Maven, .NET solutions and projects (with EF Core migrations raising the pre-deploy gate like Doctrine does), Xcode projects and Swift packages (asking for the scheme and destination when there are several), and Flutter. `/flow:doctor` checks those wrappers and binaries the same way it checks `make` targets.

Also: the push-guard test assumed a git identity, which a CI runner does not have — its throwaway repo could not commit, so every BLOCK case passed for the wrong reason and the first CI run went red. The test now sets its own identity.

## v0.38.0 — The flow asked for one product where it needed a role  ·  2026-09-02

**In short**
- New `knowledge` section in `FLOW.md`: four roles (`search`, `stage`, `read_staging`, `save`) filled by any MCP tool, CLI or skill — domain-memory, codegraph, a search over `docs/adr`, or whatever comes next.
- Every command names the role, never the product; an empty role degrades (no lookup · finding stays in the artifact · artifacts are the staging · `KNOWLEDGE.md` instead of a store).
- `search` accepts several providers, consulted in parallel; `knowledge.timeout_s` replaces the fixed 2 s.
- `domain_memory.enabled: true` keeps working as a legacy alias; `/flow:init` detects knowledge MCPs and proposes the mapping; `/flow:doctor` and `/flow:config` resolve the roles.
- `/flow:save-knowledge` works without a store: it appends to `KNOWLEDGE.md` at the repo root.

**Twenty-one commands named `mcp__domain-memory__*` by hand.** The flow only ever needed four operations from a knowledge store — look something up, note a finding, read what was noted, consolidate it — and one product's tool names were written into every step that used them, gated by one boolean. A team on `codegraph`, or on a memory server that does not exist yet, had nothing to fill in. The `knowledge` section names a tool per role, the commands say `knowledge.search` where they said the tool, and the resolution rules live once in flow-core §0.

**Only `search` buys anything on its own.** The other three roles exist for stores with a staging notion. With them empty nothing is lost: the finding that would have been staged is already in the phase artifact, `ship` and `postmortem` read the artifacts, and `/flow:save-knowledge` appends to `KNOWLEDGE.md` (asking once before creating the file, in every mode). `search` takes a list, so a repo can consult domain-memory for the business and codegraph for the structure in the same call.

**Nothing existing breaks.** `domain_memory.enabled: true` with no `knowledge` section resolves the four roles to the domain-memory tools, and the template keeps the key under a "legacy alias" heading. `/flow:init` stops writing it: it looks at the MCP tools exposed in the session, proposes the domain-memory mapping when those are there, any other search/knowledge/memory/graph tool as an extra `search` entry, and a `rg` over `docs/adr` when there is a folder and no MCP. `/flow:doctor` checks each configured role is reachable this session and suggests the new section when it finds the alias.

Mirrored across the opencode, Gemini CLI and Codex adapters by the generator; the legend line about the MCP now speaks of `knowledge.*` roles.

## v0.37.0 — The same rules were copied eighteen times, and the mirrors by hand  ·  2026-09-02

**In short**
- The shared rules (autonomy, gates, stop header, `panel.json`) live once in the `flow-core` skill, loaded once per session; every command was cut to its contract (~50% shorter).
- New `00-summary.md` handoff (≤15 lines) read first by every phase; artifacts open on demand. `/flow:init` writes a compact `FLOW.md` and offers to ignore `.claude/work/`.
- New `/flow:next` entry point; `quality.review_depth: light`; every review prints its cost line; `/flow:news` shows the "In short" bullets by default.
- The opencode / Gemini / Codex mirrors are generated by `script/adapter-build.py`; CI runs the preflight, the smoke test and both hook tests on every push.
- New docs: `CONCEPTS.md`, `PHILOSOPHY.md`, `DESIGN.md` (the rationale that left the prompts), a generated key table in `CONFIGURATION.md`; README rewritten around a quickstart.

**Every phase command carried the same 12 KB preamble.** Eighteen copies of the autonomy modes, the hard gates, the stop header and the `panel.json` spec — 3k tokens re-injected at every phase, so a chained `auto` run paid for them seven times, and a change to the panel spec had to land in eighteen files. They now live once, in `plugins/flow/skills/flow-core/SKILL.md`, and each command opens with one line pointing at it. The preflight refuses a command that carries a copy again.

**Contract, not justification.** Every rule in the commands came with the incident that motivated it, what would go wrong without it, and an example. That is worth keeping — for people. For the model it was tokens: the 33 commands weighed 667 KB. They were rewritten as numbered steps and tables, every rule, gate, default, artifact schema and section number intact (other commands cross-reference them), and the reasoning moved whole into `docs/DESIGN.md`. The commands are roughly half their size; the behaviour is the same.

**Phases read everything, every time.** "Read all prior artifacts" was the first line of every pre-flight. Each work now carries `00-summary.md` — what the work is, size and current MR/PR, the decisions that stand, the contracts and where their literal shape lives, what is pending — overwritten whole at every Close, and each phase names the one or two artifacts it still opens in full. `start` writes the first one; works started before this rule read as before and get one at their next Close.

**`FLOW.md` was read at every step, comments included.** The template is 239 lines, 144 of them comments, and `/flow:init` copied it. `init` now writes only the keys you set, one line each, with a pointer at the shipped template for the rest. It also asks whether to git-ignore `.claude/work/` (recommended) next to `FLOW.md`, and `.worktrees/` when worktrees are on.

**`/flow:next`.** Thirty-three commands and no first one to type. `next` looks at the repo and routes: no `FLOW.md` → `init`; a work on this branch → `resume`; otherwise `status` or `start`. Read-only, one `AskUserQuestion`, then it hands over.

**A review now says what it cost.** `quality.review_depth` gains `light` — the built-in `code-review` alone, no panel, no skeptics; a sensitive surface still gets the proportional tier. Whatever the tier, `06-review.md` and the stop header carry one cost line: subagents launched, reviewers · reinforcements · skeptics, tier and effort.

**The adapters are build output.** 1.7 MB of opencode, Gemini and Codex mirrors were condensed by hand — 10 to 25 % shorter than the originals, and the source of the last three patch releases. `script/adapter-build.py` now generates every mirror and an `adapters/<harness>/CORE.md` from the plugin: wrapper per harness, invocation prefix, `{{args}}`, the pointer at `~/.claude/flow/CORE.<harness>.md`, and a short legend mapping the Claude Code primitives the prose names to what that harness has. `adapter-new.py` and the parity exceptions are gone; `check.py` asks the generator whether anything is stale. `install.sh` copies the core file and the manifest alongside the changelog.

**There is CI now.** Wiring it up found that `script/tests/push-guard.sh` had its worktree block pasted twice, once before the throwaway repo existed, and never exited non-zero on a failing case — so it printed FAIL lines and reported success. Both fixed; 33 cases, exit 1 on any failure. `.github/workflows/preflight.yml` runs `check.py`, the whole adapter smoke test, both generators' `--check`, the push-guard cases and a new test for the update notice hook on every push and pull request. `RELEASING.md` said "there is no CI here"; it no longer does.

**Docs for someone who just arrived.** The README opens with what it is, three commands and a diagram; the argument moved to `docs/PHILOSOPHY.md`; `docs/CONCEPTS.md` is the glossary; `docs/CONFIGURATION.md` carries a key table generated from the template so the two cannot drift. Every changelog entry, this one included, starts with an "In short" list, which is what `/flow:news` prints unless you ask for `full`. Commands declare `argument-hint` for autocomplete and, the read-only ones, `allowed-tools`.

## v0.36.0 — The review said yes to code that had already changed  ·  2026-09-01

**In short**
- `review` and `validate` write `reviewed_sha`/`validated_sha` to `meta.json`; `ship` stops when `HEAD` moved past them.
- `/flow:work:respond` rounds are capped by new `quality.respond_max_rounds` (empty = 3, `0` = no ceiling).
- New `/flow:doctor`: read-only check of tools and auth, agents, MCP, hooks, base branch, worktrees, fan-out tool.
- New `script/adapter-smoke.py` and `script/adapter-new.py` check and generate the adapter mirrors per harness.
- README, `/flow:work:README` and `/flow:feat:start` name the change that belongs outside the flow (edit-and-commit).

Five gaps closed at once, four of them the same shape: a rule the flow states, and nothing that checks the rule still holds by the time it matters.

**A review that had passed was a review of *some* tree, and `ship` never asked which one.** The gate read `review` in `phases_done` — a phase name, which records that a review *happened* and cannot record what it looked at. So the honest sequence `review` → a few more commits → `ship` pushed code no reviewer had ever seen, with the gate reporting itself satisfied; in a train, where an MR/PR can sit reviewed for days before its turn, the window was as wide as the queue. `review` and `validate` now write `reviewed_sha` and `validated_sha` into `meta.json` (work-level and per MR/PR) **only when the phase actually advances** — a review that ended in blockers reviewed nothing that stands — and `ship` compares them against `HEAD`. A mismatch is judged by **what the delta touches**, never by its size: test files and the work's own folder are the normal order of this flow and pass with a note in `06-review.md`; anything else stops and asks in **every** autonomy mode, offering a re-review scoped to `<sha>..HEAD` rather than the whole branch. Absent shas — every work already in flight — are not a mismatch: one line, and it continues.

**`/flow:work:respond` could argue with a reviewer for ever.** The loop had no ceiling: each round appended to `08-feedback.md`, and a round that restated the previous one looked exactly like progress. Now the round count lives in `meta.json` (`respond_rounds`, per MR/PR) and is checked **before** the round starts, against the new `quality.respond_max_rounds` (empty = 3, `0` = no ceiling). At the ceiling the command stops in every mode and hands back the three things a human needs to break the tie: which threads are open and about what, what each spent round already tried, and the one sentence the two sides do not agree on. And a reply that repeats an earlier round's position with no new evidence escalates immediately instead of spending the rest of the budget.

**New: `/flow:doctor`.** `/flow:config` reads the configuration; nothing read the world it assumes. So the failures arrived mid-phase: the git host CLI *installed but not authenticated* — which passes every presence check — discovered at `ship`, with the work finished; an agent named in `FLOW.md` that does not exist on this machine discovered never, because the review panel just runs with fewer reviewers and still reports a clean pass; a push guard that lost its executable bit, whose only symptom is a push to `main` that nobody stopped. `/flow:doctor` checks tools and their auth, agents, MCP reachability, hooks and their bit, base branch and worktree sanity, and the harness's fan-out tool. Read-only, quiet on success, findings ordered by what they cost — the ones that fail open and silently first — each with its fix on the same line. `/flow:config` §3 stopped duplicating the half it did badly and points here instead.

**The adapter mirrors are now checked for being *usable*, not just present.** Parity asked whether a mirror existed; freshness asked whether it was older than its command. Neither could catch the mirror that is present, current and unusable — wrapped in a format its harness does not read, or teaching the *other* harness's invocation prefix, which hands the user a command that does not exist. `script/adapter-smoke.py` checks the wrapper per harness (opencode frontmatter · Codex none · Gemini TOML), the prefix throughout the body, and that every command and path cited exists; its static half runs inside the preflight. Its second half executes `adapters/install.sh` against a throwaway `HOME` and verifies the files land where each harness looks, changelog included — with none of the three harnesses installed. `script/adapter-new.py` generates a new command's three mirrors mechanically (right place, right wrapper, prefix rewritten in either direction) with the body marked for hand-condensing, and `--from` wraps a body condensed once for all three; both were used to add `/flow:doctor` in this release. The README's warning is narrower and truer now: verified on paper, still never executed inside opencode, Gemini or Codex.

**And it now says when *not* to use it.** The size dial prunes phases; it never said "this is not a work at all", so XS — four commands, a branch, a folder — read as the floor. `README.md`, `/flow:work:README` and `/flow:feat:start` now name the change that belongs outside the flow (one sentence, one file, no review, and the suite either passes or it does not) and offer the edit-and-commit alternative instead of opening a work, in every mode. It goes back to being a work the moment it needs a ticket, or someone else has to understand later why it was done, or it touches a schema, a contract, or anything with a rollback story. Ceremony that has not earned itself is not rigour; it is how a process gets abandoned.

## v0.35.1 — The guard read the branch from the wrong directory  ·  2026-08-24

**In short**
- The push guard judges the directory the push runs in (`git -C`, `cd`); pushes from worktrees are no longer blocked.
- Paths named after the main branch (`.worktrees/main`) are not read as refspecs.
- Fourteen new cases in `script/tests/push-guard.sh`.

**Pushing from a worktree was blocked, and worktrees are what this plugin tells you to use.** The push guard's first check read `HEAD` wherever the hook happened to run — the session's directory — and refused the push if that said `master`/`main`. Under `worktree: always` the main checkout stays on the main branch by design while the work branch lives in `.worktrees/<branch>`, so every legitimate `git push -u origin HEAD` from a worktree was refused, and the reason it gave named a branch nobody was pushing. The only ways out were moving the session into the worktree or having you run the push by hand — an agent stopping to ask for a push is the failure this hook was supposed to prevent, not cause.

The check now resolves the directory the push actually runs in: `git -C <path>` aims one push, `cd <path>` moves everything chained after it, and both compose the way the shell composes them. Checks 3 and 4 read that directory too, so `--all` sees the right refs and a blind push is judged against the *worktree's* upstream instead of the main checkout's. A path only a shell could resolve (a variable, a glob, `~`, `-`) leaves the directory where it was, and a `cd` behind `||` — which may never run — is not trusted: both land on the session's checkout, the one most likely to be sitting on the main branch, so an unreadable command errs towards refusing.

What still blocks is unchanged, and the guard did not get looser: a bare `git push -u origin HEAD` from a checkout that really is on the main branch is refused exactly as before, and so is `cd <worktree> && git push origin HEAD:master`. New in the strict direction: a worktree whose *path* is named after the main branch (`.worktrees/main`, a clone in `~/src/master`) no longer trips the loose-token check on its spelling — a directory name is not a refspec. Fourteen new cases in `script/tests/push-guard.sh`, including the session directory arriving in the hook event rather than being inferred.

## v0.35.0 — A fix was Done before anyone had merged it  ·  2026-08-19

**In short**
- `/flow:bug:ship` and `/flow:feat:ship` ask for merge confirmation before `phase: done` and `tracker.done_cmd`.
- Bug size tables route `fix → validate → review`; M lists `ship`, and `bug:ship` requires the postmortem on M.
- `/flow:bug:start` follows `git.branch_pattern` and registers the GitHub linked branch.
- The push guard strips flags (`-f`, `--force-with-lease`), refuses `--all`/`--mirror`, and blocks when `jq` is missing.
- Preflight checks mirror freshness via git, JSON parsing, hook exec bits and preamble copies; new `RELEASING.md`.

Three audits over the tree — commands, tooling, docs — found the same shape of defect in three places: a rule stated in one file and contradicted in another, where nothing checked which one was true.

**`/flow:bug:ship` closed the ticket when it opened the MR/PR.** Its Close set `phase: "done"` and ran `tracker.done_cmd` immediately after creating the request, so on Jira or Linear the ticket moved to Done while the fix was still waiting for its first reviewer. `/flow:feat:ship` had always asked for merge confirmation first, and the template said `done_cmd` runs when a work "SHIPS **and is merged**" — the bug flow was the odd one out. Both flows now ask once, and `phase` stays `ship` until the answer is yes: `green`, `respond` and `clean` all read that difference, and a work parked at `done` with an open MR/PR sends all three at the wrong target. The single-MR/PR case in `feat:ship` had the same silent gap ("once merged" with nothing that ever asked) and is closed too.

**The bug flow told you to review before validating.** The size tables in `/flow:bug:start` and `/flow:work:README` routed S through `fix → review → validate`, while `/flow:bug:review` refuses to run without `validate` in `phases_done` for anything S or larger. Following the table walked you into the gate. The tables now say `fix → validate → review` — the regression test is what proves the fix, and a review that has not seen it green is reviewing a claim — and M, which the tables always routed through postmortem, now also lists `ship`, which it had been missing. `bug:ship` requires the postmortem on M as well as L, matching what `bug:review` suggests.

**A fix branch ignored the repo's own branch convention.** `/flow:bug:start` hardcoded `$ARGUMENTS-fix-slug` instead of reading `git.branch_pattern`, so a fix branch did not match what the team greps for and, on trackers that link by branch name, never reached its ticket. It follows the pattern now (empty → `{PREFIX}{TICKET}-{slug}`, a default the template had never stated) and registers the GitHub linked branch like `feat:start` does — the link that survives a train, where a `Closes #N` in the body does not.

**`git push --force` walked through the guard written to stop it.** The hook's blind-push check required the command to *end* in `git push [origin]`, so any flag at all — `-f`, `--force-with-lease`, even `-v` — pushed the match off the end and the push went to the main branch. It now strips the options, sees whether a refspec was actually named, and applies the upstream check whenever one was not; `--all` and `--mirror` are refused outright. And when `jq` is missing the hook no longer waves every push through in silence: it blocks and says why. Twenty cases exercised, including the four flag forms that used to slip past.

**The preflight now reads content, not just filenames.** Adapter parity checked that a mirror *existed*, so an adapter could sit five versions behind and pass — the failure this repo is most exposed to, with 14k hand-condensed mirror lines and no generator. It now asks git: a plugin command newer than its mirror, or edited in the working tree while the mirror is untouched, fails. Deliberate exceptions live in `script/adapter-parity.exceptions`, scoped to one sha each so the next real edit expires them. Also new: every tracked `.json` must parse (`hooks.json` included — nothing but the loader reads it), hooks must keep their executable bit, orphaned adapter files are reported, the 18 copies of the shared phase preamble are compared against each other, and retired `panel.json` vocabulary is refused anywhere in the tree.

**One panel vocabulary instead of two.** Seven commands still taught `Right now:`, `Waiting on you:` and grouping the MR/PR train `under Left` — labels the panel's reader does not know, so those lines quietly lost their column, and a layout `/flow:work:README` explicitly calls wrong. All of them now use `Now` / `Next` / `Decision` with the marks the reader actually reads. The check above is what keeps the third generation from appearing.

Smaller, same theme: `docs/CONFIGURATION.md` is no longer cited from inside commands (it does not ship with the plugin — they point at `FLOW.md` and the bundled template instead); `TaskCreate`, `ScheduleWakeup` and `Monitor` name their fallback for harnesses that lack them; a Stripe-specific skill and "load the project skills" became stack-agnostic; `feat:ship §6.2` had a paragraph wedged between two bullets of the same list; `design`, `investigate` and `status` pointed at section numbers and an artifact filename that had moved; `bug:review` reports the quality gates it runs; the domain-memory timeout sentence reads the same in all 22 commands; reinstalling an adapter now removes the commands upstream deleted, and `install.sh` says so when Codex ignores a `project` scope it has no directory for.

Docs caught up with all of it: the plugin README no longer advertises a `review` config section that never existed or four git hosts flow does not support, the root README has the bug flow in its real order and the fifth hard gate it had been omitting, and the release procedure — until now only in the maintainer's head — is written down in **`RELEASING.md`**, together with every convention the preflight enforces and why.

Mirrored across the opencode, Gemini CLI and Codex adapters.

## v0.34.0 — The plugin was handing out models it did not own  ·  2026-08-18

**In short**
- New `models` section in `FLOW.md`: `study`, `code`, `test`, `review`, `workers`; empty = the model you launched with.
- For steps the main agent runs itself, a differing configured model is reported in one line, never enforced.
- A named `agents.<role>` agent keeps its own model; the keys apply to improvised agents and fan-out workers.
- `/flow:config` prints the resolved model map; `/flow:init` writes the section empty and does not ask about it.
- The hardcoded opus/sonnet lines in `/flow:work:README` and `/flow:feat:review §3.5` are removed.

Two lines in this plugin picked models for you. A bullet in `/flow:work:README` split the work between "opus" and "sonnet" by judgment level, and `/flow:feat:review §3.5` launched its completeness critic with "(opus model — this is judgment, not tracking)". Both were wrong in the same three ways. **No command applied them** — not one `Agent` call in twenty commands ever passed a model, so the bullet described a policy that existed only in prose. **The names are not portable**: the same commands run on Codex, Gemini CLI and opencode, where `opus` means nothing, so a plugin that ships one vendor's tiers is lying to three of the four harnesses it claims to support. And **it is not the plugin's call**: which model is good at what changes every few months, differs per account and per budget, and belongs to whoever pays for the tokens.

**`models` in `FLOW.md`, five keys, by what a step does.** `study` (start, brainstorm, design, plan, diagnose, investigate, postmortem) · `code` (build, fix, green) · `test` (validate) · `review` (review, query, respond triage) · `workers` (the parallel fan-out rounds only, so breadth can be made cheap without touching the rest). Every key is empty by default and **empty means the step runs with the model you launched the command with** — a repo that ignores the section behaves exactly as it did before it existed. The values are free text passed straight to the harness: flow does not validate a model name, does not rank models, and never picks one.

**Two limits, stated instead of glossed over.** An agent **cannot switch its own model**, so for the steps the main agent performs itself — reading the ticket, designing, and writing the code (`build`/`fix` are single-thread on XS/S/M by design) — a configured value is *reported, not enforced*: when it differs from the running model, the phase handoff says so in one line with the command that fixes it, records it in the artifact, and **continues**. Making that a gate was the tempting version and the wrong one: a stop at every phase boundary demanding a `/model` is individually defensible and collectively turns an unattended run back into an attended one, which is the exact degradation the never-ask list in the phase preamble exists to prevent. And a **named agent keeps its own model** — when `agents.<role>` points at a real agent, that agent's own definition decides, because a setting must not be overridden from two places; the keys apply where flow *improvises* the agent and to the fan-out workers.

**Which model runs where is read, not inferred.** The keys are named by kind of step, and which step falls under which key lives inside the commands — so `/flow:config` now prints the resolved map: key, value, the commands it covers, a mark on the two whose steps the main agent performs itself, and who decided each one. `/flow:init` writes the section empty and does **not** ask about it unless you bring up models first.

Mirrored across the opencode, Gemini CLI and Codex adapters, where all three declare a subagent's model in the subagent's own definition rather than at the call site — each adapter's `PRIMITIVES.md` now says where, and says plainly that the conductor's own model is beyond reach there too.

## v0.33.0 — Ten lines about a class nobody had opened  ·  2026-08-18

**In short**
- Stop bodies are a one- or two-line headline plus two to five one-idea bullets; ~10 lines is a ceiling, not a target.
- Stops describe what changed for the software's user; a class or error code appears only when a decision needs it.
- Mechanics go to the phase artifact; a technical question still gets a full technical answer.
- Both rules live in the shared Reporting preamble, inherited by all 18 phase commands and the adapters.

v0.26.0 gave every stop a header: ticket, size, phase, `MR #n of N`, the plan state, one line of what just finished, one line of what is needed from you. That fixed the **order** of a report — you no longer had to read to the end to find out where you were. It did not fix the other two things that make a stop unreadable to the person it is written for.

**The ten-line limit turned out to be a ceiling, not a shape.** "At most ~10 lines of body" is satisfied perfectly by ten lines of paragraph, and ten lines of paragraph are still a wall of text — subordinate clauses, a "for context" opening, a recap of what the previous stop already said. Nothing in the contract asked for short lines, so nothing produced them. The body is now a headline of one or two lines and then two to five bullets, one idea each, and the limit is stated as a ceiling rather than a target.

**And nothing in it asked for the right altitude.** The only rule about wording was `Zero-context`, which says that when a class or method appears it carries four to six words of what it is. That rule assumes the identifier belongs there. Usually it does not. When the agent is the one writing the code, the human on the other side of the stop is doing product — deciding what the software should do, for whom, and what it must not break — not archaeology on a diff they have not read. Ten lines about `AttachmentUploader` are a report about the agent's afternoon; *"attachments over 25 MB no longer break the send — they upload separately and the mail carries a link"* is a report about their software. So the body now speaks in the language of what changed for whoever uses this thing, and a class, file or error code earns a line only when the user has to **decide** about it, asked something technical, or named it first. The mechanics are not lost — they go where they were always more useful, the phase artifact.

**What this is not.** It is not a licence to answer shallowly. The two rules govern the report the flow writes *unprompted*, at a stop; a technical question still gets a technical answer, at whatever length the subject needs.

Both rules sit in the shared **Reporting** preamble, so all 18 phase commands inherit them, and mirrored in the opencode, Gemini CLI and Codex adapters.

## v0.32.0 — The query passed every gate; nobody read its plan  ·  2026-08-18

**In short**
- New `/flow:work:query`: states the query's facts, runs a blinded challenger over twelve failures, judges by numbers.
- Verdicts are `ok` / `change` / `schema-follow-up` / `unresolved`.
- `feat:review` §3.6 and `bug:review` §3.5 run the duel for any query change, at any size including XS.
- `feat:design` gains an Access paths table; `build`, `validate` and `bug:investigate` record or measure plans.
- `work:respond` gets thread category `G`; new optional `data` section in `FLOW.md` (`explain_cmd`, `volumes`, …).

A query shipped through `design`, `build` and a full `review` panel, and not one of those gates ever looked at an execution plan. A human reviewer did, in a comment: *"why is the limit in the code and not in the query?"*. The flow answered from theory — the bound is per key, a global `LIMIT` cannot express that, the ORM's query language has no window function — which was all true and all beside the point. When someone finally built a data set and ran `EXPLAIN`, the cost was somewhere else entirely: two tables joined on columns with **different character sets**, so the join could not use an index and the engine scanned 63,000 rows to return fifteen. 449 ms. The same defect was already sitting in a neighbouring query that had been in production for a year, and the shape that finally won was the one the flow had dismissed as obviously worse — one small indexed query per key.

Three separate failures, and none of them is a reviewer being careless.

**A query's cost is invisible to reading.** Correctness is in the code; cost is in the plan, and the plan depends on facts that appear nowhere in the diff — which index exists, in what column order and **direction**, the type and collation of both sides of a join, how many rows a key really has. A mixed-direction `ORDER BY` (`a ASC, b DESC`) over a single-direction index does not half-use it: it sorts the whole result set. Join keys with different collations lose the index entirely. Both are invisible to tests too — same rows, same assertions, green suite, collapsed plan. So no amount of reviewer attention finds them, and a plausible sentence in the design makes the reviewer stop looking sooner.

**New: `/flow:work:query`, the query duel.** A standalone, repeatable command that puts one query on trial. It states the facts first (call site and frequency, filter, order with direction, bound and whether it is per key or global, both sides of every join with their real types and collations, heavy columns, rows per key **and where that number came from**, and the indexes that actually exist — read from the schema, never the ORM mapping). Then a challenger **blinded to the design's rationale** attacks it over twelve classic failures, each attack required to name the data scenario that triggers it. Then the main agent judges, under three rules: **no number, no win** (an unresolved point is recorded unresolved, never split in prose), **no dogma in either direction** ("N small queries is an N+1" and "one batched query always wins" are both preferences until measured), and **the objector's variant gets measured next to yours** — especially when your theory says it will lose. Verdicts are `ok` / `change` / `schema-follow-up` / `unresolved`, and the last one is a real verdict, not a failure to produce one.

**Wired into the phases that let it through.** `feat:review` §3.6 and `bug:review` §3.5 run the duel whenever the diff adds or changes a query, at **any size, XS included** — it is not a depth tier but a category no other reviewer owns, and a one-line change to an `ORDER BY` is exactly the change whose cost is invisible. `feat:design` gains an **Access paths** table (filter, order with direction, bound, rows per key, and the index that supports it) so a missing index is a decision taken when adding one is still cheap. `feat:build` records the plan as the query is written. `feat:validate` measures against real volumes, because a green suite proves rows and never plans. `bug:investigate` treats slowness as a plan problem until proven otherwise — and notes that several of its causes leave the code untouched, where `git blame` cannot find them.

**`work:respond` gets a new thread category, `G`, and one rule.** A performance objection is answered with a plan, never with reasoning. A reasoned reply that has not looked at one is the most expensive answer the flow can produce: it sounds authoritative, so it costs the reviewer a round trip to disprove; it is grounded in the design's own rationale, so it feels verified when nothing was. The reviewer's variant is measured beside yours, a defect that predates the MR/PR is declared and ticketed rather than used to bless or widen the diff, and the reply leads with **one** recommendation and the number behind it — a reply that agrees and then hedges in three directions reads as "I don't know" and makes the reviewer decide twice.

**New optional `data` section in `FLOW.md`**: `explain_cmd`, `schema_cmd`, `sandbox_cmd`, `seed_cmd`, `volumes`. All empty by default — the duel still runs on the schema alone and **says** what it could not prove. `volumes` is the cheapest key of the five and worth filling even with the commands empty: an adversarial reviewer with no volumes invents them. Creating or seeding a database is a hard gate in every autonomy mode, never against production. And the corollary the flow now states out loud: the functional test database, with its handful of fixture rows, proves nothing about a plan — "not measured" is a legitimate verdict, a plan measured there reported as evidence is not.

Mirrored in the opencode, Gemini CLI and Codex adapters.

## v0.31.0 — 36 agents on a 69-line MR, in a dialect only one harness spoke  ·  2026-08-07

**In short**
- The `Workflow` DSL scripts are removed from the commands; fan-out rounds are described in prose for every harness.
- New `agents.fanout_max` (empty → 4) caps any parallel round; a truncated sweep reports its coverage (`4/7`).
- Review verification runs only for M/L with >150 changed lines and ≥4 ambiguous findings, with one skeptic.
- The brainstorm panel is proportional: advisors for M, cross-critique only for L; synthesis returns to the main agent.
- `agents.fanout_tool: Workflow` opts back into Claude Code's tool; an unavailable tool falls back to subagents.

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

**In short**
- `script/check.py` resolves its symlink and uses `git rev-parse --show-toplevel` to find the repo root.
- Installed as a pre-commit hook it now checks files instead of exiting green with nothing to check.
- No changes to any command.

v0.30.2 added `script/check.py` and told you to wire it in with `ln -s ../../script/check.py .git/hooks/pre-commit`. Doing exactly that produced `not a git checkout — nothing to check` and a green exit on every commit.

Reached through the symlink, `abspath(__file__)` resolves inside `.git/hooks`, so the script took `.git` for the repo root and ran `git ls-files` against a directory git does not track. Empty list, nothing to check, exit 0 — a hook that guards nothing while looking like it does, which is worse than no hook, because the previous release's own instructions installed it.

It now resolves the symlink and asks `git rev-parse --show-toplevel` where the tree actually starts, falling back to the script's own parent outside a checkout. Verified through all three entry points: as the installed hook, from another working directory, and with a defect reintroduced to confirm it still fails.

No changes to any command.

## v0.30.2 — A tree that would not load can now say so before the tag does  ·  2026-08-07

**In short**
- New `script/check.py` refuses empty tracked files and a manifest that fails to parse or lacks `name`/`version`.
- Fails when the manifest version disagrees with the newest `CHANGELOG.md` heading.
- Checks command frontmatter, `.toml` files, embedded `json` examples, and `panel.json` marks/styles the reader knows.
- Fails when a plugin command is missing from any of the three adapters.
- No changes to any command.

v0.30.1 restored a manifest that had been empty for two releases. This adds the check that would have caught it, plus the ones that would catch its neighbours.

There is no CI in this repo and a release is a tag on whatever is in the tree, so `script/check.py` is what stands between a broken tree and a permanent tag. It refuses: an **empty tracked file** (the actual failure — nothing else reads the manifest, so every other check passed while the plugin could not start), a manifest that does not parse or has no `name`/`version`, a **manifest version that disagrees with the newest `CHANGELOG.md` heading** (`/flow:news` reads one and the loader reads the other; when they drift the release notes describe a version nobody is running), a command without frontmatter, a `.toml` that does not parse, an embedded `json` example that does not parse, a `panel.json` example using a `mark`, `style` or inline URL **the reader would not understand**, and a plugin command **missing from any of the three adapters**.

The last two are worth their place because neither breaks anything loudly. An unknown `mark` is not an error in the panel — the line quietly loses its symbol and its column and renders as plain text — and adapter parity is maintained by hand, one file at a time, so the failure mode is a command that silently stops being mirrored rather than one that breaks.

Each check was verified by reintroducing the defect it targets and confirming it fails, which is how the first two versions of the embedded-json check turned out to be worthless: one skipped every block containing an ellipsis (which is all of the panel examples) and the next choked on blocks that quote a single field of a larger object.

No changes to any command — `/flow:*` behaviour is exactly v0.30.0's.

## v0.30.1 — The manifest was truncated to zero bytes  ·  2026-08-06

**In short**
- `plugins/flow/.claude-plugin/plugin.json`, empty since v0.29.1, is restored so the plugin loads again.
- Cause: a one-line Python version bump that truncated the file before reading it.
- No content changes; `/flow:*` behaviour is exactly v0.30.0's.

`plugins/flow/.claude-plugin/plugin.json` shipped **empty** in v0.29.1 and stayed empty through v0.30.0, so Claude Code could not load the plugin at all: no manifest, no commands.

The cause was a scripted version bump written as `open(p, "w").write(open(p).read().replace(...))`. Python opens the file for writing — truncating it — before it evaluates the argument that reads it, so the read returned the empty file it had just created. The v0.29.0 bump had done the same edit in two statements and was fine; the one-liner that replaced it was not. Nothing flagged it: the file is not read by any command, only by the loader, and v0.30.0's diff did not list it because by then it was already empty.

Restored from v0.29.0 and versioned 0.30.1. No content changes — `/flow:*` behaviour is exactly v0.30.0's.

## v0.30.0 — The line says what it *is*; the panel decides how to draw it  ·  2026-08-06

**In short**
- `panel.json` lines carry a `mark` (`done`, `current`, `pending`, `wait`, `block`, `info`) instead of a state column.
- `ref` accepts labels like `Now`/`Next`/`Decision`; column widths are computed per blank-line-separated block.
- `link` is a field the panel shortens and pins; flow no longer writes raw URLs on their own line.
- New `stale_after_minutes`; `/flow:work:watch` sets it to about twice its cycle interval.
- The v0.29.1 "~55 characters per line" rule is removed.

The reader gained a vocabulary, and writing against it turns out to be both simpler and more honest than the columns flow was hand-building in v0.29.1.

**`mark` replaces the state column.** Each line declares what it is — `done` · `current` · `pending` · `wait` (shipped or asked, now waiting on someone else) · `block` · `info` — and the panel picks the symbol and the colour. That kills the last place where flow was making a presentation decision it had no business making, and it fixes the v0.29.1 compromise honestly: an open MR/PR is `wait`, not "done" and not "in progress", which is exactly what it is in a train.

**`ref` need not be a number.** `#1` and `#3–#6`, but equally `Now`, `Next`, `Decision` — the panel aligns them into a column either way, so the labels below the train get the same treatment as the train. Widths are computed **per block**, and blocks are separated by blank lines, so the two groups no longer drag each other wide. Blank lines are now load-bearing.

**`link` is a field, not text.** The panel shortens the URL to `!9977 ↗`, makes it clickable and pins it right, or hangs it underneath when it does not fit. flow no longer writes a raw 60-character URL on its own indented line, which is what the v0.29.0 layout did.

**`stale_after_minutes`** raises the 30-minute staleness threshold for a stretch known to run long. `/flow:work:watch` sets it to about twice its cycle interval: the default would let a dead monitoring loop pass for a live one through five missed cycles, and a watcher that has stopped watching is precisely what has to be visible.

**One correction to v0.29.1.** The "keep every line under ~55 characters" rule was written from a misread screenshot: the reader *does* align a wrapped line's continuation under its text. Length is now a matter of saying less, not of measuring columns — the rule is gone.

## v0.29.1 — The header said `build` while the body said "validating"  ·  2026-08-06

**In short**
- `panel.json` carries its own `phase` (the phase running now); the reader prefers it over `meta.json`.
- The `Done` / `Now` / `Left` train headings are gone; each entry shows its real state, unstarted ones collapse.
- Each panel line is kept short enough not to wrap (~55 characters).
- The panel is written in the language of the work's artifacts.

First run of the panel against a real work, three fixes it earned in the first ten minutes.

**The header was a phase behind.** `meta.json.phase` only advances when a phase *closes*, so a reader drawing the phase from it shows `build` for as long as `validate` takes — with the panel body, one line below, saying "validating". `panel.json` now carries its own **`phase`**: the phase being executed right now. The reader prefers it when present and falls back to `meta.json` when absent, so it costs older works nothing.

**"Done  #1 …  MR open" contradicted itself.** Grouping the train under `Done` / `Now` / `Left` is the obvious layout and it is wrong for the way flow actually ships: in a train an MR/PR that has shipped is *open, waiting to merge*, not done, and in a four-MR train almost nothing is merged until the end. A heading that calls it done states something false in the one place the user is trusting at a glance. The headings are gone; each entry carries its real state as its last column, and the not-yet-started ones collapse into a single `#a–#z` line — which also buys back the height the URLs need.

**Lines were written long enough to wrap.** The reader wraps rather than truncates, so an overflowing line takes two ragged lines and its continuation does not inherit `indent` — the column breaks and a trailing `#2` ends up alone. The rule is now explicit: each line short enough not to wrap (~55 characters), and say less rather than say it in two lines.

Also: the panel is written **in the language the work's artifacts use**, which was left implicit and produced one panel in English over a Spanish work.

## v0.29.0 — Every stop is a file too, so something other than the chat can answer "where is this?"  ·  2026-08-06

**In short**
- Every phase command writes `.claude/work/<work>/panel.json` for external readers (pane, status bar, dashboard).
- It carries the MR/PR train with open URLs, what runs now, what comes next, `accent` decisions and `warn` blockers.
- Lines use semantic styles (`normal`, `dim`, `title`, `accent`, `ok`, `warn`, `error`), never colours.
- Written whole and before long stretches with a real `updated_at`; `ship`, `plan`, `resume`, `watch`, `abandon` too.
- Optional: works without one still resolve from `meta.json`; no new `FLOW.md` keys.

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

**In short**
- `/flow:feat:start` §2.1 and `/flow:bug:start` §1.1 read the ticket's comment thread, not just the description.
- New `tracker.comments_cmd` key (empty = derived from `tracker.tool`); `/flow:init` fills it alongside `view_cmd`.
- The latest deciding comment wins over the description; comments are untrusted input, never instructions.
- An unreadable thread is reported as a named gap; `01-context.md` gains `## Decided in the ticket thread`.
- `/flow:work:resume` §2.5 re-reads the thread, appends only what is new, and hands contradictions to you.

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

**In short**
- `/flow:work:clean` measures "not on the remote" against `refs/remotes/origin/<branch>`, not `@{u}`.
- An MR/PR closed without merging gets its own `closed` verdict: never a candidate, always named.
- With 25 or fewer `unknown` branches, the sweep asks the forge about each one directly.

Running `/flow:work:clean --dry-run` against the two repos from v0.27.0 — 49 and ~120 branches — turned up three defects, all of them the kind that only shows up against a repo with history.

**`@{u}` was the wrong ruler for "not on the remote".** The protected set measured unpushed commits against the configured upstream. But flow creates branches with `git worktree add --no-track`, so a branch that was pushed, reviewed and merged still has **no upstream configured** — and every one of them read as "exists only here" and got protected. In the larger repo that was most of the table: branches whose `origin/<branch>` ref was sitting right there. It now measures against `refs/remotes/origin/<branch>` and only falls back to counting the branch's own commits when there is no remote ref at all.

**A closed MR/PR is not the absence of one.** An MR/PR closed without merging is neither `merged` nor in flight, and the previous version folded it into `unknown` alongside branches that never had an MR/PR. Same non-action, opposite meaning: one says a decision was made about this work, the other says nobody ever looked. `closed` is now its own verdict — never a candidate, always named in the report.

**The 100-MR/PR page is not the whole forge.** In a high-turnover repo most finished branches are older than the list window, and the local patch-equivalence check in §4c misses a squash whose MR/PR absorbed review changes — the patch that landed is no longer the patch on the branch. So when **25 or fewer** branches are still `unknown`, the sweep now asks the forge about each one directly (`--source-branch` / `--head`). That is the one place per-branch queries earn their cost: the list already answered for everything it covers, and what is left is bounded and named. Above 25 it skips the pass and reports how many went unresolved.

## v0.27.0 — The flow sweeps up after itself, and "merged" is a verdict rather than a guess  ·  2026-08-05

**In short**
- New `/flow:work:clean`: joins worktrees, local branches and `.claude/work/` folders and decides each from evidence.
- Two forge calls (merged, open); squash merges are detected locally with `git commit-tree` + `git cherry`.
- `unknown` is never a candidate; dirty worktrees, unpushed branches and the remote are protected; no `--force`.
- Work folders are archived, never deleted; `--purge-archive <N>d` removes only git-committed archives; `--dry-run`.
- `status` §4, `daily` §4 and `feat:ship` surface the residue count; adapter indexes regain `/flow:work:green`.

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

**In short**
- `guided`/`auto` never ask about flow mechanics, WIP commits, train chaining, size, or already-settled decisions.
- `plan` §6 and `design` §9 approval prompts are now conditioned on the autonomy mode.
- New shared Reporting preamble: every stop opens with ticket, size, phase, `MR #n of N`, plan state; ~10-line body.
- `plan` §6 prints waves as `Wave 1: #1 ∥ #2 → Wave 2: #3`; `work:resume` gains `MR/PRs:` and `Waves:` lines.
- The business brief and `ship` still stop in `auto`; no new `FLOW.md` keys.

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

**In short**
- Every `## Close` ends with an autonomy handoff: `manual` proposes the next command, `guided`/`auto` chain into it.
- `validate`, `bug:review` (XS/S) and `bug:postmortem` never chain into `ship`; nothing chains past a red gate.
- `build` §2.2 / `fix` §2.1: `auto` commits WIP itself, `guided` asks once, `manual` asks per step.
- `work:green` and `work:respond` commit the round in `guided`/`auto` and go straight to the push gate.
- The business brief and all of `ship` still stop in `auto`; no new `FLOW.md` keys.

### An unattended mode that stopped at every phase boundary was never unattended
The report: with `autonomy.mode: auto`, a build ended with *"nothing committed — the 5 files are in the working tree for you to validate first. When you want: commit and `/flow:feat:review`"*. Two stops in one sentence, in the mode whose whole promise is *"chaining phases without pausing"*. Nothing in the plugin had changed — both instructions were months old. What changed is which one wins when a prompt contradicts itself, and the flow contradicted itself in two places.

**A named next command is not a handoff.** The autonomy preamble, repeated at the top of all twelve phase commands, promised that `guided`/`auto` "chain into the recommended next command automatically". But only `feat:start` and `bug:start` said so in their closing section; the other ten closed with *"and next command: `/flow:feat:review`"* and nothing else. A closing line that merely **names** the next command is a specific instruction to stop, and a specific instruction beats a general preamble. So `auto` stalled at every phase boundary while claiming to chain. Every `## Close` now ends with an explicit **autonomy handoff**: `manual` stops and proposes the next command as a one-click confirmation (never leaving you to type it); `guided`/`auto` chain into it **in the same turn**. The exceptions are stated where they apply rather than left to inference — `validate`, `bug:review` (XS/S) and `bug:postmortem` never chain into `ship`, because pushing and opening the MR/PR is a hard gate in every mode, and nothing chains downstream of a red gate (blockers in review, red tests or unproven criteria in validate, unresolved `high` findings in design).

**Choosing `auto` *is* the commit authorization.** `build` §2.2 and `fix` §2.1 carried a *hard rule* with no exception per mode: the agent never commits on its own and **waits** for you at every step. Against `auto` that is not a preference, it is a contradiction — and it is the one the system rule (*never commit unless the user explicitly asks*) reinforces, so it won every time. The rule is now gated by the mode, with the authorization made explicit instead of assumed: `manual` — you decide per step, nothing is committed without your word; `guided` — asked **once** at the first step, then applied for the rest; `auto` — the agent commits each step's WIP and keeps going, because **setting `autonomy.mode: auto` and typing the command is the explicit ask**. Same reasoning that already made the commits in `ship` authorized (it is the command's stated purpose) and the `Workflow` fan-out opt-in valid (typing the command is the authorization). It covers **only** WIP commits on the work branch — push and MR/PR creation stay hard gates in every mode. `work:green` and `work:respond` follow suit: in `guided`/`auto` they commit the round and go straight to the push gate, instead of asking twice for the same round.

**What deliberately still stops in `auto`.** The **business brief** before any code is written (`build` §2, `fix` §2) — it is the last point where the scope can be corrected before there is a diff to argue with, and scope creep is invisible in code review once mixed into everything else. And all of `ship`. An `auto` run now goes from `start` to a validated branch without intervention, and ends where it always should have: asking whether to publish.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. No new `FLOW.md` keys — this is `autonomy.mode` finally doing what it already documented.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.24.0...v0.25.0

## v0.24.0 — The contract crosses to the other repo, and green means a count  ·  2026-07-29

**In short**
- `/flow:feat:ship` §6.3 publishes literal contracts for a `Known consumer` to the ticket, previewed in every mode.
- `/flow:feat:start` §3.6 picks a published contract up into `01-context.md`; `design` carries it verbatim.
- New `contract_handoff` per `meta.json.related_repos` entry (`none` / `pending` / `published → <location>`).
- `build` §4 judges test runs by executed count and names, not exit code; zero or missing tests is a failure.
- `build` §2.1 requires a reason for borrowed code; `design` §8 requires an evidence line before `stage_finding`.

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

**In short**
- `review` §3 and `validate` §2 performance triggers cover any repeated call leaving the process, not only the DB.
- Reviewers are asked what each failed iteration sets off downstream (publishes, enqueues, disables, logs).
- A settled decision is reviewer context, never a "do not report X" veto; same in `bug:review`, `respond`, `green`.
- `review` §2.1 launches the panel as defined and records ran vs defined (`N/M`) in `06-review.md`.

### A full flow, a green suite, and a human reviewer still found four things
The case that motivated this release: the whole flow ran on a read-time endpoint that called an external API **inside a loop** over up to 100 items, with a per-item `catch` that returned `null`. Suite green, static analysis clean, MR opened. A human reviewer then found four problems — three of them hanging off that same loop. Every failed iteration published a message to a queue *and* emitted an event that enqueued one job per item downstream; 100 sequential external calls in a synchronous request had no cap; and the generic `catch` swallowed all of it. Three fixes, none of which invents a new phase.

**Performance stopped meaning "database".** The reinforcement trigger in `review` §3 was literally *"DB / heavy queries"*, and `validate` §2's brief was a closed list of persistence patterns (N+1, indexes, unbounded queries, flush in a loop). A change that touches no database fell outside that vocabulary entirely. Both now cover **any repeated call that leaves the process** — external API, HTTP, cache, filesystem — and, more importantly, ask what **each failed iteration sets off downstream**: what it publishes, enqueues, disables or logs, and whether N failures multiply it. The cost of the happy path was never the whole question. Same widening in `design`'s performance pass, `bug:review` §3, and the `performance` role in `FLOW.template.md`.

**A decision already taken is context for the reviewer, never a scope exclusion.** §2.2 already warned against inheriting `03-design.md`'s rationalizations — but only for the artifact handed to reviewers. Nothing stopped the *conductor* from turning a design decision into a veto inside the agent's own prompt ("this cost is accepted, don't report it, look for something else"), which is the same pathology through the other door — and it silently excludes everything hanging off the vetoed topic. §2.2 now covers the briefs you write: *"X is decided — tell me what consequences it has that we have not seen"*, never *"do not report X"*. The rule reaches every place that briefs a reviewer — `bug:review` §2.1, `work:respond` §6.1, `work:green` §5 — and it is deliberately narrow: don't fence the reviewer off, not doubt everything.

**A panel that runs at 2-of-6 says so in the artifact.** `quality.review_skill` / `quality.reviewers` define a roster whose members own whole categories that the rest of the flow explicitly does not revisit — so a skipped reviewer is a category with no owner at all. `Agents launched:` was free text and never asked what *should* have run. §2.1 now says to launch the panel **as defined** — whole roster, no hand-picked subset, no substitutions — and the output field asks for **ran vs defined** (`N/M`, naming who did not run and why, and any substitution). A partial panel is now visible in `06-review.md`, before the MR/PR opens.

Mirrored across the opencode / Codex CLI / Gemini CLI adapters. **No new FLOW.md keys**, no new phase, no extra agent.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.22.0...v0.23.0

## v0.22.0 — `/flow:work:green` means *mergeable*, not just a green pipeline  ·  2026-07-27

**In short**
- `/flow:work:green` reads the forge's merge verdict (§2.1) as well as the pipeline (§2.2), every round.
- `UNKNOWN`/`checking` mergeability is re-queried, never reported as "no conflicts".
- New triage category C (conflict / behind base): `git merge` the base, resolve on the merits, regenerate artifacts.
- New triage category H (human blocker): drafts, approvals and threads are named and routed, never worked around.
- Integrating the base is a hard gate in every mode; `daily` flags unmergeable MR/PRs; `respond` nudges to `green`.

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

**In short**
- New optional `tracker` keys: `start_cmd`, `done_cmd`, `abandon_cmd`, `assignee` (empty = nothing runs).
- `start_cmd` runs on `feat:start`/`bug:start`; `done_cmd` when `phase` reaches `done`; `abandon_cmd` on `work:abandon`.
- Transitions are best-effort and idempotent: ask in `manual`, run in `guided`/`auto`, warn and continue on failure.
- `/flow:config` flags a redundant `done_cmd` on GitHub/GitLab; `/flow:init` offers Jira/Linear defaults.

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

**In short**
- Ticket-mode work folders are named `<TICKET>-<slug>` (e.g. `MT-1234-fix-login-validation`).
- `meta.json` gains a `slug` field; `meta.json.ticket` stays the pure identifier.
- Older `<TICKET>` folders keep working; `watch`, `status` and `abandon` glob/match instead of assuming the path.
- `status` shows the title next to the ticket.

### `.claude/work/MT-1234/` told you nothing when you had five of them open
In ticket mode the work folder was named just `<TICKET>` (`MT-1234`), so with several works in flight at once you couldn't tell which was which without opening each `meta.json`. Ticket-less works already had a readable slug; ticket mode didn't.

Now the folder is named `<TICKET>-<slug>` (e.g. `MT-1234-fix-login-validation`), reusing the **same** slug already derived for the branch — so branch and folder read alike. `meta.json` gains a `slug` field, and `meta.json.ticket` stays the **pure identifier** that feeds the tracker view, the issue link and `{TICKET}` in the branch — the id is never polluted with the slug.

- **`/flow:feat:start` & `/flow:bug:start`** — derive the slug once and name the directory `<TICKET>-<slug>` (ticket mode) or `<slug>` (ticket-less local-only). The "already exists" check globs both `<TICKET>/` and `<TICKET>-*/`.
- **Backwards compatible** — works created before this are still named `<TICKET>` and keep working: every other command locates a work by matching `meta.json.branch`/`ticket`, not by the folder name. `/flow:work:watch`, `/flow:work:status` and `/flow:work:abandon` were adjusted to glob/match instead of assuming the exact `<TICKET>` path, and `status` now shows the title next to the ticket.

Docs/command-logic only — no new FLOW.md keys, still stack-agnostic. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.19.0...v0.20.0

## v0.19.0 — cross-repo scope: flow stops forgetting the other project  ·  2026-07-22

**In short**
- New `related_repos` field in `meta.json` (`repo`, `scope`, `status`: `pending` / `in_progress` / `done`).
- `feat:start` and `bug:start` ask once about cross-repo scope when signals point to another repo; silent otherwise.
- `feat:design` and `feat:plan` refine the list; in ticket-less mode the affected repos go into the issue body.
- `feat:ship`, `bug:ship`, `daily`, `resume` and `status` remind about non-`done` entries.

### The other repo fell off the map
flow is **per-repo**: the `.claude/work/<TICKET>/` lives in the repo where you start. But plenty of tasks span two projects (a backend change plus its consumer, an API plus its client). Since the debate and the ticket usually start in one repo, the slice that belongs to the *other* repo was recorded **nowhere** — you'd `ship` the first part and the second was silently forgotten. `/flow:work:daily` (v0.17) was per-repo too, so it couldn't catch it either.

New `related_repos` field in `meta.json` (`[{ "repo", "scope", "status": "pending"|"in_progress"|"done" }]`), woven through the flow:

- **Capture** — `/flow:feat:start` and `/flow:bug:start` add a **Cross-repo scope** step: if signals point to another repo (the ticket names it, the conversation settles it), they ask once and record it. **Silent by default** — no signal, no question. `/flow:feat:design` and `/flow:feat:plan` refine the list when the design reveals a repo the conversation missed (a plan slice that lands in another repo goes to `related_repos`, not to this repo's `mrs`).
- **Recorded in the ticket too** — in **ticket-less** mode, when flow drafts and creates the issue, the *repos affected* go in the issue body, so the multi-repo scope lives in the tracker for the whole team, not only in the local `meta.json`.
- **Remind** — `/flow:feat:ship` and `/flow:bug:ship` call out any non-`done` entry after creating the MR/PR ("the `<repo>` part still needs `<scope>` → start the work there"). `/flow:work:daily`, `/flow:work:resume` and `/flow:work:status` surface them.

flow **only notes and reminds** — it never scans or touches the sibling repo (that would break the per-repo model). No new FLOW.md keys. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.18.0...v0.19.0

## v0.18.0 — `FLOW.md` is personal config: gitignore it, don't commit it  ·  2026-07-22

**In short**
- `FLOW.md` is now documented as personal config, not team config.
- `/flow:init` offers to add `FLOW.md` to `.gitignore` when it is not already ignored.
- `FLOW.template.md` header and README say the same; committing a subset by hand remains possible.

### "Team config, not secrets" was only half right
`FLOW.md` was documented as committable team config. But it mixes three different natures: **repo facts** (tracker, quality commands, conventions — genuinely shared), **your machine's environment** (`domain_memory.enabled`, which `agents.*` exist on *your* box, worktree paths), and **your flow tastes** (`autonomy.mode`, `assignee`, `review_depth`, per-command `notes`). Committing it as-is imposes one developer's preferences on everyone who clones and assumes their machine has the same tools installed — the same `FLOW.md` on another box can point at agents or an MCP that isn't there.

So `FLOW.md` is now treated as **personal config, not team config**:

- `/flow:init` no longer says "can be committed". It explains the file is personal, holds **no secrets**, and — if `FLOW.md` isn't already git-ignored — **offers to add it to `.gitignore`** (a confirmed edit, since it touches a tracked file).
- The `FLOW.template.md` header and the README say the same, and point you to gitignore it.
- Escape hatch preserved: a team that deliberately wants to share the repo-fact subset can still commit it by hand.

Documentation + `/flow:init` behavior only — no command logic or FLOW.md keys changed. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.17.1...v0.18.0

## v0.17.1 — `/flow:work:daily` stops nagging about threads you already answered  ·  2026-07-22

**In short**
- `/flow:work:daily` flags a review thread only when the latest comment is not yours.
- Threads you already answered move to an informational **Awaiting others** line, never to *Blockers*.
- Threads are fetched per open MR/PR (`glab api …/discussions` · `gh api`) and compared against `git.assignee`.

### The signal was "unresolved", and it should have been "awaiting *you*"
The first cut of `/flow:work:daily` flagged every **unresolved** review thread as *"go respond"*. But on both GitLab and GitHub a thread stays unresolved until the **reviewer** closes it — and `/flow:work:respond` **never resolves threads** by design (that call is the reviewer's). So a thread you already answered stays unresolved forever, and the daily kept telling you to respond to MRs you'd already handled. Real report from the field: `!9707` was fully answered, yet the briefing still put it under *"respond today"*.

The forge layer now keys off the right signal — **whose comment is last**:

- **Threads whose latest comment is *not* yours** (someone left you something unanswered) → the real `/flow:work:respond` signal, fetched per open MR/PR (`glab api …/discussions` · `gh api` review threads) and compared against `git.assignee` / `@me`.
- **Threads you already answered** (unresolved, but the last word is yours — waiting on the reviewer) → moved to a separate **Awaiting others** line, **informational only**, never in *Blockers*. *Blockers* is now strictly what **you** must act on.

No new FLOW.md keys; a `patch`. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.17.0...v0.17.1

## v0.17.0 — `/flow:work:daily` — your work assistant (the Scrum-style standup)  ·  2026-07-22

**In short**
- New `/flow:work:daily [question]`: read-only briefing from `.claude/work/`, the forge and the tracker.
- No argument → yesterday · today · blockers plus suggested next commands; a question → answers just that.
- Crosses sources into suggested commands: unstarted ticket → `feat:start`, red CI → `green`, threads → `respond`.
- External sources are best-effort and degrade with a one-line note; marker in `~/.claude/flow/daily-last-seen`.

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

**In short**
- `/flow:work:respond` §6 runs the same review ladder as `/flow:feat:review`, scoped to the round's diff.
- Trivial rounds keep the single `code-review` pass; non-trivial rounds run the depth ladder, YAGNI, idiom, contract.
- The §5.5 idiom audit always runs when a round adds architectural pieces; §7 local gates run as well.
- Lightweight mode (no `03-design.md`) skips §5 and judges YAGNI against the code itself.

### Closing the quality gap in the review loop
`/flow:work:respond` implements code changes agreed in an MR/PR review round, but its quality gate was a **single** built-in `code-review` (or `review_skill`) pass — a fraction of what `/flow:feat:review` runs. So the exact place where a wrong primitive or an over-engineered mechanism slips in under pressure ("just extract it to a class to answer the comment") had the **weakest** gate in the whole flow, and the result went straight into an MR/PR already under human eyes — producing the *next* round of comments instead of closing the thread. The risk was inverted: highest-risk edits, flimsiest check.

`respond §6` now runs the **same ladder as `/flow:feat:review`**, scoped to the round's diff:

- **Trivial rounds** (nitpicks only, no new classes/wiring) keep the single `code-review` pass — no added latency.
- **Non-trivial rounds** run the review machinery scoped to the round: the **§2.0 depth ladder** (effort by size + sensitive-surface bump, panel when selected), the **§4 over-engineering / YAGNI audit**, the **§5.5 idiom / primitive audit (blind to the design's rationale)** — the two that catch exactly this loop's failure mode, with §5.5 **always** running when the round introduces new architectural pieces regardless of size — the **§5 contract check**, and the **§7 local gates** (`style_fix` / `static_analysis` / `test_one`).
- **Lightweight mode** (no `03-design.md`) degrades cleanly: §5 is skipped, §4 judges YAGNI against the code itself, and §5.5 runs unchanged (it needs no artifact). A blocker fix that reopens the debated approach loops back to §4 to re-agree the stance before editing again, instead of silently re-patching.

**No new FLOW.md keys** — it reuses the `quality.*` and `agents` keys the flow already needs. Mirrored across the opencode / Codex CLI / Gemini CLI adapters.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.15.0...v0.16.0

## v0.15.0 — `/flow:work:green` — the CI-green loop between ship and merge  ·  2026-07-20

**In short**
- New `/flow:work:green [mr-iid-or-url]`: fetches the failing pipeline jobs and logs via `git.cli`.
- Triages each job (lint · test · type/build · flaky/infra · quality gate) and fixes at the root, reproducing locally.
- Never green-washes: no blind reruns, no disabled checks; hard gates on every push and rerun; logs to `09-ci.md`.
- `respond` nudges you to run `green` first when CI is red.
- Code-writing commands add comments only for a non-obvious why; ticket IDs and MR numbers never go in comments.

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

**In short**
- Each `mrs[]` entry carries its own `phases_done`; `build`, `review` and `validate` record into the current entry.
- `/flow:feat:ship` §1 gates on the current MR/PR's own `phases_done` when the work has several MR/PRs.
- `/flow:feat:plan` seeds every entry with `phases_done: []`; hot-cuts in `build` §2.3 do the same.
- Single-MR/PR works and the whole bug flow are unaffected.

### The ship gate is now per-MR/PR, not per-work
`/flow:feat:ship` refused to publish unless `review` (and, above `XS`, `validate`) had run — but it checked the **work-level** `phases_done`, a single list per ticket. In a multi-MR/PR feature that list accumulates and never resets, so once the **first** MR/PR completed review/validate the gate passed **for free** on every later MR/PR. A train MR/PR could ship unreviewed just because an earlier sibling had been reviewed — precisely the shortcut the flow exists to prevent, and it bit exactly on the MR/PR that carried a defect.

Now each `mrs[]` entry carries its **own** `phases_done`:

- `/flow:feat:build`, `/flow:feat:review` and `/flow:feat:validate` record `build`/`review`/`validate` into the **current `in_progress` MR/PR's** entry, and their pre-flights require the previous phase on **that** entry.
- `/flow:feat:ship §1` gates on the current MR/PR's own `phases_done` when the work has more than one MR/PR — a sibling's review no longer satisfies it.
- `/flow:feat:plan` seeds every entry with `phases_done: []`; a hot-cut in `/flow:feat:build §2.3` inserts the new entry the same way.

Single-MR/PR works (all `XS`/`S`, and the whole `bug` flow) are unaffected — they keep using the work-level list.

**Full changelog**: https://github.com/mashware/flow-workflows/compare/v0.13.0...v0.14.0

## v0.13.0 — ticket-less start + `/flow:news`  ·  2026-07-17

**In short**
- `feat:start` and `bug:start` take an optional argument; with none they draft the work from the conversation.
- The draft can create the real tracker issue (always asks); otherwise the work proceeds local-only with a slug.
- New `/flow:news` prints changelog entries since your last version (`vX.Y.Z`, `N`, `all`); marker in `~/.claude/flow/`.
- New SessionStart hook `notify-update.sh` nudges once after a plugin version change.
- `plugin.json` gains `homepage`/`repository`; `CHANGELOG.md` ships with the plugin.

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

**In short**
- `feat/review.md` and `bug/review.md` §2.0 use the full ladder `low < medium < high < xhigh < max`.
- Base by size: XS `medium`, S `high`, M `high`, L `xhigh`; `full` mode bumps `high → xhigh`.
- Sensitive surfaces raise one tier and force the panel: S/M sensitive at `xhigh`, L sensitive at `max`.
- The review output records the effort used; adapters phrase it as the maximum thoroughness the tool supports.

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

**In short**
- New `/flow:work:respond [mr-iid-or-url]`: fetches open review threads via `gh`/`glab`.
- Triages each thread (question · nitpick · change request · design debate · out-of-scope · obsolete) and debates it.
- Implements agreed changes with `build`/`fix` mechanics; hard gates on every post and push; never resolves a thread.
- Repeatable per review round, logged to `08-feedback.md`; no new `FLOW.md` keys.

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

**In short**
- `/feat:plan` numbers steps in topological wave order, so `n` is execution order.
- MR/PR bodies never emit the plan's `#n` (no more `#5 (closed)` auto-links).
- `/feat:review` §5.5 adds a blind idiom/primitive audit; reviewers are de-anchored from design rationale.

topological wave numbering in `/feat:plan` (`n` is execution order, no more "start at #5"); never emit the plan's `#n` in MR/PR bodies (kills the `#5 (closed)` auto-link); blind idiom/primitive audit in `/feat:review` §5.5 + de-anchoring of reviewers from design rationale. Merged via #11.

## v0.9.0 — manual-mode one-click handoff + autonomy for codex/gemini  ·  2026-07-08

**In short**
- Manual mode hands off each step as a one-click confirmation.
- Autonomy modes ported to the codex and gemini adapters.
- Merged via #10.

manual-mode one-click step handoff; autonomy ported to codex/gemini adapters. Merged via #10.

## v0.8.0 — the `flow` prefix  ·  2026-07-06

**In short**
- Every command lives under the `flow` prefix: `/flow:feat:start`, `/flow-feat-start` (opencode/Codex), Gemini nested.
- 67 adapter command files renamed; cross-references, README tables, `install.sh`, `PRIMITIVES.md`, `AGENTS.md` updated.
- 188 internal cross-references in the plugin normalized to `/flow:*`.
- Breaking for adapter users: `/feat-start` and `/feat:start` no longer exist.

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

**In short**
- GitLab issues are a selectable tracker (`tracker.tool: glab`), alongside Jira, GitHub issues and Linear.
- `/flow:init` offers trackers without preselecting and auto-fills `tracker.view_cmd`, warning if the CLI is absent.
- `FLOW.template.md` documents per-tool `view_cmd` examples.

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

