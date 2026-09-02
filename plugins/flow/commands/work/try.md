---
description: Point the main checkout at a branch to test it (then return), re-syncing per FLOW.md
argument-hint: "<branch> | --back"
---

# `/flow:work:try $ARGUMENTS`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context.

Temporarily point the **main checkout** at another branch to test it against this checkout's live environment (running stack, DB, containers), then return — a generic `make wt-try`/`wt-back` pair. The git switch is built in; the project-specific re-sync (e.g. migrations) comes from `git.worktree_resync` in `FLOW.md`. Operates **in place**; never creates or touches worktrees.

## 1. Parse the argument

- `$ARGUMENTS` is a **branch name** → *Try mode* (§3).
- `$ARGUMENTS` is `--back` (or `back`, or empty while the checkout is in a detached "try" state) → *Back mode* (§4).
- Anything else / ambiguous → ask the user which branch to try, or `--back` to return.
- Read `git.worktree_resync` from `FLOW.md`: commands (one per line) to run after switching. Empty/absent → no re-sync (git switch only).

## 2. Clean-tree guard (both modes)

```bash
git status --porcelain
```
Uncommitted or staged changes → **stop**: switching would carry them over. Tell the user to commit or stash first. Do not `--force` anything.

## 3. Try mode — `/flow:work:try <branch>`

1. Resolve the branch: `<branch>` exists locally → use it; otherwise `git fetch origin` and use `origin/<branch>` (tell the user you are using the remote ref).
2. Switch the main checkout in **detached HEAD** (you are only testing, not committing onto that branch):
   ```bash
   git switch --detach <branch>       # or origin/<branch>
   ```
   `git switch -` in §4 returns you to the branch you were on before this.
3. **Re-sync the environment** with `git.worktree_resync`. These commands can be invasive (schema migrations, container rebuilds): show the exact list and confirm before running (`AskUserQuestion`: Run / Skip). On confirm, run them **in order**, stopping and reporting if one fails. Empty → skip silently.
4. Report: now on `<branch>` (detached), which re-sync commands ran, and that `/flow:work:try --back` returns to the previous branch.

## 4. Back mode — `/flow:work:try --back`

1. Clean-tree guard (§2).
2. Return to the previous branch:
   ```bash
   git switch -
   ```
   If it fails (no previous branch recorded), tell the user which branch to switch to manually.
3. Re-sync again with `git.worktree_resync` (same confirm-then-run as §3.3).
4. Report the branch you are back on and which re-sync commands ran.

## Notes

- Detached HEAD is deliberate: no accidental commits onto the branch you are only testing.
- Never pushes, never touches the base branch's history — a local, reversible convenience.
- Put every re-sync command your project needs in `git.worktree_resync`; they run in order.
