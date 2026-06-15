---
description: Close a work without shipping (discarded feature, non-issue, etc.)
---

# `/work:abandon`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as indicated by each step. Regarding `domain_memory`: if active but the MCP fails or takes more than 2s, continue without that context — do not block or notify the user.

Clean closure for works that will not reach the base branch. Typical cases:

- A feature is discarded after `brainstorm` or `design` (no value, scope does not justify effort).
- A bug turns out not to be one (expected behavior, external problem, user misconfiguration).
- A work is replaced by another ticket that absorbs it.

## 1. Pre-flight

- Locate the active `meta.json`: search by current branch; if not found, ask the user for the ticket.
- If `phase` is already `done`, do not abandon: notify and stop (finished works are archived, not abandoned).
- Read `meta.json` and the existing artifacts to understand what was done.

## 2. Reason

Ask the user for the reason with `AskUserQuestion`. Typical options:

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
- Commits on branch: <git log --oneline <base>..HEAD | wc -l>
- Is there unmerged code?: yes / no

## What was learned (if applicable)
<short bullets on analysis conclusions, if any>

## Follow-up actions (if applicable)
- New ticket to open:
- Changes to revert:
- Branch to delete: yes / no
```

`<base>` is read from `git.default_base` in FLOW.md; if empty, use `origin/main` or `origin/master` according to the repo's real base branch.

## 4. Domain knowledge (conditional offer)

**Only if `domain_memory.enabled` is `true` in FLOW.md and the analysis left non-obvious findings** (why something in the domain works the way it does, legal constraints, integrations with surprising behavior): ask the user whether to invoke `Skill save-knowledge`. Silence by default — abandoning does not mean nothing was learned, but most of the time there is nothing worth saving. If `domain_memory.enabled` is `false` or absent, skip this step silently.

## 5. Git state

Ask the user what to do with the branch:

- **Delete it locally** (if there is nothing worth keeping): `git checkout <base> && git branch -D <branch>`. **Only if the user confirms** — this is destructive.
- **Leave it** (in case the topic comes back): do nothing.
- **Push it to the remote as a reference** (rare but valid if there is valuable analysis).

Do not decide alone — ask.

## 6. Close

- Update `meta.json`:
  - `phase = "abandoned"`.
  - `phases_done` is not touched (it reflects what was actually done).
  - `notes` += abandonment reason.
  - `updated_at` updated.
- Move the folder to `.claude/work/_archive/<TICKET>/` so it does not appear in `/work:status` as pending.
- Report to the user: ticket abandoned, reason, what was done with the branch.

## Recovery

If the topic resurfaces, the user can:
1. Move the folder back: `mv .claude/work/_archive/<TICKET> .claude/work/<TICKET>`.
2. Change `phase` to the phase from which they resume.
3. Recreate the branch if it was deleted.

There is no dedicated command for this — it is intentionally manual (this should not happen often).
