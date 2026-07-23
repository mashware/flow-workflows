# `/flow-work-status`

**Step 0**: read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

Shows an overview of work in progress and detects divergences between artifacts and actual git state.

## 1. List work items

- `ls -1 .claude/work/` (ignore `_archive`).
- Read the `meta.json` of **every** folder (folders are now named `<TICKET>-<slug>` or, for ticket-less/local works, `<slug>`; older ones are just `<TICKET>`). Identify each work by its `meta.json.ticket`, not by the folder name.

## 2. For each work item, show

```
<TICKET> — <title> [feat|bug] [XS|S|M|L]  ⏵ <current phase>
  Branch:      <branch>           [✓ active | ⚠ not the current]
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
- If **either** threshold is exceeded: add `⚠ exceeds estimate` and suggest that `/flow-feat-build` apply §2.2 (cut / continue / reopen).

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

- If there are local branches with the ticket pattern but no matching work folder (`.claude/work/<TICKET>/` or `.claude/work/<TICKET>-*/`, matched via `meta.json.ticket`/`branch`): flag it.
- If there are work folders whose branch no longer exists locally: ask whether to archive.

The branch pattern is inferred from `git.branch_pattern` in FLOW.md; if empty, look for branches whose name matches the pattern `<prefix>XXXXX-*`.

## 5. Quick actions

At the end, if there's a work item whose branch matches the current one, suggest:
- If `phase = "done"`: nothing to do, offer to archive.
- If `phase = "abandoned"`: the folder should already be in `_archive/`; if it's at the root, suggest moving it.
- If there's an `in_progress` MR/PR waiting for merge confirmation: indicate that `/flow-feat-ship` should update the status.
- If there's a `closed` MR/PR with no subsequent decision: warn the user to decide.
- Otherwise: the specific next command.
