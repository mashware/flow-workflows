# Changelog

All notable changes to the **flow** plugin, newest first. This file is bundled with the
plugin and is what `/flow:news` reads to show you what changed since your previous version.

The canonical, richest notes live in the [GitHub Releases](https://github.com/mashware/flow-workflows/releases).

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

