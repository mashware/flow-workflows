---
description: Resume the work associated with the current branch and suggest the next step
---

# `/flow-work-resume`

**Step 0**: Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Use this command when returning to work after a break (next morning, another session, etc.).

## 1. Detection

- Read `git branch --show-current`.
- Look in `.claude/work/` for a `meta.json` with a matching `branch`.
- If none found: ask the user for the ticket or whether they want to start a new one.
- If the matched `meta.json` has a non-null `worktree` and the current directory is not that worktree, tell the user the work lives in a worktree and to `cd <worktree>` before continuing — run the repo-state checks below from there (`git -C <worktree> …`).

## 2. Summary

Print to the user in brief format:

```
Resuming <TICKET> [feat|bug] [size]
Current phase:   <phase>
Completed phases: <list>
Last edited:     <updated_at>
Notes:           <meta.notes>
Cross-repo:      <meta.related_repos entries not "done", as "repo: scope"; or "—">
```

The ticket format follows `tracker.prefix` from FLOW.md; if empty, display it as-is from `meta.json`.

Then a **5-line summary** synthesising all available artifacts (`01-context.md` + the most recent):
- What is being done and why.
- Decisions made so far.
- What was still pending.

## 3. Repo state

- `git status --short` → pending changes.
- `git log --oneline -5` → latest commits.
- Warn if there are uncommitted changes that do not appear in the most recent log.

## 4. Next step

Suggest the concrete command based on `phase` and `size`. If the current phase was interrupted (e.g. `build` with an empty artifact), suggest repeating it with `/flow-feat-build` or `/flow-bug-fix`.

If `meta.json.related_repos` has entries not `done`, remind the user that a **sibling repo still has a pending part** (`<repo>: <scope>`) — suggest starting the work there (`/flow-feat-start <TICKET>` in that repo). flow only reminds; it does not scan or touch the other repo.

Do not proceed on your own. The user decides.
