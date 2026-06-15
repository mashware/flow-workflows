---
description: Lessons learned, areas to watch, and offer to save to domain-memory
---

# `/flow:bug:postmortem`

**Only for `size` M/L** (optional for S, skip for XS).

Goal: capture lessons that prevent recurrence — not to blame anyone.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Load `meta.json`. Require `review` in `phases_done`.
- If `size` is `XS`, suggest skipping to `/flow:bug:ship`.

## 2. Work

Read all previous artifacts. Produce an honest analysis:

- **Timeline**: when it was introduced, when it was detected, how long it was active.
- **Root cause** (already in `03-investigation.md` — copy the summary).
- **Why tests did not catch it**: a real gap, not excuses.
- **Why code review did not catch it**: if applicable.
- **Actionable prevention measures** (not generic ones like "improve tests"). Each action with an owner and a suggested ticket.
- **Areas with similar risk**: those noted in `03-investigation.md`.

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

## Why it was not detected earlier
- Tests:
- Code review:
- Monitoring:

## Prevention actions
| Action | Owner | Suggested ticket |
|--------|-------|-----------------|

## Areas with similar risk (open separate tickets)
- pattern to audit
```

## 4. Domain knowledge (offer)

If `domain_memory.enabled`:

1. **Read the staging accumulated during the branch**: call `mcp__domain-memory__read_staging`. There will be findings staged in `/flow:bug:investigate` if the root cause revealed something non-obvious. That is the primary material.
2. **Review the postmortem** for any additional "why" items (business decisions, legal constraints, integrations, model assumptions that were false) that were not staged at the time. The "what" (code, paths) is not saved.
3. **Combine staging + new findings**. If the result is empty or only obvious things, do not insist.
4. If there are 1+ relevant findings, ask the user whether to save them. If yes, invoke `Skill save-knowledge` with the right angle (the lesson, not the code). If no, do not insist.

If `domain_memory.enabled` is false or empty, skip this block without saying anything.

## 5. Close

- Update `meta.json`: `phase = "postmortem"`, add to `phases_done`.
- Suggest `/flow:bug:ship`. If the postmortem surfaced prevention actions, propose opening separate tickets (not done in this flow).
