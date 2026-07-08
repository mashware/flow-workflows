# `/flow-bug-postmortem`

**Only for `size` M/L** (optional for S, skipped for XS).

Goal: capture lessons that prevent recurrence — not to blame anyone.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`. Require `review` in `phases_done`.
- If `size` is `XS`, suggest jumping to `/flow-bug-ship`.

## 2. Work

Read all previous artifacts. Generate an honest analysis:

- **Timeline**: when it was introduced, when it was detected, how long it was active.
- **Root cause** (already in `03-investigation.md` — copy the summary).
- **Why tests didn't catch it**: a real gap, not excuses.
- **Why code review didn't catch it**: if applicable.
- **Actionable prevention actions** (not generic ones like "improve tests"). Each action with an owner and a suggested ticket.
- **Areas with similar risk**: as noted in `03-investigation.md`.

## 3. Output

`.claude/work/<TICKET>/99-postmortem.md`:

```markdown
# Postmortem {TICKET}

## Executive summary
<3-5 bullets: what happened, impact, cause, fix>

## Timeline
- <date>: <event>

## Root cause
<copy from investigation>

## Impact
- Affected users:
- Compromised data:
- Degraded services:

## Why it wasn't detected earlier
- Tests:
- Code review:
- Monitoring:

## Prevention actions
| Action | Owner | Suggested ticket |
|--------|-------|-----------------|

## Areas with similar risk (to open separate tickets)
- pattern to audit
```

## 4. Domain knowledge (offer)

If `domain_memory.enabled`:

1. **Read the staging accumulated during the branch**: call `mcp__domain-memory__read_staging`. There will be findings staged in `/flow-bug-investigate` if the root cause revealed something non-obvious. That's the primary material.
2. **Review the postmortem** for any additional "why" findings (business decisions, legal constraints, integrations, model assumptions that were false) that weren't staged. The "what" (code, routes) is not saved.
3. **Combine staging + new findings**. If the result is empty or only obvious things, don't insist.
4. If there are 1+ relevant findings, ask the user whether they want to save them. If yes, invoke the `/flow-save-knowledge` workflow with the right angle (the lesson, not the code). If no, don't insist.

If `domain_memory.enabled` is false or empty, skip this block without comment.

## 5. Close

- Update `meta.json`: `phase = "postmortem"`, add to `phases_done`.
- Suggest `/flow-bug-ship`. If prevention actions came out of the postmortem, propose opening separate tickets (not done in this workflow).
