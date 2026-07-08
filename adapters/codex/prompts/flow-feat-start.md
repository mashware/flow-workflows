# `/flow-feat-start $ARGUMENTS`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

You are starting a feature. `$ARGUMENTS` must be the ticket identifier (`tracker.prefix` format from `FLOW.md`; empty = free-form). If empty, ask the user and stop without writing anything.

## 1. Pre-flight

- Read `FLOW.md` at the repo root. If it doesn't exist, continue with default behavior (each step describes what to do when a key is missing).
- Verify the repo has a recognizable project structure. If not, warn and stop.
- If `.claude/work/$ARGUMENTS/meta.json` already exists, don't overwrite it: warn the user and suggest `/flow-work-resume`.

## 2. Gather context

Run these tasks in **parallel**:

1. **Tracker**: if `tracker.tool` in `FLOW.md` is not `none`, read the ticket using `tracker.view_cmd` replacing `{TICKET}` — extract title, description, acceptance criteria. If `tool` is `none` or empty, or the command fails, ask the user to paste the description and continue with what they provide.
2. **domain-memory**: if `domain_memory.enabled` is `true`, call the `domain-memory` MCP with `search_knowledge` using the ticket title and keywords. If it doesn't respond within 2s or fails, continue without context.
3. **Git**: verify you're on a clean branch. If there are uncommitted changes, warn but don't block.

## 3. Clarify ticket gaps

Before classifying size, identify any open questions that affect the design and that neither the ticket description nor `domain-memory` resolve. Typical examples:

- Behavior for different plan types or access levels.
- Locales, countries, or languages with different rules.
- What happens to existing users on the current flow (compatibility).
- What counts as "success" (metric, event, log to emit).
- Obvious edge cases not specified (empty input, duplicate, network failure).

If there are questions, **ask them all at once** (max 4, the most blocking ones). Don't invent or assume. If everything is clear, continue.

Answers are noted in `01-context.md` under "Decisions clarified in /flow-feat-start".

## 4. Classify size

Based on the description and context, propose a size and ask the user for confirmation (single question):

| Size | Criteria                                                                  | Suggested phases                     |
|------|---------------------------------------------------------------------------|--------------------------------------|
| XS   | < 50 lines, no DB, no new API, no domain logic                            | start → build → review → ship        |
| S    | Bounded change, 1-3 relevant files, no migrations                         | start → design (short) → build → review → validate → ship |
| M    | New domain logic, possible migrations, multiple modules                   | start → brainstorm → design → build → review → validate → ship |
| L    | Cross-module, external integrations, significant model changes            | full flow, consider splitting        |

Recommend the size you estimate with a "(Recommended)".

## 5. Create the branch

**Two non-negotiable rules**, because breaking them has already caused an accidental deployment:

1. **Never** create the branch implicitly from wherever you currently are. If you're on another task's branch, a `git checkout -b` would inherit its commits.
2. **Never** let the new branch have the base branch as its automatic upstream. With `branch.autoSetupMerge=true`, a `git checkout -b X <base>` sets the upstream to that base, and a push that resolves the upstream can end up on the main branch and trigger a deployment.

Both rules apply the same whether the branch is created in place or as a worktree.

### 5.0 In place or worktree?
Read `git.worktree` from `FLOW.md`:
- `off` or empty → in place (§5.2). This is the current behavior; skip to §5.1.
- `always` → create as a worktree (§5.4).
- `ask` → ask the user ("Create this branch as a git worktree (separate checkout) or in place?"). Worktree → §5.4; in place → §5.2.

### 5.1 Check where you are first
```bash
git rev-parse --abbrev-ref HEAD   # current branch
git status --porcelain            # clean tree?
```
- If there are uncommitted changes: warn and ask before continuing (they get carried over with `switch`).
- If the current branch **is not the main branch** (master/main): do NOT assume the base. Ask the user:
  - **Base = `git.default_base` from FLOW.md** *(Recommended)* — independent task. This is the normal case.
  - **Stacked on `<current-branch>`** (train mode) — only if this task depends on another not yet merged. Record it in `meta.json` as `stacked_on` and remember the MR/PR will target that branch, not the main base.

### 5.2 Create with an explicit base and WITHOUT inheriting its upstream
Name: per `git.branch_pattern` from `FLOW.md` (substitute `{PREFIX}` and `{TICKET}`; `{slug}` in English, kebab-case). Create only if the user confirms:
```bash
git fetch origin
git switch --create <branch-name> --no-track <git.default_base>      # independent task
# — or, in confirmed train mode: —
git switch --create <branch-name> --no-track origin/<parent-branch>
```
`--no-track` is **mandatory**: it's what prevents the upstream from being set to the remote base. The explicit base (from `git.default_base` or the parent branch, never "where I am") is what prevents inheriting commits from another task. Then go to §6 (record `"worktree": null` in `meta.json`).

### 5.4 Create as a git worktree (when §5.0 chose worktree)
Same name and the same two non-negotiable rules. The worktree directory comes from `git.worktree_path` (substitute `{branch}` = branch name, `{repo}` = repo dir name); empty → `.worktrees/<branch-name>` at the repo root. `git worktree add` creates the branch **and** its checkout in a single step:
```bash
git fetch origin
git worktree add --no-track -b <branch-name> <worktree-path> <git.default_base>   # independent task
# — or, in confirmed train mode: —
git worktree add --no-track -b <branch-name> <worktree-path> origin/<parent-branch>
```
`--no-track` is **mandatory** here too (same upstream rule). Do NOT `git switch` — the current checkout stays where it is; the new branch lives in `<worktree-path>`.
- If the path is under the repo (e.g. `.worktrees/`) and it isn't already ignored, add the worktree root to `.gitignore` (or `.git/info/exclude`) so the checkout doesn't show up as untracked. Don't commit the worktree contents.
- Tell the user the rest of the flow runs **from the worktree**: `cd <worktree-path>`. Record the resolved path in `meta.json` as `worktree`.

### 5.3 Push rule (executed in `ship`, declared here)
The first push is **always** explicit to the branch's own remote, never a push that blindly resolves upstream:
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
  "worktree": "<worktree path if created in §5.4, else null>",
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
<summary of the description in 3-5 bullets>

## Acceptance criteria
<list from the tracker or "not specified">

## Relevant domain knowledge
<domain-memory hits with one bullet per finding, or "no findings">

## Repo state at start
- Branch: <name>
- Last commit: <short hash + message>

## Decisions clarified in /flow-feat-start
<list of question → user answer, or "no questions">

## Estimated size: <XS|S|M|L>
<2 lines justifying>
```

## 7. Close

Summarize for the user in 2-3 lines:
- Ticket, size, branch.
- Next recommended command based on size (see table).

Do not automatically invoke the next step.
