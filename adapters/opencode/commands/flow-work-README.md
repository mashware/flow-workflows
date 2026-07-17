---
description: Guide to the /flow-feat-* and /flow-bug-* flow system
---

# `/flow-feat-*` and `/flow-bug-*` flow system

This system **orchestrates** the sub-agents and skills that already exist in the project (it does not replace them). Its job is to persist context between phases, prevent each step from starting from scratch, and enforce a mandatory code review before closing.

## Per-repo configuration: `FLOW.md`

Place a `FLOW.md` file at the repo root to adapt the plugin to your conventions. Define the ticket tracker, branch and MR/PR conventions, quality commands, coding conventions, the domain-memory MCP, and the observability profile. All commands read this file in their step 0.

You can start from the template at `flow/examples/FLOW.template.md`.

If the file does not exist or a key is empty, each command auto-discovers the value or falls back to the default behavior described in its corresponding section.

## Principles

- **One folder per ticket**: `.claude/work/{TICKET}/` contains `meta.json` and the markdown artifacts.
- **Numbered artifacts**: each phase writes a `NN-phase.md` that the next step reads.
- **`meta.json` is the source of truth** for state (current phase, size, branch). Without it, commands refuse to proceed.
- **Size drives the flow**: in `/flow-feat-start` and `/flow-bug-start` the work is classified XS/S/M/L and skipping phases is suggested for small changes.
- **Branch with explicit base and no upstream pointing to the base**: creating a branch once caused an accidental deployment, so `/flow-feat-start` §5 and `/flow-bug-start` §4 enforce two rules. (1) **Explicit base**: never `git checkout -b` from "wherever I am" — the base is `git.default_base` from FLOW.md (normal case) or a confirmed parent branch (train mode, noted in `meta.json.stacked_on`). If the current branch is not the base, confirm the base before creating. (2) **`--no-track` required**: with `branch.autoSetupMerge=true`, creating from the base without `--no-track` leaves the upstream on the remote base; a push that resolves the upstream ends up on the base and can trigger a deployment. The first push is always `git push -u origin HEAD` (own branch), and `/flow-feat-ship` §4.0 / `/flow-bug-ship` §3.0 block if HEAD is the base branch or the upstream points to it.
- **Small, focused, loosely coupled MR/PRs**: the default goal is to close the feature in the smallest possible MR/PRs, each with a clear purpose, independently mergeable when possible. Coupling between MR/PRs only when unavoidable; when it is, justify it in `04-mr-plan.md` and record the merge order. A huge MR/PR "because it can't be split" signals that `/flow-feat-plan` was not thought through — go back to that phase before continuing.
- **Understand before starting**: if after reading the ticket, `domain-memory`, and the code there are still open questions that affect the design (which cases it covers, what happens with certain roles/plans, what it does if user X, which metric/event counts as "success"), **ask the user** before closing `/flow-feat-start` or `/flow-feat-brainstorm`. Making up answers that the user will have to correct later is worse than asking upfront. Ask all at once, not one by one.
- **Reuse before creating**: in `/flow-feat-design`, before proposing new entities, columns, repositories, services, or events, verify whether something equivalent already exists in the affected module or neighboring modules. Every new piece in `03-design.md` implicitly means "I found nothing that works." If duplicating knowingly, justify it.
- **Solve the project's real problem, not the generic one (fit + YAGNI)**: before adding any defensive mechanism (validation, guard, retry, lock, fallback, cache, idempotency, queue, feature flag), answer **two questions with evidence**:
  - **(a) Does it fit? Can this scenario actually occur given how this project works?** Evidence comes from `domain-memory` and the code, **not** from generic book patterns or "it could happen that…". If the current system already prevents that scenario, the protection **is unnecessary**.
  - **(b) Do we need it now, for what the ticket asks?** If it solves a hypothetical future problem instead of today's, **don't add it** (YAGNI). Future ideas are noted as "idea for a separate ticket", not built.

  The default bias in design is to **remove, not add**.
- **Size is revisable**: the XS/S/M/L classification is made in `/flow-feat-start` or `/flow-bug-start` with partial information. Any later phase that sees a clear mismatch should **propose reclassification to the user** before proceeding, and update `meta.json.size`.
- **If implementation invalidates the design, go back to design**: during `/flow-feat-build` it is normal to discover new things. If the accumulated deviations in `05-implementation.md` are 2+ significant ones, or one that changes a decision in the design's ADR-light, **pause the build and go back to `/flow-feat-design`** to update the document before continuing.
- **Challenge design/investigation before executing**: at the end of `/flow-feat-design` and `/flow-bug-investigate`, launch a *challenger* (a general-purpose sub-agent with a sharp prompt). Its **first and dominant** angle is **"Fit and necessity"** — it looks for what **can be removed**. The other angles (fragile assumptions, simplification, production operation) look for what is missing. The result is noted in the artifact itself under "Challenges". **High-severity** findings without a response block progress; the user decides whether to reopen, cut scope, or accept and document.
- **Business brief before writing code**: just before starting to edit files (in `/flow-feat-build` and `/flow-bug-fix`), write 3-5 bullets **in business language** (not technical) explaining what the user/system will be able to do after this task, and what is **NOT** included. Ask for confirmation before the first commit.
- **MR/PR communicates functionality, not implementation**: the MR/PR title and description (in `/flow-feat-ship` and `/flow-bug-ship`) come from the **Brief** of the corresponding artifact, not from the technical design. Technical details go in a collapsed section at the end.
- **Mandatory MR/PR preview before creating**: in `/flow-feat-ship` and `/flow-bug-ship`, before invoking creation, print the full block to the user and ask for confirmation. **No exceptions, even when the content seems obvious.**
- **Anchoring to design contracts**: (1) `/flow-feat-design` §"External contracts": external surfaces as literal shape. (2) `/flow-feat-build` §2.0bis: copy verbatim before typing. (3) `/flow-feat-review` §5: a deliberately biased sub-agent that only compares shape.
- **Commits are user opt-in**: during `/flow-feat-build` and `/flow-bug-fix`, the agent **does not run `git commit` on its own**. After each step, edit the files and report a summary. Wait for the user to decide.
- **Mandatory code review**: `/flow-feat-ship` cannot proceed nor can `/flow-bug-postmortem` be closed without going through the corresponding review command.
- **Existing sub-agents**: the commands invoke the sub-agents and skills available in the project for design, API building, testing, performance analysis, etc. Work is not duplicated — it is delegated to what already exists.
- **Parallel multi-agent fan-out (optional, only where it pays)**: three phases offer launching sub-agents in parallel, **conditional on `size` M/L + user confirmation** — never forced, never on XS/S. (1) `/flow-feat-brainstorm` §3.A: approach panel. (2) `/flow-bug-investigate` §3.A: hypothesis sweep. (3) `/flow-feat-review` §6 and `/flow-bug-review` §5: adversarial verification of findings.
- **`domain-memory` (full cycle)**: if `domain_memory.enabled` is `true` in FLOW.md, the `domain-memory` MCP is used at four moments throughout the flow. If at any point the MCP does not respond within 2 s or fails, continue without context and do not mention it to the user. If `enabled` is `false` or absent, skip all domain-memory steps without notice.
  - **`search_knowledge`** when entering new territory: `/flow-feat-start` and `/flow-bug-start` (ticket keywords), `/flow-feat-brainstorm` (concept/pattern), `/flow-feat-design` (module + integrations), `/flow-bug-diagnose` (affected component), `/flow-bug-investigate` (hypothetical cause).
  - **`stage_finding`** during the process: when closing `/flow-feat-design` and `/flow-bug-investigate`, if non-obvious domain decisions emerged, propose staging them to the user. Silent by default.
  - **`read_staging`** before saving: `/flow-feat-ship` and `/flow-bug-postmortem` read what was accumulated in staging for that branch before proposing the final save.
  - **`save_knowledge`** when closing: `/flow-feat-ship` and `/flow-bug-postmortem` offer to consolidate. Only the "why" is saved (decisions, constraints, motivations); the "what" (code, routes) lives in the repo.

## `meta.json` schema

```json
{
  "ticket": "{PREFIX}XXXXX",
  "type": "feat" | "bug",
  "title": "Tracker text or short description",
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
      "phases_done": ["build", "review", "validate"],
      "wave": 1,
      "depends_on": [],
      "lines_est": 120,
      "files_est": 6,
      "url": "https://...",
      "note": "reason if closed/superseded; empty otherwise"
    }
  ],
  "started_at": "2026-05-11T10:00:00Z",
  "updated_at": "2026-05-11T11:30:00Z",
  "notes": "free field the user can edit"
}
```

## Shortcuts by size

| Size | Features                                                                  | Bugs                                                            |
|------|---------------------------------------------------------------------------|-----------------------------------------------------------------|
| XS   | start → build → review → ship                                             | start → fix → review → ship                                     |
| S    | start → design (condensed) → build → review → validate → ship             | start → diagnose → fix → review → validate → ship               |
| M    | start → brainstorm → design → **plan** → build → review → validate → ship | full flow                                                       |
| L    | full flow (includes **plan**)                                             | full flow                                                       |

`/flow-feat-plan` is skipped for XS/S (always 1 MR/PR). For M/L it is required and records the `mrs` array in `meta.json`.

## Full `/flow-feat-*` flow

`/flow-feat-start {TICKET}` → `/flow-feat-brainstorm` → `/flow-feat-design` → `/flow-feat-plan` → `/flow-feat-build` → `/flow-feat-review` → `/flow-feat-validate` → `/flow-feat-ship`

For M/L with multiple MR/PRs, the `build → review → validate → ship` block repeats for each MR/PR in the plan. The `meta.json.mrs` array tracks the state. **Each MR/PR earns its own `build`/`review`/`validate`**, recorded in its `mrs[]` entry's `phases_done` — so `/flow-feat-review`, `/flow-feat-validate` and `/flow-feat-ship` gate on *this* MR/PR's progress, not the work-level `phases_done`. This is deliberate: without it, once the first MR/PR completed review/validate the work-level list would satisfy `ship`'s gate for every later MR/PR, letting a train MR/PR ship unreviewed just because an earlier sibling was reviewed.

## Full `/flow-bug-*` flow

`/flow-bug-start {TICKET}` → `/flow-bug-diagnose` → `/flow-bug-investigate` → `/flow-bug-fix` → `/flow-bug-validate` → `/flow-bug-review` → `/flow-bug-postmortem` → `/flow-bug-ship`

## Cross-cutting commands

- `/flow-work-status` — shows all work items in `.claude/work/`, current phase, and divergence with git.
- `/flow-work-resume` — detects the current branch, opens `meta.json`, recaps the state, and suggests the next step.
- `/flow-work-watch {TICKET} [30m]` — post-deployment monitoring: observes the observability platform (per FLOW.md `observability`) scoped to the change. Runs one cycle, saves the state to `monitor.md`, and stops. For continuous monitoring, set up an OS cron job with `opencode run -p "/flow-work-watch {TICKET}"` every 5 minutes.

## Golden rules

1. **Never skip `review`.** If the previous phase is not in `phases_done`, the command refuses.
2. **If you edit code outside the flow**, `/flow-work-status` warns you of the divergence.
3. **Artifacts are hand-editable**. If you rewrite `03-design.md`, the next step will respect it.
4. **`domain-memory` is optional but recommended** when closing large features or postmortems (requires `domain_memory.enabled: true` in FLOW.md).
