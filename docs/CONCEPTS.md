# Concepts

The terms the flow uses, grouped, each with where it is specified. Command paths are relative to
`plugins/flow/commands/`; [flow-core][fc] is the shared skill; [work/README][wr] the internal guide.

## The work and its files

**Work** — one unit of tracked work: a ticket (or a ticket-less slug), a branch, and a folder under
`.claude/work/<TICKET>-<slug>/` holding state and artifacts. Created by `feat/start.md` or
`bug/start.md`; closed by `ship` once merged, or by `work/abandon.md`. → [work/README §Principles][wrp]

**Phase** — one step of a chain (`start`, `design`, `build`, `review`…). Each gates the next: a command
refuses to run if the previous phase is not in `meta.json.phases_done`. Each writes its own artifact.
→ [work/README §Full flow][wrf]

**Artifact** — the numbered markdown file a phase leaves behind (`01-context.md`, `03-design.md`…).
Hand-editable: rewrite one and the next phase respects it. Process narration goes there, never into
the chat. → [README §On disk](../README.md#what-a-work-looks-like-on-disk)

**`meta.json`** — the work's source of truth: ticket, type, size, branch, `phase`, `phases_done`, the
MR/PR train (`mrs[]`), related repos, `reviewed_sha` / `validated_sha`, `respond_rounds`. Without it,
commands refuse to continue. Advances only when a phase closes. → [work/README][wrm]

**`00-summary.md`** — a handoff of at most 15 lines, overwritten whole at every phase close: what the
work is, size and current MR/PR, decisions that stand, contracts, what is pending, what to open in full.
Every phase reads `meta.json` and this file first; a full artifact only when needed. → [flow-core §5][fc]

**`panel.json`** — the work's live state for a reader outside the chat (a pane, a status bar). Each
line says what it *is* (`mark`, `ref`, `link`), not how to draw it. Overwritten whole, written *before*
long stretches with an honest `updated_at`, carrying the phase actually running. → [work/README][wrpj]

**Size (XS/S/M/L) and pruning** — classified at `start`, revisable later. Size prunes phases: XS runs
`start → build → review → ship`; S adds an abridged design and validate; M/L run the full chain with
`plan`. Size never decides whether something is a work at all ([PHILOSOPHY](PHILOSOPHY.md#when-not-to-use-it)). → [work/README][wrs]

**Ticket-less work** — `/flow:feat:start` with no arguments drafts the work from the conversation you
just had (title, summary, criteria, closed decisions) for you to confirm; a slug replaces the ticket id.
→ [CONFIGURATION][cnt]

## Autonomy and stops

**Autonomy mode (`manual` / `guided` / `auto`)** — `autonomy.mode` in `FLOW.md`. `manual` stops at
every decision and proposes the next command. `guided` resolves low-risk decisions, records them, asks
at the real ones, chains phases. `auto` also resolves the rest with recorded defaults and never pauses.
→ [CONFIGURATION §autonomy][ca]

**Hard gate** — a stop that holds in every mode, `auto` included: any push or MR/PR creation, a branch
on an ambiguous base, a DB schema change or migration, shipping a review with high-severity findings,
the business brief before code. `respond`, `green`, `query`, `clean` add their own. → [flow-core §2][fc]

**"Never a question" list** — the symmetric rule: what `guided`/`auto` decide, record and move past.
Flow mechanics (panels, challengers, skeptics, how many), WIP commits, continuing a train when
`train_chain` is `always`, size confirmation, anything already recorded. Asking these is how an
unattended run degrades into a manual one. → [flow-core §2][fc]

**Stop header** — the fixed lines every stop opens with: `<TICKET> · <size> · phase · MR #n of N`, the
plan state from `meta.json.mrs`, what just finished, what is needed from you. Then at most ~10 lines
of body, in product language. A question is always an `AskUserQuestion`, never prose. → [flow-core §3][fc]

## Branches and MR/PRs

**Train (stacked MR/PRs) and waves** — on M/L work, `plan` splits the feature into small MR/PRs, each
stacked on the previous branch; `build → review → validate → ship` repeats per MR/PR. Numbering is
the execution order; a **wave** groups the ones that can run in parallel. The train never waits for a
merge; `git.train_chain` decides what `ship` does when MR/PRs remain. → `feat/plan.md`, [CONFIGURATION][ctr]

**Worktree** — with `git.worktree: ask|always`, `start` creates the branch as a git worktree (default
`.worktrees/{branch}`) instead of switching your checkout. `/flow:work:try` points the main checkout at
a branch and re-syncs per `git.worktree_resync`; `/flow:work:clean` sweeps merged ones. → [CONFIGURATION][cwt]

**Green loop vs Respond loop** — the two loops between `ship` and merge. **Green** handles the machine
(red pipeline, conflicts, behind base): triage, fix at the root, push; never green-washes. **Respond**
handles the humans (review threads): triage, debate from the recorded rationale, implement, reply;
never resolves a thread. → [WORKFLOWS](WORKFLOWS.md#after-ship-before-merge)

**Cross-repo handoff** — a task touching a sibling repo is recorded in `meta.json.related_repos` and
reminded at `ship`. When the sibling consumes a contract declared here, `ship` offers to publish the
literal shape as a **ticket comment**; the sibling's `start` reads it as received. Flow never touches
the other repo. → [WORKFLOWS §Cross-repo](WORKFLOWS.md#cross-repo-tasks)

## Design and review

**Contract (declared / received, verbatim)** — any surface consumed from outside (HTTP body, header,
route, event, column, metric), written in `03-design.md` §"External contracts" as a **literal shape**.
`build` copies it verbatim before writing code; `review` sends a blinded subagent to compare it against
the diff. A contract **received** from a sibling is copied verbatim as not negotiable. A paraphrased
contract is a *new* contract. → [work/README §Principles][wrp], `feat/build.md` §2.0bis

**Review depth (`light` / `proportional` / `full`)** — `quality.review_depth`. `light`: only the base
code-review at medium effort — no panel, reinforcements or skeptics. `proportional` (default): the
panel scales by size and risk; a sensitive surface (auth, secrets, payments, personal data, public API
shape, schema) raises effort and forces the full panel. `full`: everything at xhigh. → [CONFIGURATION][cd]

**Reinforcements** — specialist agents `review` launches in parallel on top of the panel when the diff
touches their area (`agents.performance`, `queues`, `security`, `frontend`…), covering only what the
base review does not. Used only if `FLOW.md` names them; skipped under `light`. → `feat/review.md` §3

**Skeptic fan-out** — the verification gate at the end of `review`: one skeptic subagent per *ambiguous*
finding, told to refute it with the burden of proof on the finding; refuted findings are listed as
discarded, with the reason. Opens only on M/L, a diff over 150 lines and at least 4 ambiguous
findings; capped by `agents.fanout_max`; never under `light`. → `feat/review.md` §6, [CONFIGURATION][cf]

**Query duel** — a data-access query judged on its execution plan, not on prose: a fact sheet (filter,
order with direction, bound, joins, real indexes), a challenger blinded to the design's rationale, and
a verdict by the main agent with numbers — measured when the schema cannot settle it. Runs as
`/flow:work:query`, inside `review` when the diff touches a query, and when a reviewer objects in
`respond`. → [WORKFLOWS §Query duel](WORKFLOWS.md#query-duel--flowworkquery), [CONFIGURATION §data][cda]

## Configuration and plumbing

**FLOW.md** — the per-repo configuration file: `tracker`, `git`, `autonomy`, `quality`, `agents`,
`models`, `data`, `conventions`, `notes`, `domain_memory`, `observability`. Every command reads it
first; empty keys auto-detect or use the stated default. Generated by `/flow:init`, inspected by
`/flow:config`, checked against the machine by `/flow:doctor`. → [CONFIGURATION](CONFIGURATION.md)

**domain-memory** — an optional MCP that stores the *why* of a codebase. With `domain_memory.enabled:
true` the flow searches it on entering new territory, stages findings at `design` and `investigate`,
and offers to save at `ship` and `postmortem`. If it fails, the flow continues without it, silently.
→ [CONFIGURATION §domain_memory][cdm]

**flow-core skill** — the rules every `/flow` command relies on, stated once and loaded once per
session: `FLOW.md`, model keys, autonomy and hard gates, the never-a-question list, the stop header,
`panel.json`, the `00-summary.md` handoff. A command file carries only its phase. → [flow-core][fc]

**Adapter** — a mirror of the plugin's commands for another harness (opencode, Gemini CLI, Codex CLI),
generated by `script/adapter-build.py`. Only the wrapper changes: command format, invocation prefix,
subagent and MCP declaration. Checked by `script/adapter-smoke.py`; not executed end to end in those
harnesses. → [adapters/README](../adapters/README.md)

[fc]: ../plugins/flow/skills/flow-core/SKILL.md
[wr]: ../plugins/flow/commands/work/README.md
[wrp]: ../plugins/flow/commands/work/README.md#principles
[wrf]: ../plugins/flow/commands/work/README.md#full-flowfeat-flow
[wrm]: ../plugins/flow/commands/work/README.md#metajson-schema
[wrpj]: ../plugins/flow/commands/work/README.md#paneljson-schema
[wrs]: ../plugins/flow/commands/work/README.md#shortcuts-by-size
[ca]: CONFIGURATION.md#autonomy
[cnt]: CONFIGURATION.md#working-without-a-tracker
[ctr]: CONFIGURATION.md#multi-pr-trains-train_chain
[cwt]: CONFIGURATION.md#worktrees-and-flowworktry
[cd]: CONFIGURATION.md#how-much-review-runs-review_depth
[cf]: CONFIGURATION.md#how-wide-the-fan-out-goes-fanout_max
[cda]: CONFIGURATION.md#data
[cdm]: CONFIGURATION.md#domain_memory
