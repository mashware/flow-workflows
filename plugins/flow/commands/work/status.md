---
description: Summary of all open works in .claude/work/
---

# `/flow:work:status`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as indicated by each step. Regarding `domain_memory`: if active but the MCP fails or takes more than 2s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Shows an overview of works in progress and detects divergences between artifacts and actual git state.

## 1. List works

- `ls -1 .claude/work/` (ignore `_archive`).
- Read the `meta.json` of **every** folder (folders are now named `<TICKET>-<slug>` or, for ticket-less/local works, `<slug>`; older ones are just `<TICKET>`). Identify each work by its `meta.json.ticket`, not by the folder name.

## 2. For each work, display

```
<TICKET> — <title> [feat|bug] [XS|S|M|L]  ⏵ <current phase>
  Branch:      <branch>           [✓ active | ⚠ not current]
  Started:     <date>
  Updated:     <date>
  Phases done: context, design, build…
  MR/PRs:      2/4 merged · MR/PR #3 in_progress · MR/PR #4 pending
  Cross-repo:  <meta.related_repos entries not "done", as "repo: scope">   (line only if any)
  Next:        <suggested next command>
```

The term "MR" or "PR" is read from `git.request_term` in FLOW.md; if empty, use "MR/PR".

The `Cross-repo:` line is only printed if `meta.json.related_repos` has entries not `done`; show each as `<repo>: <scope>`. It flags that a **sibling repo still has a pending part** of this task. flow only surfaces what's recorded — it never scans or touches the other repo.

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
- If **either** threshold is exceeded: add `⚠ exceeds estimate` and suggest that `/flow:feat:build` applies §2.2 (cut / continue / reopen).
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

- If there are local branches with the ticket pattern but no matching work folder (`.claude/work/<TICKET>/` or `.claude/work/<TICKET>-*/`, matched via `meta.json.ticket`/`branch`): warn about it.
- If there are work folders whose branch no longer exists locally: ask whether to archive.

The branch pattern is inferred from `git.branch_pattern` in FLOW.md; if empty, look for branches whose name matches the pattern `<prefix>XXXXX-*` or orphaned folders in `.claude/work/`.

## 5. Quick actions

At the end, if there is a work whose branch matches the current one, suggest:
- If `phase = "done"`: nothing to do, offer to archive.
- If `phase = "abandoned"`: the folder should already be in `_archive/`; if it is at the root, suggest moving it.
- If there is an `in_progress` MR/PR waiting for merge confirmation: indicate that `/flow:feat:ship` should update the state.
- If there is a `closed` MR/PR with no subsequent decision: warn so the user can decide (retry build or abandon).
- Otherwise: the concrete next command.
