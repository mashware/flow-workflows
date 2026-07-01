---
description: Guide to the /feat and /bug workflow system
---

# `/feat:*` and `/bug:*` workflow system

This system **orchestrates** the sub-agents and skills that already exist in the project (it does not replace them). Its job is to persist context across phases, prevent each step from starting from scratch, and enforce a code-review gate before closing.

## Per-repo configuration: `FLOW.md`

Place a `FLOW.md` file at the repo root to adapt the plugin to your conventions. It defines the ticket tracker, branch and MR/PR conventions, quality commands, code conventions, the domain-memory MCP, and the observability profile. All commands read this file in their step 0.

You can start from the template at [`examples/FLOW.template.md`](../../examples/FLOW.template.md).

If the file does not exist or a key is empty, each command auto-discovers the value or falls back to the default behavior described in its corresponding section.

## Principles

- **One folder per ticket**: `.claude/work/{TICKET}/` holds `meta.json` and the markdown artifacts.
- **Numbered artifacts**: each phase writes a `NN-phase.md` that the next step reads.
- **`meta.json` is the source of truth** for state (current phase, size, branch). Without it, commands refuse to continue.
- **Size drives the flow**: `/feat:start` and `/bug:start` classify the work as XS/S/M/L and suggest skipping phases for small changes.
- **Branch with explicit base and no upstream pointing to the base**: an accidental deploy was once caused by creating a branch carelessly, so `/feat:start` §5 and `/bug:start` §4 enforce two rules. (1) **Explicit base**: never `git checkout -b` from "wherever I am" — the base is `git.default_base` from FLOW.md (normal case) or a confirmed parent branch (stacked mode, noted in `meta.json.stacked_on`). If the current branch is not the base, ask with `AskUserQuestion` before creating. (2) **`--no-track` required**: with `branch.autoSetupMerge=true`, creating from the base without `--no-track` leaves the upstream pointing at the remote base; a push that resolves the upstream lands on the base and may trigger a deploy. The first push is always `git push -u origin HEAD` (own branch), and `/feat:ship` §4.0 / `/bug:ship` §4.0 block if HEAD is the base branch or the upstream points to it.
- **Small, focused, loosely coupled MR/PRs**: the default goal is to close the feature in the smallest possible MR/PRs, each with a clear purpose and independently mergeable when possible. Coupling between MR/PRs only when unavoidable; document the reason in `04-mr-plan.md` and note the merge order. A huge MR/PR "because it can't be split" is a sign that `/feat:plan` was not thought through — return to that phase before continuing.
- **Understand before starting**: if after reading the ticket, `domain-memory`, and the code there are open questions that affect the design (what cases it covers, what happens with certain roles/plans, what it does if user X, what metric/event counts as "success"), **ask the user** before closing `/feat:start` or `/feat:brainstorm`. Inventing answers the user would later have to correct is worse than asking. Ask everything at once (`AskUserQuestion` with all doubts), not one by one.
- **Reuse before creating**: in `/feat:design`, before proposing new entities, columns, repositories, services, or events, verify whether something equivalent already exists in the affected module or neighboring ones. Every new piece in `03-design.md` implicitly means "I found nothing that fits." If duplication is intentional, justify it (unwanted coupling, different semantics). This does NOT mean forcing reuse of something that fits poorly — it means not adding out of habit.
- **Solve the real project problem, not the generic one (fit + YAGNI)**: before adding any defensive mechanism (validation, guard, retry, lock, fallback, cache, idempotency, queue, flag), answer **two questions with evidence**:
  - **(a) Does it fit? Can this scenario actually happen given how this project works?** Evidence comes from `domain-memory` and the code, **not** from generic textbook patterns or "it could happen that…". If the current system already prevents that scenario (an upstream validates first, a constraint blocks it, the flow does not allow that state), the protection is **unnecessary**.
  - **(b) Do we need it now, for what the ticket asks?** If it solves a hypothetical future problem instead of today's, **don't add it** (YAGNI). Future ideas go as "idea for a separate ticket", not as built code.

  The default design bias is **remove, not add**. A protection without a concrete, present scenario behind it is over-engineering. This is operationally anchored in the `/feat:design` challenger (angle "Fit and need", which looks for what's excessive) and in the defensive mechanisms table of `03-design.md`.
- **Size is revisable**: the XS/S/M/L classification is made in `/feat:start` or `/bug:start` with partial information. Any subsequent phase (`brainstorm`, `design`, `plan`, `diagnose`, `investigate`) that sees a clear mismatch should **propose reclassifying to the user** before proceeding, and update `meta.json.size`. Carrying a wrong size contaminates subsequent phases (wrong skips, unnecessary MR/PR plans, unneeded postmortems).
- **If the implementation invalidates the design, return to design**: during `/feat:build` it's normal to discover new things. If the accumulated deviations in `05-implementation.md` are 2+ significant ones, or a single one that changes a decision from the design's ADR-light, **pause the build and return to `/feat:design`** to update the document before continuing. The reason: the design is the source read by `/feat:review` and `/feat:validate` — if it lies, everything that follows is based on something false. The same applies to `/bug:fix` when the actual fix diverges from what was noted in `/bug:investigate`.
- **Challenge the design/investigation before executing**: at the end of `/feat:design` and `/bug:investigate`, launch a *challenger* (a `general-purpose` sub-agent with a sharpened prompt). Its **first and dominant** angle is **"Fit and need"** — it looks for what is **excessive**: protections against scenarios that cannot happen in this project, and YAGNI pieces that solve hypothetical future problems (this angle counteracts the natural tendency to add too many defenses). The other angles (fragile assumptions, simplification, production operation) look for what's missing. The result is noted in the artifact itself under "Challenges". **High-severity** findings without a response — both "this is missing" and "this is excessive" — block advancing to closure; the user decides whether to reopen, trim, or accept and document.
- **Business brief before writing code**: just before starting to edit files (in `/feat:build` and `/bug:fix`), write 3-5 bullets **in business language** (not technical) explaining what the user/system will be able to do after this task, and what is **NOT** included. Ask for confirmation with `AskUserQuestion` before the first commit. This filters two things: invented features the design did not ask for, and scope creep while "we're already here." If something outside the brief comes up during implementation, confirm before adding it — never "while we're at it, let's also…".
- **The MR/PR communicates functionality, not implementation**: the MR/PR title and description (in `/feat:ship` and `/bug:ship`) start from the **Brief** in the corresponding artifact, not from the technical design. A reviewer or product manager should be able to read the header and understand what changes for the user without opening the diff. Technical details go in an **optional section at the end** ("Technical details for reviewers"), not at the top. Title: descriptive in behavioral language, not internal implementation jargon.
- **Mandatory MR/PR preview before creating**: in `/feat:ship` and `/bug:ship`, before invoking creation, show the user the full block (title + assignee + squash + description exactly as it will appear) and ask for confirmation with `AskUserQuestion`. **No exceptions, even when the content seems obvious**. Options: create, edit (show the preview again after changes), or cancel. Nothing is published until explicit confirmation — this prevents generic titles/descriptions when the underlying skill decides not to ask. The assignee, squash, and sections are read from `git.assignee`, `git.squash`, and `git.request_sections` in FLOW.md; if empty, use the default values from FLOW.template.md.
- **Anchoring to design contracts (anti-self-deception)**: the same agent that designs usually builds next — and in that transition the contract declared in `03-design.md` dissolves under the "gravity field" of repo patterns. To prevent this, three anchor points:
  1. **`/feat:design` §"External contracts"**: any surface consumed from outside (HTTP body, header, route, event, column, metric) is declared as a **literal shape**, not in prose. If the contract breaks the repo's usual pattern, mark it "Pattern deviation" explicitly.
  2. **`/feat:build` §2.0bis**: before writing code, **copy verbatim** the "External contracts" section from the design into `05-implementation.md`. This keeps the contract in the file being written, not in another file no longer being looked at. And §4.2: when closing build, a deliberate key-by-key textual comparison between what the code produces and the cited contract — not a test, a deliberate agent comparison.
  3. **`/feat:review` §5**: a sub-agent **deliberately blinded** that receives only the literal contracts + the diff hunks that touch shape construction. Without the rest of the design or full code context, it cannot rationalize mismatches — it only compares textually and reports.

  Known limitations: if the contract is copied incorrectly (typo when transcribing) or was declared wrong in the design (not what the real consumer expects), the system faithfully confirms the broken version. The package reduces the case to those two categories, it does not eliminate them.
- **Commits are user opt-in**: during `/feat:build` and `/bug:fix`, the agent **does not run `git commit` on its own**. After each `TaskCreate` step, it edits the files and reports a summary (files, lines, validation suggestion). Wait for you to decide: commit now, wait to validate locally first (test the UI, run the flow, read the diff), or continue without committing. This breaks the previous pattern of automatic WIP commits per step. User control is preferred: if you validate and commit periodically, there are still cuttable units in `/feat:build` §2.3; if you prefer not to commit until the end, accept that you lose that granularity. The system rule *"NEVER commit changes unless the user explicitly asks you to"* takes precedence — commits in `/feat:ship` and `/bug:ship` count as explicitly authorized because that is the stated purpose of the command.
- **Code review is mandatory**: `/feat:ship` is not run and `/bug:postmortem` is not closed without passing through `/*:review`.
- **Existing sub-agents**: commands invoke the agents and skills available in the project for design, API construction, testing, performance analysis, etc. Work is not duplicated — it is delegated to what already exists.
- **Deliberate model tiering (opus vs sonnet)**: the split is by judgment level, not by where each file ended up. **opus** → the conductor (main agent: reads, asks, synthesizes, writes artifacts), design agents when they *design*, the generalist challenger, and the **synthesis/convergence** phases of fan-out Workflows. **sonnet** → bounded expert or mechanical work (code-review skill reviewers, testing agents, API builders, frontend, etc.) and the **parallel workers** of Workflows (perspective panel, hypothesis sweep, verification skeptics). The `quality.review_skill` skill from FLOW.md (or the built-in `code-review` if empty) determines which agents run in review and with which model; those details belong to that skill.
- **Parallel multi-agent fan-out (optional, only where it pays)**: three phases offer launching the `Workflow` tool (deterministic parallel orchestration), **conditioned on `size` M/L + user confirmation** — never forced, never on XS/S. (1) `/feat:brainstorm` §3.A: perspective panel, one agent per lens (minimal / reuse / operations / rethink) + synthesis. (2) `/bug:investigate` §3.A: hypothesis sweep, one agent per root cause looking for evidence both **for and against** + convergence. (3) `/feat:review` §6 and `/bug:review` §5: adversarial verification of findings (3 skeptics per finding, refute-by-default, survives if <2 refute it) to eliminate false positives. The remaining phases (build, plan, start, diagnose, validate) **do not** use fan-out: editing files, slicing MR/PRs, or running tests is sequential work where parallelizing only adds cost. A slash command instructing a call to `Workflow` is valid opt-in by design — typing the command is the authorization.
- **`domain-memory` (full cycle)**: if `domain_memory.enabled` is `true` in FLOW.md, the `domain-memory` MCP is used at four points throughout the flow. If the MCP does not respond within 2s or fails at any point, continue without context and do not mention it to the user. If `enabled` is `false` or absent, skip all domain-memory steps silently.
  - **`search_knowledge`** when entering new territory: `/feat:start` and `/bug:start` (ticket keywords), `/feat:brainstorm` (concept/pattern), `/feat:design` (module + integrations), `/bug:diagnose` (affected component), `/bug:investigate` (hypothetical cause). Searching at ticket start is not enough — the context needed in `/feat:design` is different from what was needed in `/feat:start`.
  - **`stage_finding`** during the process: when closing `/feat:design` and `/bug:investigate`, if non-obvious domain decisions emerged (legal constraints, integrations with surprising behavior, model assumptions hard to infer from code), offer to stage them. Silence by default — only when there is a clear signal. Staging is per-branch and accumulates until save.
  - **`read_staging`** before saving: `/feat:ship` and `/bug:postmortem` read what has been staged for that branch before proposing the final save. Avoids duplication and helps decide what to consolidate.
  - **`save_knowledge`** at close: `/feat:ship` and `/bug:postmortem` offer to consolidate. Only the "why" is saved (decisions, constraints, motivations); the "what" (code, paths) lives in the repo.

## `meta.json` schema

```json
{
  "ticket": "{PREFIX}XXXXX",
  "type": "feat" | "bug",
  "title": "Ticket title or short description",
  "branch": "{PREFIX}XXXXX-slug",
  "size": "XS" | "S" | "M" | "L",
  "phase": "context" | "brainstorm" | "design" | "plan" | "build" | "review" | "validate" | "ship" | "diagnose" | "investigate" | "fix" | "postmortem" | "done" | "abandoned",
  "phases_done": ["context", ...],
  "mrs": [
    {
      "n": 1,
      "title": "…",
      "size": "S",
      "status": "pending" | "in_progress" | "merged" | "closed" | "superseded",
      "lines_est": 120,
      "files_est": 6,
      "url": "https://...",
      "note": "reason if closed/superseded; empty otherwise"
    }
  ],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "free-form field the user can edit"
}
```

The ticket format follows `tracker.prefix` from FLOW.md; if empty, the ticket is free-form.

## Shortcuts by size

| Size | Features                                                                  | Bugs                                                            |
|------|---------------------------------------------------------------------------|-----------------------------------------------------------------|
| XS   | start → build → review → ship                                             | start → fix → review → ship                                     |
| S    | start → design (abridged) → build → review → validate → ship              | start → diagnose → fix → review → validate → ship               |
| M    | start → brainstorm → design → **plan** → build → review → validate → ship | full flow                                                       |
| L    | full flow (includes **plan**)                                             | full flow                                                       |

`/feat:plan` is skipped on XS/S (always 1 MR/PR). On M/L it is mandatory and populates the `mrs` array in `meta.json`.

## Full `/feat:*` flow

`/feat:start {TICKET}` → `/feat:brainstorm` → `/feat:design` → `/feat:plan` → `/feat:build` → `/feat:review` → `/feat:validate` → `/feat:ship`

For M/L with multiple MR/PRs, the `build → review → validate → ship` block repeats for each MR/PR in the plan. `meta.json.mrs` tracks the state.

## Full `/bug:*` flow

`/bug:start {TICKET}` → `/bug:diagnose` → `/bug:investigate` → `/bug:fix` → `/bug:validate` → `/bug:review` → `/bug:postmortem` → `/bug:ship` (alias)

## Cross-cutting commands

- `/work:status` — shows all works in `.claude/work/`, current phase, and divergence with git.
- `/work:resume` — detects the current branch, reads `meta.json`, recaps, and suggests the next step.
- `/work:try <branch>` / `/work:try --back` — point the main checkout at a branch to test it against this checkout's environment, then return; re-syncs per `git.worktree_resync` in FLOW.md. Generic (no project Makefile needed); complements worktrees.
- `/flow:config` — show the effective FLOW.md config (set vs empty-with-fallback) and validate it. Read-only.
- `/work:watch {TICKET} [30m]` — autopiloted post-deploy monitoring: observes the observability platform (per FLOW.md `observability`) scoped to the change, comparing against a baseline (preceding window + same weekday of the prior week, ratios over counts), and alerts immediately on any regression. External state polling via `ScheduleWakeup`; does not touch code or production.

## Golden rules

1. **Never skip `review`.** If the previous phase is not in `phases_done`, the command refuses.
2. **If you edit code outside the flow**, `/work:status` will flag the divergence.
3. **Artifacts are hand-editable**. If you rewrite `03-design.md`, the next step will respect it.
4. **`domain-memory` is optional but recommended** when closing large features or postmortems (requires `domain_memory.enabled: true` in FLOW.md).
