---
description: Summary of all open works in .claude/work/
---

# `/work:status`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as indicated by each step. Regarding `domain_memory`: if active but the MCP fails or takes more than 2s, continue without that context — do not block or notify the user.

Shows an overview of works in progress and detects divergences between artifacts and actual git state.

## 1. List works

- `ls -1 .claude/work/` (ignore `_archive`).
- For each folder matching the ticket pattern, read its `meta.json`.

## 2. For each work, display

```
<TICKET> [feat|bug] [XS|S|M|L]  ⏵ <current phase>
  Branch:      <branch>           [✓ active | ⚠ not current]
  Started:     <date>
  Updated:     <date>
  Phases done: context, design, build…
  MR/PRs:      2/4 merged · MR/PR #3 in_progress · MR/PR #4 pending
  Next:        <suggested next command>
```

The term "MR" or "PR" is read from `git.request_term` in FLOW.md; if empty, use "MR/PR".

The `MR/PRs:` line is only printed if `meta.json.mrs` exists and has >0 entries. Format:
- Summary: `<merged>/<total> merged`.
- If there are `closed` or `superseded` MR/PRs, add to the count: `2/4 merged · 1 closed · 1 pending`.
- If there is one `in_progress`, show it explicitly with its number.
- If there are any `closed` or `superseded`, also list the reason (truncated to 40 chars): `MR/PR #2 closed (reviewer requested different approach)`.

### Actual progress vs estimate

**Only for the `in_progress` MR/PR and only if the branch matches the current one** (you can measure the diff). The diff base is read from `git.default_base` in FLOW.md; if empty, auto-discover the repo's base branch. Calculate:

```bash
git diff --shortstat <base>..HEAD          # lines
git diff --name-only <base>..HEAD | wc -l  # files
```

Compare with `mrs[in_progress].lines_est` and `files_est` and show a line below `MR/PRs:`:

```
  Current MR/PR size: 180/120 lines (150%) · 7/6 files     ⚠ exceeds estimate
```

Rules:
- If lines ≤ `lines_est * 1.5` **and** files ≤ `files_est + 2`: show without warning, in grey.
- If **either** threshold is exceeded: add `⚠ exceeds estimate` and suggest that `/feat:build` applies §2.2 (cut / continue / reopen).
- If `lines_est` does not exist in meta.json (work created before this improvement): do not show the line, do not invent an estimate.

## 3. Divergences with git

If the branch in meta.json **is the current one**:

- `git diff --name-only <base>...HEAD | wc -l` → files changed on the branch.
- Read `04-implementation.md` or `04-fix.md` and extract the listed files.
- If there are files changed in git that do not appear in the log, show:
  ```
  ⚠ Divergence: <N> changed files not recorded in log.
     Examples: <path>, <path>…
  ```
- If there are files in the log that have no actual changes in git, same.

## 4. Orphaned works

- If there are local branches with the ticket pattern but no `.claude/work/<TICKET>` folder: warn about it.
- If there are `.claude/work/<TICKET>` folders whose branch no longer exists locally: ask whether to archive.

The branch pattern is inferred from `git.branch_pattern` in FLOW.md; if empty, look for branches whose name matches the pattern `<prefix>XXXXX-*` or orphaned folders in `.claude/work/`.

## 5. Quick actions

At the end, if there is a work whose branch matches the current one, suggest:
- If `phase = "done"`: nothing to do, offer to archive.
- If `phase = "abandoned"`: the folder should already be in `_archive/`; if it is at the root, suggest moving it.
- If there is an `in_progress` MR/PR waiting for merge confirmation: indicate that `/feat:ship` should update the state.
- If there is a `closed` MR/PR with no subsequent decision: warn so the user can decide (retry build or abandon).
- Otherwise: the concrete next command.
