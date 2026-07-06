---
description: Close a work item without shipping (discarded feature, non-issue bug report, etc.)
---

# `/flow-work-abandon`

**Step 0**: Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Clean closure for work items that will not reach the base branch. Typical cases:

- A feature is discarded after `brainstorm` or `design` (no value added, scope does not justify effort).
- A bug turns out not to be one (expected behaviour, external issue, user configuration).
- A work item is replaced by another ticket that absorbs it.

## 1. Pre-flight

- Locate the active `meta.json`: search by current branch; if not found, ask the user for the ticket.
- If `phase` is already `done`, do not abandon: warn and stop (completed work items are archived, not abandoned).
- Read `meta.json` and the existing artifacts to understand what was done.

## 2. Justification

Ask the user for the reason. Typical options:

- **Feature discarded** (insufficient value).
- **Not a bug** (expected behaviour or external issue).
- **Absorbed by another ticket** (handled in a different ticket).
- **Externally blocked** (depends on something outside our control).
- **Other** (user explains).

Record the justification in a single line — it goes into the artifact.

## 3. Minimal capture

Write `.claude/work/<TICKET>/99-abandoned.md`:

```markdown
# Abandoned <TICKET>

## Reason
<one line>

## State at abandonment
- Phase reached: <phase>
- Completed phases: <phases_done>
- Branch: <branch>
- Worktree: <meta.worktree path, or "none"> — <removed / kept>
- Commits on the branch: <git log --oneline <base>..HEAD | wc -l>
- Unmerged code?: yes / no

## What was learned (if applicable)
<short bullets about findings from the analysis, if any>

## Follow-up actions (if applicable)
- New ticket to open:
- Changes to revert:
- Branch to delete: yes / no
```

`<base>` is read from `git.default_base` in FLOW.md; if empty, use `origin/main` or `origin/master` based on the repo's actual base branch.

## 4. Domain knowledge (conditional offer)

**Only if `domain_memory.enabled` is `true` in FLOW.md and the analysis left non-obvious findings** (why something in the domain works the way it does, legal constraints, integrations with surprising behaviour): ask the user whether they want to invoke `/flow-save-knowledge`. Silent by default. If `domain_memory.enabled` is `false` or absent, skip this step without any notification.

## 5. Git state

Ask the user what to do with the branch:

- **Delete locally** (if nothing is worth keeping): `git checkout <base> && git branch -D <branch>`. **Only if the user confirms** — destructive.
- **Leave it** (in case the topic resurfaces): no action.
- **Push it to remote as a reference** (rare but valid if there is valuable analysis).

If `meta.json.worktree` is not null, the branch is checked out in a worktree and cannot be deleted while it exists. On **Delete locally**, first remove the worktree (from the main checkout, not from inside it): `git worktree remove <worktree>` (add `--force` only if it has changes the user confirms discarding), then `git branch -D <branch>`. On **Leave it**, you may still offer to remove just the worktree directory (`git worktree remove <worktree>`) while keeping the branch. Note what was done in `99-abandoned.md`.

Do not decide on your own — ask.

## 6. Close

- Update `meta.json`:
  - `phase = "abandoned"`.
  - `phases_done` is not modified (it reflects what was actually done).
  - `notes` += abandonment reason.
  - `updated_at` updated.
- Move the folder to `.claude/work/_archive/<TICKET>/` so it does not appear in `/flow-work-status` as pending.
- Report to the user: ticket abandoned, reason, what was done with the branch.

## Recovery

If the topic resurfaces, the user can:
1. Move the folder back: `mv .claude/work/_archive/<TICKET> .claude/work/<TICKET>`.
2. Change `phase` to the phase from which they are resuming.
3. Recreate the branch if it was deleted.

There is no dedicated command for this — it is intentionally manual (it should not be a frequent case).
