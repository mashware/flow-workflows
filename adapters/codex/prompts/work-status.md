# `/work-status`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user.

Shows an overview of work in progress and detects divergences between artifacts and actual git state.

## 1. List work items

- `ls -1 .claude/work/` (ignore `_archive`).
- For each folder matching the ticket pattern, read its `meta.json`.

## 2. For each work item, show

```
<TICKET> [feat|bug] [XS|S|M|L]  ⏵ <current phase>
  Branch:      <branch>           [✓ active | ⚠ not the current]
  Started:     <date>
  Updated:     <date>
  Phases done: context, design, build…
  MR/PRs:      2/4 merged · MR/PR #3 in_progress · MR/PR #4 pending
  Next:        <suggested next command>
```

The term "MR" or "PR" is read from `git.request_term` in FLOW.md; if empty, use "MR/PR".

The `MR/PRs:` line is only printed if `meta.json.mrs` exists and has >0 entries. Format:
- Summary: `<merged>/<total> merged`.
- If there are `closed` or `superseded` MRs/PRs, add to the count.
- If there's one `in_progress`, show it explicitly with its number.
- If there are any `closed` or `superseded`, list their reason too (truncated to 40 chars).

### Actual progress vs estimate

**Only for the `in_progress` MR/PR and only if the branch matches the current one**. The base for the diff is read from `git.default_base` in FLOW.md; if empty, auto-discover the repo's base branch. Calculate:

```bash
git diff --shortstat <base>..HEAD
git diff --name-only <base>..HEAD | wc -l
```

Compare with `mrs[in_progress].lines_est` and `files_est` and show:

```
  Actual MR/PR size: 180/120 lines (150%) · 7/6 files     ⚠ exceeds estimate
```

Rules:
- If lines ≤ `lines_est * 1.5` **and** files ≤ `files_est + 2`: show without warning.
- If **either** threshold is exceeded: add `⚠ exceeds estimate` and suggest that `/feat-build` apply §2.2 (cut / continue / reopen).

## 3. Divergences with git

If the branch in meta.json **is the current one**:

- `git diff --name-only <base>...HEAD | wc -l` → files changed on the branch.
- Read `04-implementation.md` or `04-fix.md` and extract the files listed.
- If there are files changed in git that don't appear in the log:
  ```
  ⚠ Divergence: <N> files changed but not recorded in the log.
     Examples: <path>, <path>…
  ```

## 4. Orphaned work items

- If there are local branches matching the ticket pattern without a `.claude/work/<TICKET>` folder: flag it.
- If there are `.claude/work/<TICKET>` folders whose branch no longer exists locally: ask whether to archive.

The branch pattern is inferred from `git.branch_pattern` in FLOW.md; if empty, look for branches whose name matches the pattern `<prefix>XXXXX-*`.

## 5. Quick actions

At the end, if there's a work item whose branch matches the current one, suggest:
- If `phase = "done"`: nothing to do, offer to archive.
- If `phase = "abandoned"`: the folder should already be in `_archive/`; if it's at the root, suggest moving it.
- If there's an `in_progress` MR/PR waiting for merge confirmation: indicate that `/feat-ship` should update the status.
- If there's a `closed` MR/PR with no subsequent decision: warn the user to decide.
- Otherwise: the specific next command.
