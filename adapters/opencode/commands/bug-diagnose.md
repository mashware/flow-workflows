---
description: Reproduce the failure and pinpoint exactly what is broken
---

# `/bug-diagnose`

Diagnosis phase: isolate **what** is failing before looking for **why**.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user.

- Load `meta.json`. If `type` is not `bug`, refuse.
- If `size` is `XS`, suggest skipping to `/bug-fix` and stop.
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled`, call `mcp__domain-memory__search_knowledge` with queries about the **suspected component** (handler, worker, endpoint, module). Prior postmortems in the same area often exist and can save hours — the same root cause may have appeared under a different symptom.

Examples:
- Failed queue → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <path>"`, `"validation <DTO>"`.
- Frontend → `"<component>"`, `"<flow-name>"`.

2-3 queries in parallel. Max wait 2 s; continue if it fails. Record relevant findings in the artifact under "Prior domain knowledge".

## 3. Work

Goal: produce a minimal reproducible case and delimit the affected components.

Steps:

1. **If it's a failed queue / messaging**: invoke the subagent your project has for analyzing dead-letter messages if one exists; if not, inspect the message payload and headers to locate the handler, retry history, and initial cause.
2. **If it's API/HTTP**: identify the endpoint, capture a reproducible curl or request, verify expected vs actual response.
3. **If it's frontend**: identify the component, route, reproduction steps, browser devtools (console, network).
4. **If it's a worker/consumer**: identify the job type, source message, supervisor logs (use `quality.test_one` or the equivalent observability command from FLOW.md filtered by worker type).
5. **If it's DB**: identify the problematic query, execution plan (`EXPLAIN`), input data that triggers the failure.

Use a general-purpose subagent to locate the relevant code. Pass a self-contained prompt with the symptom and initial clues.

## 4. Output

`.claude/work/<TICKET>/02-diagnose.md`:

```markdown
# Diagnosis {TICKET}

## Prior domain knowledge
<findings from the focused search_knowledge, or "no findings">

## Minimal reproduction
<numbered steps that reproduce the failure>

## Expected vs actual behavior
- Expected:
- Actual:

## Implicated components
- Suspected files: (not asserting the cause yet)
- Services: backend / worker / frontend / DB

## Failure data
- Stack trace / log:
- Request / payload:
- Input data that triggers it:

## Initial hypotheses
1. …
2. …
```

## 5. Is the size still correct?

If the diagnosis reveals the failure is trivial (a null check, a typo) and it was classified as M/L out of uncertainty, propose reclassifying to XS/S. Conversely: if what appeared to be XS turns out to affect multiple components, raise the size. Confirm with the user before changing `meta.json.size`.

## 6. Wrap-up

- Update `meta.json`: `phase = "diagnose"`, add to `phases_done`.
- Suggest next step: `/bug-investigate` (M/L) or `/bug-fix` (S if the cause is evident).
