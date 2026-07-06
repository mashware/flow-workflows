# `/flow-bug-start $ARGUMENTS`

Start a bug. `$ARGUMENTS` is the ticket (format `tracker.prefix` from FLOW.md; empty = free-form). If empty, ask for it and stop.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Verify you're in the correct repo.
- If `.claude/work/$ARGUMENTS/meta.json` exists, suggest `/flow-work-resume`.

## 1. Gather context

In parallel:

1. **Tracker**: read it using `tracker.view_cmd` from FLOW.md (substitute `{TICKET}` with `$ARGUMENTS`). If `tool:none` or the key is missing, ask the user for the symptom, severity, and environment.
2. **domain-memory** (if `domain_memory.enabled`): `search_knowledge` with keywords from the symptom. Important for detecting whether there have been previous postmortems in the same area.
3. **Observability** if the incident is recent: if you have clues (service, trace, log), consider using the `observability.platform` MCP tools from FLOW.md. If not, don't force it.
4. **Git**: check for a clean branch and the base commit.

## 2. Classify size

| Size | Criteria                                                  | Suggested phases                              |
|------|-----------------------------------------------------------|-----------------------------------------------|
| XS   | Obvious fix (typo, inverted condition, null check)        | start → fix → review → ship                   |
| S    | Clear symptom, reasonably bounded cause                   | start → diagnose → fix → review → validate → ship |
| M    | Clear symptom but non-obvious cause, possible regression  | start → diagnose → investigate → fix → validate → review → postmortem |
| L    | Critical incident, multi-component, production affected   | full flow + mandatory postmortem               |

## 3. Branch

Same two non-negotiable rules as in `/flow-feat-start` §5 (breaking them already caused an accidental deployment):

1. **Explicit base**, never implicit from where you are. If you're on another task's branch, you'd inherit its commits.
2. **No inherited upstream**: with `branch.autoSetupMerge=true`, creating from `git.default_base` from FLOW.md without `--no-track` leaves the upstream on that base and a push can end up there.

```bash
git rev-parse --abbrev-ref HEAD && git status --porcelain   # where am I / clean tree
git fetch origin
git switch --create $ARGUMENTS-fix-slug --no-track <git.default_base>   # independent base; --no-track mandatory
```

If the current branch is not the main base, ask the user for the base (`git.default_base` recommended, or stacked on the current one in train mode → note it as `stacked_on`). Create only if the user confirms. First push always `git push -u origin HEAD` (in `ship`), never to the main base.

**Worktree mode** (same as `/flow-feat-start` §5.0/§5.4): read `git.worktree` from FLOW.md. If `always` (or `ask` and the user picks it), create the branch as a worktree instead of switching in place — `git worktree add --no-track -b <branch> <worktree-path> <git.default_base>`, path from `git.worktree_path` (empty → `.worktrees/<branch>`, git-ignore it). Don't `git switch`; the fix runs from the worktree (`cd <worktree-path>`). Record the resolved path in `meta.json.worktree`. If `off`/empty, in place as above and `worktree` is `null`.

## 4. Write artifacts

`.claude/work/$ARGUMENTS/meta.json`:
```json
{
  "ticket": "$ARGUMENTS",
  "type": "bug",
  "title": "<symptom from the tracker>",
  "branch": "<branch created in §3>",
  "stacked_on": null,
  "worktree": "<worktree path if created in §3, else null>",
  "size": "<XS|S|M|L>",
  "phase": "context",
  "phases_done": ["context"],
  "started_at": "...",
  "updated_at": "...",
  "notes": ""
}
```

`.claude/work/$ARGUMENTS/01-context.md`:
```markdown
# Context bug {TICKET}

## Reported symptom
<what the reporter said>

## Tracker data
- Severity / priority:
- Affected environment:
- Reporter:
- Date first reported:

## Prior knowledge (domain-memory)
<findings or "no findings">

## Initial clues
- Known stack trace / log:
- Observability trace (if any):
- Workers in failure queue (if applicable):

## Estimated size: <XS|S|M|L>
```

## 5. Close

Summarize and suggest the next command based on size (`/flow-bug-fix` for XS, `/flow-bug-diagnose` for the rest). Don't advance automatically.
