---
description: Close a work without shipping (discarded feature, non-issue, etc.)
---

# `/flow:work:abandon`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context.

Clean closure for works that will not reach the base branch: a feature discarded after `brainstorm` or `design`, a bug that is not one (expected behavior, external problem, user misconfiguration), a work absorbed by another ticket.

## 1. Pre-flight

- Locate the active `meta.json` by current branch; not found → ask the user for the ticket.
- `phase` already `done` → do not abandon: notify and stop (finished works are archived, not abandoned).
- Read `meta.json` and `00-summary.md`; open the existing artifacts in full only where the summary does not say what was done (missing summary → read the artifacts).

## 2. Reason

Ask with `AskUserQuestion`. Typical options:

- **Discarded feature** (not enough value).
- **Not actually a bug** (expected behavior or external problem).
- **Absorbed by another ticket** (will be done in a different ticket).
- **Externally blocked** (depends on something outside our control).
- **Other** (user explains).

Record the reason in a single line — it goes into the artifact.

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
- Commits on branch: <git log --oneline <base>..HEAD | wc -l>
- Is there unmerged code?: yes / no

## What was learned (if applicable)
<short bullets on analysis conclusions, if any>

## Follow-up actions (if applicable)
- New ticket to open:
- Changes to revert:
- Branch to delete: yes / no
```

`<base>` = `git.default_base` in FLOW.md; empty → `origin/main` or `origin/master` per the repo's real base branch.

## 4. Domain knowledge (conditional offer)

**Only if any `knowledge` role is set and the analysis left non-obvious findings** (why the domain works as it does, legal constraints, surprising integrations): ask whether to invoke `Skill save-knowledge`. Silence by default; the role empty → skip silently.

## 5. Git state

Ask the user what to do with the branch — do not decide alone:

- **Delete it locally** (nothing worth keeping): `git checkout <base> && git branch -D <branch>`. **Only if the user confirms** — destructive.
- **Leave it** (the topic may come back): do nothing.
- **Push it to the remote as a reference** (rare; valid when there is valuable analysis).

`meta.json.worktree` not null → the branch is checked out in a worktree and cannot be deleted while it exists:
- On **Delete it locally**: first, from the main checkout (not inside it), `git worktree remove <worktree>` (`--force` only if it has changes the user confirms discarding), then `git branch -D <branch>`.
- On **Leave it**: you may still offer to remove just the worktree directory (`git worktree remove <worktree>`) while keeping the branch.
- Note what was done in `99-abandoned.md`.

## 6. Close

- Update `meta.json`: `phase = "abandoned"`; `phases_done` not touched (it reflects what was actually done); `notes` += abandonment reason; `updated_at` updated.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- **Tracker: move to won't-do** (never "done" — this work did not ship). Only if `tracker.tool` is not `none`/empty, `tracker.abandon_cmd` is set, and `meta.json.ticket` is a **real tracker id** (skip for local-only slugs). Run `tracker.abandon_cmd` substituting `{TICKET}` = `meta.json.ticket`. Same contract as `/flow:feat:start §6.5`: **best-effort, idempotent, gated** (ask once in `autonomy.mode: manual`; automatic in `guided`/`auto`); failure or already-in-state ticket → warn and continue, never block. `tracker.abandon_cmd` empty → do nothing (the user closes the ticket by hand if they want).
- `panel.json` present (`/flow:work:README`) → overwrite with a terminal state before archiving: the title, one `block` line saying the work was abandoned and why, no `Decision` line.
- Move the folder to `.claude/work/_archive/` **keeping its directory name** (`_archive/<work-dir>/`, the folder located in §1 — e.g. `<TICKET>-<slug>`) so `/flow:work:status` no longer lists it.
- Report to the user: ticket abandoned, reason, what was done with the branch.

## Recovery

Intentionally manual — no dedicated command. If the topic resurfaces:
1. Move the folder back: `mv .claude/work/_archive/<TICKET> .claude/work/<TICKET>`.
2. Change `phase` to the phase from which to resume.
3. Recreate the branch if it was deleted.
