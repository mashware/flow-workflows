---
description: Start a bug flow (tracker, domain-memory, size, branch, initial artifact)
---

# `/flow-bug-start $ARGUMENTS`

Start a bug. `$ARGUMENTS` is the ticket (format `tracker.prefix` from FLOW.md; empty = free-form). If empty, ask for it and stop.

## 0. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Verify you're in the correct repo.
- If `.claude/work/$ARGUMENTS/meta.json` exists, suggest `/flow-work-resume`.

## 1. Gather context

In parallel:

1. **Tracker**: read it using `tracker.view_cmd` from FLOW.md (replace `{TICKET}` with `$ARGUMENTS`). If `tool:none` or the key is missing, ask the user for the symptom, severity, and environment.
2. **domain-memory** (if `domain_memory.enabled`): call `search_knowledge` with keywords from the symptom. Useful for detecting prior postmortems in the same area.
3. **Observability** if the incident is recent: if you have clues (service, trace, log), consider using the `observability.platform` MCP tools from FLOW.md. If not, don't force it.
4. **Git**: check for a clean working tree and base commit.

## 2. Classify size

| Size | Criteria                                                       | Suggested phases                                    |
|------|----------------------------------------------------------------|-----------------------------------------------------|
| XS   | Obvious fix (typo, inverted condition, null check)             | start → fix → review → ship                         |
| S    | Clear symptom, reasonably scoped cause                         | start → diagnose → fix → review → validate → ship   |
| M    | Clear symptom but non-obvious cause, possible regression       | start → diagnose → investigate → fix → validate → review → postmortem |
| L    | Critical incident, multi-component, production affected        | full flow + mandatory postmortem                    |

## 3. Branch

Same two non-negotiable rules as `/flow-feat-start` §5 (breaking them already caused an accidental deployment):

1. **Explicit base**, never implicit from wherever you are. If you're on another task's branch, you'd inherit its commits.
2. **No upstream inheritance**: with `branch.autoSetupMerge=true` (team config), creating from `git.default_base` in FLOW.md without `--no-track` sets the upstream to that base, and a push could end up there.

```bash
git rev-parse --abbrev-ref HEAD && git status --porcelain   # where am I / clean tree
git fetch origin
git switch --create $ARGUMENTS-fix-slug --no-track <git.default_base>   # independent base; --no-track required
```

If the current branch is not the main base, ask the user for the base (`git.default_base` recommended, or stacked on top of the current one in train mode → record it as `stacked_on`). Create only after user confirmation. First push always `git push -u origin HEAD` (in `ship`), never to the main base.

**Worktree mode** (same as `/flow-feat-start` §5.0/§5.4): read `git.worktree` from FLOW.md. If `always` (or `ask` and the user chooses it), create the branch as a worktree instead of switching in place — `git worktree add --no-track -b <branch> <worktree-path> <git.default_base>`, path from `git.worktree_path` (empty → `.worktrees/<branch>`, git-ignore it). Don't `git switch`; the fix runs from the worktree (`cd <worktree-path>`). Record the resolved path in `meta.json.worktree`. If `off`/empty, in place as above and `worktree` is `null`.

## 4. Write artifacts

`.claude/work/$ARGUMENTS/meta.json`:
```json
{
  "ticket": "$ARGUMENTS",
  "type": "bug",
  "title": "<symptom from tracker>",
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
# Bug context {TICKET}

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
- Failed-queue workers (if applicable):

## Estimated size: <XS|S|M|L>
```

## 5. Wrap-up

Summarize and suggest the next command based on size (`/flow-bug-fix` for XS, `/flow-bug-diagnose` for the rest). Then apply the `autonomy.mode` from the preamble: `manual` stops and recommends; `guided`/`auto` chain into that command automatically, subject to the hard gates.
