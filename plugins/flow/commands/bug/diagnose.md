---
description: Reproduce the bug and pinpoint exactly what is broken
---

# `/flow:bug:diagnose`

Diagnosis phase: isolate **what** is failing before looking for **why**.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

- Load `meta.json`. If `type` is not `bug`, refuse.
- If `size` is `XS`, suggest skipping to `/flow:bug:fix` and stop.
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled`, call `mcp__domain-memory__search_knowledge` with queries about the **suspected component** (handler, worker, endpoint, module). Previous postmortems from the same area often save hours: the same root cause may have appeared under a different symptom.

Examples:
- Dead-letter queue → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <path>"`, `"validation <DTO>"`.
- Frontend → `"<component>"`, `"<flow-name>"`.

2-3 queries in parallel. Maximum wait 2 s; continue on failure. Record relevant findings in the artifact under "Prior domain knowledge".

## 3. Work

Goal: produce a minimal reproducible case and delimit the affected components.

Steps:

1. **Dead-letter queue / messaging**: invoke your project's agent for analyzing dead messages, if one exists; otherwise inspect the message payload and headers to locate the handler, retry history, and initial cause.
2. **API/HTTP**: identify the endpoint, collect a reproducible curl or request, verify the expected response vs. the actual one.
3. **Frontend**: identify the component, route, steps to reproduce, browser developer tools (console, network).
4. **Worker/consumer**: identify the job type, source message, supervisor logs (use `quality.test_one` or the observability command from FLOW.md to filter by worker type).
5. **Database**: failing query, execution plan (`EXPLAIN`), input data that triggers the bug.

Use `Agent general-purpose` to locate the relevant code. Pass a self-contained prompt with the symptom and the initial clues.

## 4. Output

`.claude/work/<TICKET>/02-diagnose.md`:

```markdown
# Diagnosis {TICKET}

## Prior domain knowledge
<findings from the focused search_knowledge, or "no findings">

## Minimal reproduction
<numbered steps that reproduce the bug>

## Expected vs actual behavior
- Expected:
- Actual:

## Involved components
- Suspected files: (not asserting the cause yet)
- Services: backend / worker / frontend / DB

## Bug data
- Stack trace / log:
- Request / payload:
- Input data that triggers it:

## Initial hypotheses
1. …
2. …
```

## 5. Is the size still correct?

If the diagnosis reveals the bug is trivial (a null check, a typo) and was classified M/L due to uncertainty, propose reclassifying to XS/S. Conversely, if what looked like XS turns out to affect several components, raise the size. Confirm with `AskUserQuestion` before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "diagnose"`, add to `phases_done`.
- Suggest next: `/flow:bug:investigate` (M/L) or `/flow:bug:fix` (S if the cause is evident).
