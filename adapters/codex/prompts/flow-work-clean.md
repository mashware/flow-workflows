# `/flow-work-clean $ARGUMENTS`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding the forge (`git.cli`): it's **best-effort** — if the CLI is missing, unauthenticated, or takes more than ~5 s, fall back to the local evidence in §4 and say so in one line; never block. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

The periodic sweep. Every finished work leaves three kinds of residue on disk — the **worktree** it was developed in, the **local branch** behind it, and its **`.claude/work/` folder** — and each is only cleaned up if you happen to answer yes at the end of `/flow-feat-ship` or `/flow-work-abandon`. That prompt is easy to miss and, in a train, never fires at all: an intermediate MR/PR doesn't set `phase = "done"`, so nothing offers to remove anything. After a few weeks the repo carries dozens of full checkouts of branches that merged long ago.

This command is the counterpart: it takes stock of all three inventories at once, checks each entry against **the forge's verdict** rather than a guess, and removes only what is provably finished — after showing you the whole list. It's the only flow command whose purpose is deletion, so §0 isn't decoration.

## 0. The rule that never bends

**Every deletion is confirmed by the user, in every `autonomy.mode` — including `auto`.**

`autonomy.mode` governs *flow mechanics* (which panel to launch, whether to chain into the next MR/PR). Removing a checkout or a branch isn't mechanics: it's the one action in the plugin that can destroy work that exists nowhere else. So `auto` doesn't authorize it, and neither does the user having confirmed a similar sweep an hour ago. Invoking the command authorizes the **sweep**; the list in §6 authorizes the **deletions**, once, for that list only.

Two corollaries the rest of this file leans on:

- **Never `--force`, never `-D` on a guess.** If a removal needs force, that's the signal to leave it alone and report it, not to add the flag.
- **When the evidence is unclear, the entry isn't a candidate.** Silence from the forge isn't a merge.

## 1. Modes

Parse `$ARGUMENTS`:

- **empty** → full sweep: inventory (§2–§3), classify (§4), show (§6), confirm and act (§7).
- **`--dry-run`** → §2–§6 only. Prints the same table and stops. Touches nothing, asks nothing. This is the safe way to see what a sweep *would* do.
- **`--worktrees`** / **`--branches`** / **`--works`** → restrict the sweep to that inventory (combinable). Useful when you want the worktrees gone but the work folders left where they are.
- **`--purge-archive <N>d`** → the separate, opt-in pass in §8. Not part of the default sweep.
- Anything else → treat as unrecognized: explain the modes above and stop.

## 2. Guard: run this from the main checkout

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
```
If the two differ, the session is **inside a worktree**. A worktree can't remove itself, and this command may want to remove the one you're standing in. Stop and tell the user to run it from the main checkout, naming the path (`git worktree list` shows it first).

Also read the current branch (`git branch --show-current`) — it's protected by §5 regardless of its state.

Then refresh the local view of the remote once, so "merged" isn't judged against a stale base:

```bash
git fetch --prune origin
```
`--prune` also drops remote-tracking refs for branches the forge deleted on merge, which is itself part of the evidence in §4. If the fetch fails (offline), continue with what's local and note it in one line — but treat every "merged" verdict as unconfirmed (§4, degraded).

## 3. Take the inventory

Three lists, gathered in one pass:

- **Worktrees** — `git worktree list --porcelain` → path + branch per entry. Skip the first (the main checkout).
- **Local branches** — `git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads/`.
- **Work folders** — `ls -1 .claude/work/` (ignore `_archive`), reading each `meta.json` for `ticket`, `branch`, `phase`, `worktree`, `mrs[]`.

Plus two strays worth catching in the same sweep:

- **Prunable worktree registrations** — `git worktree prune --dry-run`: entries git still tracks whose directory is gone. Harmless but they clutter `git worktree list`.
- **Orphan directories** — directories under the parent of `git.worktree_path` (empty → `.worktrees/`) that no worktree in the inventory claims. These are the remains of a `rm -rf` on a worktree. Report them; never delete a directory git doesn't know about without the user saying so explicitly.

Join the three lists on the branch name — one row per branch, carrying whichever of {worktree, branch, work folder} exist for it. A row may have only one of the three; that's normal and is itself informative (a work folder whose branch is gone, a worktree whose folder was already archived).

## 4. Establish the verdict per branch

The whole command rests on one question: **is this branch's work already in the base branch?** Get it from the strongest evidence available, in this order. `<base>` is `git.default_base` from `FLOW.md`; if empty, auto-discover it (`git symbolic-ref --short refs/remotes/origin/HEAD`).

**(a) The forge — authoritative, and asked exactly once.** Resolve the CLI from `git.cli` (or infer from `git.host`). Fetch the merged and open lists in **two calls total**, then join locally against the inventory. Never query per branch: a repo with 20 worktrees would mean 20 round trips for an answer two calls already contain.

```bash
# GitLab
glab mr list --merged --per-page 100 -F json     # → .source_branch, .web_url
glab mr list --per-page 100 -F json              # open MRs
# GitHub
gh pr list --state merged --limit 100 --json headRefName,number,url
gh pr list --state open   --limit 100 --json headRefName,number,url
```

A branch in the merged list → **`merged`**. In the open list → **`open`**. In neither → fall through to (b); don't conclude anything from absence, since the page limit alone can explain it. If the repo turns over more than ~100 MRs/PRs between sweeps, raise the limit or say in the report that older entries weren't covered — a bounded query that silently reads as "checked everything" is exactly the kind of quiet cap this plugin doesn't do.

**(b) Ancestry — reliable when the forge merges with a merge commit.**

```bash
git merge-base --is-ancestor <branch> origin/<base>
```
True → **`merged`**.

**(c) Squash detection — because (b) fails on every squash merge.** A squash-merged branch isn't an ancestor of anything: its commits were replaced by one new commit with a different sha. Replay its tree onto its merge-base and ask whether that patch is already upstream:

```bash
mb=$(git merge-base origin/<base> <branch>)
synthetic=$(git commit-tree "$(git rev-parse <branch>^{tree})" -p "$mb" -m _)
git cherry origin/<base> "$synthetic"
```
`git cherry` prints `- <sha>` when an equivalent patch is already in the base (→ **`merged`, squashed**) and `+ <sha>` when it isn't (→ fall through). The synthetic commit is a dangling object that costs nothing and disappears at the next `gc`.

**(d) Nothing of its own** — `git rev-list --count origin/<base>..<branch>` is `0`: the branch never diverged, so there's nothing to lose → **`empty`**.

**(e) Otherwise** → **`unknown`**. Unmerged work, or work the evidence can't place. Reported, never touched.

Degraded mode: with no forge and no successful fetch, (b)–(d) are judging against a possibly stale `origin/<base>`. Keep the verdicts but mark the whole table `(local evidence only — origin not refreshed)`, and drop `merged, squashed` to `unknown`; the squash check is the one that most needs a current base.

## 5. The protected set

Before anything can be a candidate, it must survive all of these. Each is a hard exclusion, not a warning:

| Protected | Why |
|---|---|
| The **current branch** and the **main checkout** | You're standing on it |
| `<base>` and any long-lived branch (`main`, `master`, `develop`, `staging`, `production`, `release/*`, or whatever the forge reports as protected) | Never candidates, whatever the verdict |
| A worktree with **uncommitted or staged changes** (`git -C <wt> status --porcelain` non-empty) | Unsaved work, and removing it would need `--force` |
| A branch with **commits not on the remote** (`git log --oneline @{u}..HEAD`, or `origin/<base>..<branch>` when there's no upstream) and verdict ≠ `merged` | Exists only here |
| Verdict `open` | The MR/PR is live; the branch is in use |
| Verdict `unknown` | See §0 — unclear evidence isn't permission |
| A work folder whose `phase` is neither `done` nor `abandoned`, unless §6.C's reconciliation applies | Work in flight |
| Anything under `.claude/work/` — as **deletion** | This command archives folders; it never deletes them |

A `merged` branch whose worktree is dirty is a real case and deserves its own line in the report: the MR/PR went in, but there are edits in that checkout that never left it. Say so and leave it alone — that's a decision for the user, not a leftover.

## 6. Show the sweep

Group by what the action would be, most consequential first. Keep it scannable: one line per row, no prose between them.

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
   spike-cache-layer                no MR/PR, 4 commits not on the remote
   .worktrees/PROJ-1090-stale       directory not registered as a worktree

_archive: <N> folders (<size>) — untouched; see --purge-archive
```

Every row carries **why** it is there — `merged #412`, `merged #401 (squashed)`, `never diverged` for the `empty` verdict — because the reason is what the user is actually approving. A row printed without one is a bug in this step, not a shorthand.

Rows marked `⚠ needs your call` in **C** are the *settled but not closed out* case: `phase` isn't `done`, yet every entry in `meta.json.mrs` is `merged` and the branch is gone or merged. Almost always this is a train whose last `ship` never ran, but it can also be a work whose final MR/PR was never planned. Never fold these into a bulk yes — confirm each one individually, and on confirmation set `phase = "done"` and `updated_at` before moving the folder, so the archived record isn't left claiming it's mid-build.

If every group is empty: say the repo is clean, in one line, and stop.

## 7. Confirm and execute

Ask once, in plain text, as a numbered choice: **(1) Everything · (2) Worktrees and branches only · (3) Work folders only · (4) Pick individually · (5) Nothing**. On *Pick individually*, walk the rows and collect the choices before executing any of them — a half-applied sweep is worse than none.

Then execute, in this order (it matters: a branch can't be deleted while a worktree holds it):

1. **Worktrees** — `git worktree remove <path>`. No `--force`, ever: §5 already excluded the dirty ones, so a failure here means something changed since the inventory. Stop that row, report it, continue with the rest.
2. **Branches** — `git branch -d <branch>` first. On a squash-merged branch git refuses, because it can't see the merge; only then use `git branch -D`, and only for rows whose verdict came from **the forge** (§4a) — never for a verdict inferred locally. Name the reason in the report: `-D (squash-merged, MR #401)`.
3. **Work folders** — `mv .claude/work/<dir> .claude/work/_archive/<dir>`, keeping the directory name, exactly as `/flow-work-abandon` §6 does. Never `rm`.
4. **Prune** — `git worktree prune`.

Never touch the remote. Deleting merged remote branches is the forge's job (most do it on merge), and a `git push --delete` from a cleanup sweep is a blast radius this command has no business having.

If a step fails, report that row as failed with the git error verbatim and keep going. Never retry with a stronger flag.

## 8. `--purge-archive <N>d` (opt-in, separate)

`.claude/work/_archive/` accumulates for as long as the repo lives, and the sweep never touches it — that history is often the only record of why something was abandoned. This pass exists for when it has genuinely become noise.

Only for folders **archived more than `<N>` days ago** (newest `updated_at` in `meta.json`, falling back to the directory mtime) **and fully committed to git** — verified per folder:

```bash
git ls-files --error-unmatch <dir> >/dev/null   # tracked?
git status --porcelain <dir>                    # and no local modifications?
```
A folder that's tracked and clean exists in history; deleting it from the working tree loses nothing, and `git log -- <path>` brings it back. A folder that's **untracked** (`.claude/work/` is git-ignored in many repos) is the only copy there is — exclude it, list it separately, and say plainly that purging it would be permanent.

Show the list with sizes, confirm as in §7, then `rm -rf` only the tracked-and-clean ones. Report how many were purged and how many were kept for being untracked.

## 9. Report

State first, then the numbers:

```
<repo> · swept · <N> removed, <N> archived, <N> left alone
Worktrees removed:  <N>   (<disk freed>)
Branches deleted:   <N>
Folders archived:   <N>
Failed:             <N>   (<row>: <error>)
```

Then, at most three lines of body, and only what could change a decision: rows that failed, rows left alone for a reason the user can act on (a dirty merged worktree, an unpushed branch), and the untracked-archive note if §8 ran. Everything else was already in the §6 table — don't print it twice.

## Notes

- **Read the forge, not the calendar.** A worktree isn't stale because it's old; it's stale because its MR/PR merged. Age isn't evidence and this command never uses it — except in §8, where the entry is already archived and already in git.
- **`/flow-work-status` §4 and `/flow-work-daily` §4 surface the same residue** as a count and point here. This command is where it's acted on; they never delete.
- **It doesn't advance `meta.json.phase`** — except for the individually confirmed reconciliation in §6.C, which sets `done` on a work whose MRs/PRs all merged.
- **Safe to run often.** With `--dry-run` it's read-only, and a clean repo produces one line.
