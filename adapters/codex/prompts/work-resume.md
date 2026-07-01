# `/work-resume`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Use when returning to a work item after a break (next morning, another session, etc.).

## 1. Detection

- Read `git branch --show-current`.
- Search in `.claude/work/` for the `meta.json` with a matching `branch`.
- If none found: ask the user for the ticket or whether they want to start a new one.
- If the matched `meta.json` has a non-null `worktree` and the current directory is not that worktree, tell the user the work lives in a worktree and to `cd <worktree>` before continuing — run the repo-state checks below from there (`git -C <worktree> …`).

## 2. Recap

Print to the user in brief format:

```
Resuming <TICKET> [feat|bug] [size]
Current phase:  <phase>
Phases done:    <list>
Last edit:      <updated_at>
Notes:          <meta.notes>
```

The ticket format follows `tracker.prefix` from FLOW.md; if empty, show it as-is from `meta.json`.

Then a **5-line summary** synthesizing all available artifacts (`01-context.md` + the most recent ones):
- What is being done and why.
- Decisions made so far.
- What was still pending.

## 3. Repo state

- `git status --short` → pending changes.
- `git log --oneline -5` → recent commits.
- Warn if there are uncommitted changes that don't appear in the most recent log.

## 4. Next step

Suggest the specific command based on `phase` and `size`. If the current phase was interrupted (e.g. `build` with an empty artifact), suggest repeating it with `/feat-build` or `/bug-fix`.

Do not advance automatically. The user decides.
