# Changelog

All notable changes to the **flow** plugin, newest first. This file is bundled with the
plugin and is what `/flow:news` reads to show you what changed since your previous version.

The canonical, richest notes live in the [GitHub Releases](https://github.com/mashware/flow-workflows/releases).

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

