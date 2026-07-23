# `/flow-work-abandon`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Clean close for work items that won't reach the main branch. Typical cases:

- A feature is discarded after `brainstorm` or `design` (doesn't deliver value, scope doesn't justify the effort).
- A bug turns out not to be one (expected behavior, external problem, user configuration).
- A work item is absorbed by another ticket.

## 1. Pre-flight

- Locate the active `meta.json`: look by current branch; if not found, ask the user for the ticket.
- If `phase` is already `done`, don't abandon: warn and stop (completed work items are archived, not abandoned).
- Read `meta.json` and existing artifacts to understand what was done.

## 2. Justification

Ask the user for the reason. Typical options:

- **Feature discarded** (doesn't deliver enough value).
- **Not a bug** (expected behavior or external problem).
- **Absorbed by another ticket** (being done in another ticket).
- **Externally blocked** (depends on something outside our control).
- **Other** (the user explains).

Note the justification in one line — it goes in the artifact.

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
- Is there unmerged code?: yes / no

## What was learned (if applicable)
<short bullets on analysis conclusions, if any>

## Derived actions (if applicable)
- New ticket to open:
- Changes to revert:
- Branch to delete: yes / no
```

The `<base>` is read from `git.default_base` in FLOW.md; if empty, use `origin/main` or `origin/master`.

## 4. Domain knowledge (conditional offer)

**Only if `domain_memory.enabled` is `true` in FLOW.md and the analysis left non-obvious findings**: ask the user whether they want to invoke `/flow-save-knowledge`. Silence by default. If `domain_memory.enabled` is `false` or absent, skip this step without comment.

## 5. Git state

Ask the user what to do with the branch:

- **Delete it locally** (if there's nothing worth keeping): `git checkout <base> && git branch -D <branch>`. **Only if the user confirms** — destructive.
- **Leave it** (in case the topic comes back): don't touch it.
- **Push it to the remote as a reference** (rare but valid if there's valuable analysis).

If `meta.json.worktree` is not null, the branch is checked out in a worktree and can't be deleted while it exists. On **Delete it locally**, first remove the worktree (from the main checkout, not from inside it): `git worktree remove <worktree>` (add `--force` only if it has changes the user confirms discarding), then `git branch -D <branch>`. On **Leave it**, you may still offer to remove just the worktree directory (`git worktree remove <worktree>`) while keeping the branch. Note what was done in `99-abandoned.md`.

Don't make the decision alone — ask.

## 6. Close

- Update `meta.json`:
  - `phase = "abandoned"`.
  - `phases_done` is not touched.
  - `notes` += abandonment reason.
  - `updated_at` updated.
- Move the folder to `.claude/work/_archive/` **keeping its directory name** (`_archive/<work-dir>/`, where `<work-dir>` is the folder located in §1 — e.g. `<TICKET>-<slug>`) so it doesn't appear in `/flow-work-status` as pending.
- Summarize for the user: abandoned ticket, reason, what was done with the branch.

## Recovery

If the topic comes back, the user can:
1. Move the folder back: `mv .claude/work/_archive/<TICKET> .claude/work/<TICKET>`.
2. Change `phase` to the phase they're resuming from.
3. Re-create the branch if it was deleted.
