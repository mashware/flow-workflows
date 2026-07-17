# Changelog

All notable changes to the **flow** plugin, newest first. This file is bundled with the
plugin and is what `/flow:news` reads to show you what changed since your previous version.

The canonical, richest notes live in the [GitHub Releases](https://github.com/mashware/flow-workflows/releases).

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

