---
description: Summary of all open works in .claude/work/
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(ls:*), Bash(cat:*)
---

# `/flow:work:status`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, autonomy, how a stop reads, `panel.json`, `00-summary.md`) — skip if it is already in this session's context.

Overview of works in progress; detects divergences between artifacts and actual git state.

## 1. List works

- `ls -1 .claude/work/` (ignore `_archive`).
- **Then `_archive/*/meta.json` for `followups[]` alone** — entries not `declined`/`done` (§5). Nothing else about an archived work is shown; a finished work is exactly when its deferred items stop being visible, which is the point of reading them here.
- Read the `meta.json` of **every** folder (named `<TICKET>-<slug>`, `<slug>` for ticket-less/local works, or just `<TICKET>` for older ones). Identify each work by `meta.json.ticket`, not by the folder name.
- Read `00-summary.md` per work when it exists and use it for the recap (`Next:` line, what is pending) instead of reading every artifact (flow-core §5); missing → fall back to the artifacts.

## 2. For each work, display

```
<TICKET> — <title> [feat|bug] [XS|S|M|L]  ⏵ <current phase>
  Branch:      <branch>           [✓ active | ⚠ not current]
  Started:     <date>
  Updated:     <date>
  Phases done: context, design, build…
  MR/PRs:      2/4 merged · MR/PR #3 in_progress · MR/PR #4 pending
  Cross-repo:  <meta.related_repos entries not "done", as "repo: scope">   (line only if any)
  Follow-ups:  2 awaiting a decision · 1 accepted, not started            (line only if any)
  Next:        <suggested next command>
```

- "MR"/"PR" from `git.request_term` in FLOW.md; empty → "MR/PR".
- `Cross-repo:` only when `meta.json.related_repos` has entries not `done`: each as `<repo>: <scope>`, appending ` — contract not handed over` when that entry's `contract_handoff` is `pending`. It flags that a **sibling repo still has a pending part**; flow never scans or touches the other repo.
- `Follow-ups:` only when `meta.json.followups[]` has entries not `declined`/`done` (flow-core §7): count the `proposed` ones as *awaiting a decision* and the `accepted` ones without a `work` as *accepted, not started*, naming the ticket id when there is one. `in_progress` entries are already visible as their own work — do not double-count them.
- `MR/PRs:` only when `meta.json.mrs` exists with >0 entries:
  - Summary: `<merged>/<total> merged`.
  - `closed` or `superseded` MR/PRs present → add to the count: `2/4 merged · 1 closed · 1 pending`.
  - One `in_progress` → show it explicitly with its number.
  - Any `closed`/`superseded` → list the reason (truncated to 40 chars): `MR/PR #2 closed (reviewer requested different approach)`.

### Actual progress vs estimate

**Only for the `in_progress` MR/PR and only if the branch matches the current one** (you can measure the diff). Base = `git.default_base` in FLOW.md; empty → auto-discover the repo's base branch. Calculate:

```bash
git diff --shortstat <base>..HEAD          # lines
git diff --name-only <base>..HEAD | wc -l  # files
```

Compare with `mrs[in_progress].lines_est` and `files_est`; show a line below `MR/PRs:`:

```
  Current MR/PR size: 180/120 lines (150%) · 7/6 files     ⚠ exceeds estimate
```

Rules:
- lines ≤ `lines_est * 1.5` **and** files ≤ `files_est + 2` → show without warning, in grey.
- **Either** threshold exceeded → add `⚠ exceeds estimate` and suggest that `/flow:feat:build` applies §2.3 (the size thermometer: cut / continue / reopen).
- No `lines_est` in meta.json (older work) → do not show the line, do not invent an estimate.

## 3. Divergences with git

Only if the branch in meta.json **is the current one**:

- `git diff --name-only <base>...HEAD | wc -l` → files changed on the branch.
- Read `05-implementation.md` (features) or `04-fix.md` (bugs); extract the listed files.
- Files changed in git that do not appear in the log:
  ```
  ⚠ Divergence: <N> changed files not recorded in log.
     Examples: <path>, <path>…
  ```
- Files in the log with no actual change in git → same.

## 4. Orphaned works

- Local branches matching the ticket pattern with no work folder (`.claude/work/<TICKET>/` or `.claude/work/<TICKET>-*/`, matched via `meta.json.ticket`/`branch`) → warn.
- Work folders whose branch no longer exists locally → ask whether to archive.
- **Residue count** (one line, no per-entry detail): worktrees registered (`git worktree list`, minus the main checkout), work folders with `phase: done` still outside `_archive/`, and prunable registrations (`git worktree prune --dry-run`). Total above a handful → `Residue: <N> worktrees · <N> unarchived done · <N> prunable → /flow:work:clean --dry-run`. This command never deletes anything — `clean` establishes the merged/open verdict and acts.
- Branch pattern from `git.branch_pattern` in FLOW.md; empty → branches matching `<prefix>XXXXX-*` or orphaned folders in `.claude/work/`.

## 5. Open follow-ups (live works and `_archive/`)

One block at the end, only when there is anything to show. Deferred work outlives the work that
deferred it, and `_archive/` is where it goes to be forgotten:

```
Follow-ups awaiting a decision
  PROJ-123 F2  audit the other three callers of the same helper       (archived work)
  PROJ-140 F1  index on events.created_at — plan says full scan       → PROJ-155
```

- Source: `followups[]` of every `meta.json`, live folders **and** `_archive/`, entries not
  `declined`/`done`. Show the originating ticket, the id, the `title`, and the created ticket when
  `ticket` is set. Mark archived origins so it is clear the work itself is finished.
- `proposed` entries are listed under *awaiting a decision*; `accepted` ones without a `work` under
  *accepted, not started*. Suggest `/flow:feat:start <ticket>` for the latter.
- More than about eight → show the newest five and the total. This command is read-only: it never
  triages, creates a ticket, or edits `followups[]`. That happens once, at `ship` (flow-core §7).

## 6. Quick actions

If a work's branch matches the current one, suggest:
- `phase = "done"` → nothing to do; offer to archive.
- `phase = "abandoned"` → the folder should already be in `_archive/`; at the root → suggest moving it.
- An `in_progress` MR/PR waiting for merge confirmation → `/flow:feat:ship` should update the state.
- A `closed` MR/PR with no subsequent decision → warn so the user can decide (retry build or abandon).
- Otherwise → the concrete next command.
