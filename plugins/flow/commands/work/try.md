---
description: Point the main checkout at a branch to test it (then return), re-syncing per FLOW.md
---

# `/flow:work:try $ARGUMENTS`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as indicated by each step. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Temporarily point the **main checkout** at another branch so you can run/test it against this checkout's live environment (the running stack, DB, containers) — then return. This is the generic, project-agnostic equivalent of a `make wt-try`/`wt-back` pair: the git switch is built in, and the only project-specific part (re-syncing the environment after switching, e.g. applying migrations) comes from `git.worktree_resync` in `FLOW.md`. It complements worktrees: develop a branch in its worktree, then test it here where the stack runs.

It operates **in place** on the current checkout; it does not create or touch worktrees.

## 1. Parse the argument

- `$ARGUMENTS` is a **branch name** → *Try mode* (§3).
- `$ARGUMENTS` is `--back` (or `back`, or empty while the checkout is in a detached "try" state) → *Back mode* (§4).
- Anything else / ambiguous → ask the user which branch to try, or `--back` to return.

Read `git.worktree_resync` from `FLOW.md`: a list of commands (one per line) to run after switching. Empty/absent = no re-sync (git switch only).

## 2. Clean-tree guard (both modes)

```bash
git status --porcelain
```
If there are uncommitted or staged changes, **stop**: switching would carry them over. Tell the user to commit or stash first. Do not `--force` anything. This mirrors the guard in the reference `wt-try`/`wt-back` targets.

## 3. Try mode — `/flow:work:try <branch>`

1. Resolve the branch: if `<branch>` exists locally use it; otherwise `git fetch origin` and use `origin/<branch>` (tell the user you are using the remote ref).
2. Switch the main checkout to it in **detached HEAD** (intentional — you are only testing, not committing onto that branch):
   ```bash
   git switch --detach <branch>       # or origin/<branch>
   ```
   `git switch -` in §4 returns you to the branch you were on before this.
3. **Re-sync the environment** with `git.worktree_resync`. Because these commands can be invasive (schema migrations, container rebuilds), show the exact list and ask the user to confirm before running (`AskUserQuestion`: Run / Skip). On confirm, run them **in order**, stopping and reporting if one fails. If `git.worktree_resync` is empty, skip this step silently.
4. Report: now on `<branch>` (detached), which re-sync commands ran, and remind that `/flow:work:try --back` returns to the previous branch.

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

- Detached HEAD is deliberate: it prevents accidental commits onto the branch you are only testing.
- This never pushes and never touches the base branch's history — it is a local, reversible convenience.
- If your project needs more than a couple of commands to re-sync, put them all in `git.worktree_resync`; the command runs whatever is there, in order.
