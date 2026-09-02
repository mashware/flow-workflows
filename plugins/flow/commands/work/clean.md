---
description: Sweep what finished work left behind — merged worktrees, dead branches, unarchived work folders
argument-hint: "[--dry-run]"
---

# `/flow:work:clean $ARGUMENTS`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context.

The forge (`git.cli`) is **best-effort**: CLI missing, unauthenticated, or over ~5s → fall back to the local evidence in §4 and say so in one line; never block.

The periodic sweep of the three residues a finished work leaves — its **worktree**, its **local branch**, its **`.claude/work/` folder** — which `/flow:feat:ship` and `/flow:work:abandon` only offer to remove at their end (and a train's intermediate MR/PR never sets `phase = "done"`). Inventory all three, judge each by **the forge's verdict**, remove only what is provably finished, and only after showing the whole list. The only flow command whose purpose is deletion; §0 governs.

## 0. The rule that never bends

**Every deletion is confirmed by the user, in every `autonomy.mode` — including `auto`.**

Deletion is not flow mechanics — it can destroy work that exists nowhere else. `auto` does not authorize it; neither does an earlier confirmed sweep. Invoking the command authorizes the **sweep**; the §6 list authorizes the **deletions**, once, for that list only.

- **Never `--force`, never `-D` on a guess.** A removal that needs force is left alone and reported.
- **When the evidence is unclear, the entry is not a candidate.** Silence from the forge is not a merge.

## 1. Modes

Parse `$ARGUMENTS`:

- **empty** → full sweep: inventory (§2–§3), classify (§4), show (§6), confirm and act (§7).
- **`--dry-run`** → §2–§6 only: prints the same table and stops. Touches nothing, asks nothing.
- **`--worktrees`** / **`--branches`** / **`--works`** → restrict the sweep to that inventory (combinable).
- **`--purge-archive <N>d`** → the separate, opt-in pass in §8. Not part of the default sweep.
- Anything else → unrecognized: explain the modes above and stop.

## 2. Guard: run this from the main checkout

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
```
Differ → the session is **inside a worktree**, which cannot remove itself. Stop; tell the user to run from the main checkout, naming its path (first in `git worktree list`).

Read the current branch (`git branch --show-current`) — protected by §5 regardless of its state.

Refresh the remote view once so "merged" is not judged against a stale base:

```bash
git fetch --prune origin
```
`--prune` drops remote-tracking refs the forge deleted on merge (evidence for §4). Fetch fails (offline) → continue with what is local, note it in one line, treat every "merged" verdict as unconfirmed (§4, degraded).

## 3. Take the inventory

Three lists, gathered in one pass:

- **Worktrees** — `git worktree list --porcelain` → path + branch per entry. Skip the first (the main checkout).
- **Local branches** — `git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads/`.
- **Work folders** — `ls -1 .claude/work/` (ignore `_archive`), reading each `meta.json` for `ticket`, `branch`, `phase`, `worktree`, `mrs[]`.

Two strays caught in the same sweep:

- **Prunable worktree registrations** — `git worktree prune --dry-run`: tracked entries whose directory is gone.
- **Orphan directories** — under the parent of `git.worktree_path` (empty → `.worktrees/`), claimed by no worktree in the inventory (remains of an `rm -rf`). Report; never delete a directory git does not know about without the user saying so explicitly.

Join on branch name — one row per branch with whichever of {worktree, branch, work folder} exist. A row with only one of the three is normal.

## 4. Establish the verdict per branch

One question: **is this branch's work already in the base branch?** Strongest evidence first. `<base>` = `git.default_base`; empty → `git symbolic-ref --short refs/remotes/origin/HEAD`.

**(a) The forge — authoritative, and asked exactly once.** CLI from `git.cli` (or infer from `git.host`). Fetch merged and open lists in **two calls total**, join locally. Never query per branch.

```bash
# GitLab
glab mr list --merged --per-page 100 -F json     # → .source_branch, .web_url
glab mr list --per-page 100 -F json              # open MRs
# GitHub
gh pr list --state merged --limit 100 --json headRefName,number,url
gh pr list --state open   --limit 100 --json headRefName,number,url
```

Merged list → **`merged`**. Open list → **`open`**. Neither → (b); conclude nothing from absence (the page limit alone explains it). More than ~100 MRs/PRs between sweeps → raise the limit or report that older entries were not covered.

**Third state, not in either list: `closed`.** An MR/PR closed *without* merging — rejected or superseded, neither `merged` nor in flight. **Never a candidate** (the code exists only on that branch); the report must say which: `MR !9679 closed without merging` vs `no MR/PR, 4 commits of its own`.

**(b) Ancestry — reliable when the forge merges with a merge commit.**

```bash
git merge-base --is-ancestor <branch> origin/<base>
```
True → **`merged`**.

**(c) Squash detection — (b) fails on every squash merge** (commits replaced by one new sha). Replay the tree onto the merge-base and ask whether the patch is upstream:

```bash
mb=$(git merge-base origin/<base> <branch>)
synthetic=$(git commit-tree "$(git rev-parse <branch>^{tree})" -p "$mb" -m _)
git cherry origin/<base> "$synthetic"
```
`git cherry` prints `- <sha>` → equivalent patch already in the base → **`merged`, squashed**; `+ <sha>` → fall through. The synthetic commit is a dangling object, gone at the next `gc`.

**(d) Nothing of its own** — `git rev-list --count origin/<base>..<branch>` is `0` → **`empty`** (never diverged, nothing to lose).

**(e) Otherwise** → **`unknown`**. Reported, never touched.

**Second pass, bounded.** Still `unknown` after (b)–(d) (older than (a)'s page window, or a squash whose MR/PR absorbed review changes): if **25 or fewer**, ask the forge per branch:

```bash
glab mr list --source-branch <branch> --all -F json     # GitLab
gh pr list --head <branch> --state all --json state,number,url   # GitHub
```
Above 25 → skip the pass and report how many were left unresolved.

Degraded mode (no forge, no successful fetch): keep the (b)–(d) verdicts, mark the whole table `(local evidence only — origin not refreshed)`, and drop `merged, squashed` to `unknown`.

## 5. The protected set

A candidate must survive all of these — each a hard exclusion, not a warning:

| Protected | Why |
|---|---|
| The **current branch** and the **main checkout** | You are standing on it |
| `<base>` and any long-lived branch (`main`, `master`, `develop`, `staging`, `production`, `release/*`, or whatever the forge reports as protected) | Never candidates, whatever the verdict |
| A worktree with **uncommitted or staged changes** (`git -C <wt> status --porcelain` non-empty) | Unsaved work, and removing it would need `--force` |
| A branch with **commits not on the remote** and verdict ≠ `merged` | Exists only here |
| Verdict `open` | The MR/PR is live; the branch is in use |
| Verdict `closed` | The MR/PR was closed unmerged; the code lives only on that branch |
| Verdict `unknown` | See §0 — unclear evidence is not permission |
| A work folder whose `phase` is neither `done` nor `abandoned`, unless §6.C's reconciliation applies | Work in flight |
| Anything under `.claude/work/` — as **deletion** | This command archives folders; it never deletes them |

- "Not on the remote" is measured against **`refs/remotes/origin/<branch>`**, not `@{u}` (flow uses `git worktree add --no-track`, so a pushed branch has **no configured upstream**). Only with no remote ref at all does the count fall back to `origin/<base>..<branch>`.
- A `merged` branch with a dirty worktree gets its own report line (the MR/PR went in; edits in that checkout never left it). Leave it alone — the user's decision.

## 6. Show the sweep

Group by action, most consequential first. One line per row, no prose between:

```
Sweep of <repo> · base <base> · <N> worktrees · <N> branches · <N> work folders
Forge: <glab|gh> · <N> merged / <N> open MRs/PRs read

A. Worktrees to remove — MR/PR merged                                   (<N>)
   PROJ-1234-billing-retry-window   .worktrees/PROJ-1234-…  merged #412   branch too
   PROJ-1240-invoice-pdf-export     .worktrees/PROJ-1240-…  merged #418   branch too

B. Branches to delete — merged, no worktree                             (<N>)
   PROJ-1198-timezone-in-digest     merged #401 (squashed)

C. Work folders to archive                                              (<N>)
   PROJ-1234-billing-retry-window   phase: done              → _archive/
   PROJ-1150-legacy-import-spike    branch gone, MRs merged  → _archive/  ⚠ needs your call

D. Registrations to prune                                               (<N>)
   .worktrees/PROJ-1102-…           directory gone

Left alone                                                              (<N>)
   PROJ-1301-webhook-signing        open MR/PR #430
   PROJ-1288-rate-limit-headers     merged #421, but worktree has uncommitted changes
   PROJ-1210-batch-import           MR/PR #388 closed without merging
   spike-cache-layer                no MR/PR, 4 commits not on the remote
   .worktrees/PROJ-1090-stale       directory not registered as a worktree

_archive: <N> folders (<size>) — untouched; see --purge-archive
```

- Every row carries **why** — `merged #412`, `merged #401 (squashed)`, `never diverged` for `empty` — the reason is what the user approves. A row without one is a bug.
- `⚠ needs your call` in **C** = *settled but not closed out*: `phase` not `done`, yet every `meta.json.mrs` entry is `merged` and the branch is gone or merged (a train whose last `ship` never ran). Never fold into a bulk yes — confirm each individually; on confirmation set `phase = "done"` and `updated_at` before moving the folder.
- Every group empty → say the repo is clean, one line, stop.

## 7. Confirm and execute

Ask once with `AskUserQuestion`: **Everything** · **Worktrees and branches only** · **Work folders only** · **Pick individually** · **Nothing**. On *Pick individually*, collect every choice before executing any — a half-applied sweep is worse than none.

Execute in this order (a branch cannot be deleted while a worktree holds it):

1. **Worktrees** — `git worktree remove <path>`. No `--force`, ever: §5 excluded the dirty ones, so a failure means something changed since the inventory. Stop that row, report it, continue.
2. **Branches** — `git branch -d <branch>` first. Git refuses on a squash merge; only then `git branch -D`, and only for rows whose verdict came from **the forge** (§4a) — never a locally inferred one. Name it in the report: `-D (squash-merged, MR #401)`.
3. **Work folders** — `mv .claude/work/<dir> .claude/work/_archive/<dir>`, keeping the name, as `/flow:work:abandon` §6 does. Never `rm`.
4. **Prune** — `git worktree prune`.

Never touch the remote (no `git push --delete`; deleting merged remote branches is the forge's job).

A step fails → report that row as failed with the git error verbatim, keep going. Never retry with a stronger flag.

## 8. `--purge-archive <N>d` (opt-in, separate)

The sweep never touches `.claude/work/_archive/`; this opt-in pass is for when it has become noise. Only folders **archived more than `<N>` days ago** (newest `updated_at` in `meta.json`, else directory mtime) **and fully committed to git**, verified per folder:

```bash
git ls-files --error-unmatch <dir> >/dev/null   # tracked?
git status --porcelain <dir>                    # and no local modifications?
```
Tracked and clean → in history (`git log -- <path>` brings it back). **Untracked** (`.claude/work/` is often git-ignored) → the only copy: exclude it, list it separately, say plainly that purging would be permanent.

Show the list with sizes, confirm as in §7, `rm -rf` only the tracked-and-clean ones. Report how many purged and how many kept for being untracked.

## 9. Report

State first, then the numbers:

```
<repo> · swept · <N> removed, <N> archived, <N> left alone
Worktrees removed:  <N>   (<disk freed>)
Branches deleted:   <N>
Folders archived:   <N>
Failed:             <N>   (<row>: <error>)
```

Then at most three lines of body, only what could change a decision: failed rows, rows left alone for an actionable reason (dirty merged worktree, unpushed branch), the untracked-archive note if §8 ran. Nothing already in the §6 table.

## Notes

- **Read the forge, not the calendar.** Age is never evidence — except in §8, where the entry is already archived and in git.
- **`/flow:work:status` §4 and `/flow:work:daily` §4 surface the same residue** as a count and point here; they never delete.
- **It does not advance `meta.json.phase`** — except the individually confirmed §6.C reconciliation (sets `done` when all MRs/PRs merged).
- **Safe to run often.** `--dry-run` is read-only; a clean repo produces one line.
