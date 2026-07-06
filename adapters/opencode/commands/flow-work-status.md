---
description: Summary of the state of all open work items in .claude/work/
---

# `/flow-work-status`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Show an overview of work in progress and detect divergences between artifacts and actual git state.

## 1. List work items

- `ls -1 .claude/work/` (ignore `_archive`).
- For each folder matching the ticket pattern, read its `meta.json`.

## 2. For each work item, show

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
- If one is `in_progress`, show it explicitly with its number.
- If any are `closed` or `superseded`, also list the reason (truncated to 40 chars): `MR/PR #2 closed (reviewer asked for different approach)`.

### Actual progress vs estimate

**Only for the `in_progress` MR/PR and only if its branch matches the current one** (you can measure the diff). The base for the diff is read from `git.default_base` in FLOW.md; if empty, auto-discover the repo's base branch. Calculate:

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
- If **either** threshold is exceeded: add `⚠ exceeds estimate` and suggest that `/flow-feat-build` applies §2.2 (cut / continue / reopen).
- If `lines_est` does not exist in meta.json (work created before this improvement): do not show the line, do not invent an estimate.

## 3. Divergences with git

If the branch in meta.json **is the current one**:

- `git diff --name-only <base>...HEAD | wc -l` → files changed in the branch.
- Read `04-implementation.md` or `04-fix.md` and extract the files listed.
- If there are files changed in git that do not appear in the log, show:
  ```
  ⚠ Divergence: <N> files changed but not recorded in the log.
     Examples: <path>, <path>…
  ```
- If there are files in the log that have no actual changes in git, do the same.

## 4. Orphaned work items

- If there are local branches matching the ticket pattern with no `.claude/work/<TICKET>/` folder: report it.
- If there are `.claude/work/<TICKET>/` folders whose branch no longer exists locally: ask whether to archive.

The branch pattern is inferred from `git.branch_pattern` in FLOW.md; if empty, look for branches whose name matches the pattern `<prefix>XXXXX-*` or orphaned `.claude/work/` folders.

## 5. Quick actions

At the end, if there is a work item whose branch matches the current one, suggest:
- If `phase = "done"`: nothing to do, offer to archive.
- If `phase = "abandoned"`: the folder should already be in `_archive/`; if it is in the root, suggest moving it.
- If there is an `in_progress` MR/PR waiting for merge confirmation: indicate that `/flow-feat-ship` should update the status.
- If there is a `closed` MR/PR with no subsequent decision: warn the user to decide (retry the build or abandon).
- Otherwise: the specific next command.
