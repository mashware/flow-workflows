---
description: Start a new feature (read the tracker, classify size, create branch and initial artifact)
---

# `/feat-start $ARGUMENTS`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user.

You are starting a feature. `$ARGUMENTS` must be the ticket identifier (format: `tracker.prefix` from `FLOW.md`; empty = freeform). If empty, ask the user and exit without writing anything.

## 1. Pre-flight

- Read `FLOW.md` at the repo root. If it does not exist, continue with default behavior (each step states what to do when a key is missing).
- Verify the repo has a recognizable project structure. If not, warn and exit.
- If `.claude/work/$ARGUMENTS/meta.json` already exists, do not overwrite it: warn the user and suggest `/work-resume`.

## 2. Gather context

Launch these tasks in **parallel**:

1. **Tracker**: if `tracker.tool` in `FLOW.md` is not `none`, read the ticket using `tracker.view_cmd` replacing `{TICKET}` — extract title, description, acceptance criteria. If `tool` is `none` or empty, or if the command fails, ask the user to paste the brief and continue with whatever they provide.
2. **domain-memory**: if `domain_memory.enabled` is `true`, invoke the `domain-memory` MCP with `search_knowledge` using the ticket title and keywords. If it does not respond within 2 s or fails, continue without context.
3. **Git**: verify you are on a clean branch. If there are uncommitted changes, warn but do not block.

## 3. Clarify gaps in the ticket

Before classifying size, identify whether there are open questions that affect the design and that neither the brief nor `domain-memory` resolves. Typical examples:

- Behavior with different plan types or access levels.
- Locales, countries, or languages with different rules.
- What happens to existing users of the current flow (compatibility).
- What counts as "success" (metric, event, log entry to leave).
- Obvious edge cases not specified (empty input, duplicate, network failure).

If there are open questions, **ask them all at once** (max 4 questions, the most blocking ones). Do not invent or assume. If everything is clear, continue.

Record the answers in `01-context.md` under "Decisions clarified in /feat-start".

## 4. Classify size

Based on the brief and context, propose a size and ask the user to confirm (single question):

| Size | Criterion | Suggested phases |
|------|-----------|------------------|
| XS | < 50 lines, no DB, no new API, no domain logic | start → build → review → ship |
| S | Scoped change, 1-3 relevant files, no migrations | start → design (short) → build → review → validate → ship |
| M | New domain logic, possible migrations, multiple modules | start → brainstorm → design → build → review → validate → ship |
| L | Cross-module, external integrations, significant model changes | full flow, consider splitting |

Recommend the size you estimate with a "(Recommended)".

## 5. Create the branch

**Two non-negotiable rules**, because breaking them has already caused an accidental deployment:

1. **Never** create the branch implicitly from wherever you are. If you are on another task's branch, a `git checkout -b` would inherit its commits.
2. **Never** let the new branch have the base branch as its automatic upstream. With `branch.autoSetupMerge=true`, a `git checkout -b X <base>` pins the upstream to that base, and a push that resolves the upstream can land on the main branch and trigger a deployment.

### 5.1 Check where you are first
```bash
git rev-parse --abbrev-ref HEAD   # current branch
git status --porcelain            # clean working tree?
```
- If there are uncommitted changes: warn and ask before continuing (they carry over when you switch).
- If the current branch **is not the main branch** (master/main): do NOT assume the base. Ask the user:
  - **Base = `git.default_base` from FLOW.md** *(Recommended)* — independent task. This is the normal case.
  - **Stacked on `<current-branch>`** (train mode) — only if this task depends on another not yet merged. Record it in `meta.json` as `stacked_on` and note that the MR/PR will point to that branch, not the main base.

### 5.2 Create with explicit base and WITHOUT inheriting its upstream
Name: per `git.branch_pattern` from `FLOW.md` (replace `{PREFIX}` and `{TICKET}`; `{slug}` in English, kebab-case). Create only if the user confirms:
```bash
git fetch origin
git switch --create <branch-name> --no-track <git.default_base>      # independent task
# — or, in confirmed train mode: —
git switch --create <branch-name> --no-track origin/<parent-branch>
```
`--no-track` is **mandatory**: it is what prevents the upstream from being set to the remote base. The explicit base (`git.default_base` or the parent branch, never "where I am") is what avoids inheriting commits from another task.

### 5.3 Push rule (executed in `ship`, declared here)
The first push is **always** explicit to the branch's own remote, never a push that resolves the upstream blindly:
```bash
git push -u origin HEAD    # upstream = origin/<branch-name>, never the main base
```

## 6. Write artifacts

Create `.claude/work/$ARGUMENTS/`:

### `meta.json`
```json
{
  "ticket": "$ARGUMENTS",
  "type": "feat",
  "title": "<ticket title>",
  "branch": "<branch created in §5>",
  "stacked_on": null,
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "started_at": "<ISO8601 now>",
  "updated_at": "<ISO8601 now>",
  "notes": ""
}
```

### `01-context.md`
Structure:
```markdown
# Context <TICKET>

## Ticket
<brief summary in 3-5 bullets>

## Acceptance criteria
<list from tracker or "not specified">

## Relevant domain knowledge
<domain-memory results, one bullet per finding, or "no findings">

## Repo state at start
- Branch: <name>
- Last commit: <short hash + message>

## Decisions clarified in /feat-start
<list question → user answer, or "no open questions">

## Estimated size: <XS|S|M|L>
<2 lines of justification>
```

## 7. Wrap-up

Summarize for the user in 2-3 lines:
- Ticket, size, branch.
- Next recommended command based on size (see table).

Do not invoke the next step automatically.
