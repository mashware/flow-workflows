# `/flow-bug-diagnose`

Diagnosis phase: isolate **what** is failing before looking for **why**.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`. If `type` is not `bug`, refuse.
- If `size` is `XS`, suggest jumping to `/flow-bug-fix` and stop.
- Read `01-context.md`.

## 2. Focused domain-memory query

If `domain_memory.enabled`, call `mcp__domain-memory__search_knowledge` with queries about the **suspected component** (handler, worker, endpoint, module). Previous postmortems in the same area often save hours.

Examples:
- Failure queue → `"DLX <handler-name>"`, `"retry policy worker"`.
- Endpoint → `"endpoint <route>"`, `"validation <DTO>"`.
- Frontend → `"<component>"`, `"<flow-name>"`.

2-3 queries in parallel. Maximum wait time 2s; if it fails, continue. Relevant findings go into the artifact under "Prior domain knowledge".

## 3. Work

Goal: produce a minimal reproducible case and delimit the affected components.

Steps:

1. **If it's a failure queue / messaging**: inspect the message payload and headers to locate the handler, retry history, and initial cause.
2. **If it's API/HTTP**: identify the endpoint, collect a reproducible curl or request, verify the expected response against the actual one.
3. **If it's frontend**: identify the component, route, steps to reproduce, browser tools (console, network).
4. **If it's a worker/consumer**: identify the job type, source message, supervisor logs.
5. **If it's DB**: problematic query, execution plan (`EXPLAIN`), input data that triggers the failure.

Use a general subagent to locate the relevant code. Pass a self-contained prompt with the symptom and initial clues.

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
- Suspicious files: (without asserting the cause yet)
- Services: backend / worker / frontend / DB

## Failure data
- Stack trace / log:
- Request / payload:
- Input data that triggers it:

## Initial hypotheses
1. …
2. …
```

## 5. Is the size still right?

If the diagnosis reveals the failure is trivial, propose reclassifying to XS/S. Conversely: if what seemed like XS turns out to affect several components, bump the size. Confirm with the user before changing `meta.json.size`.

## 6. Close

- Update `meta.json`: `phase = "diagnose"`, add to `phases_done`.
- Suggest next: `/flow-bug-investigate` (M/L) or `/flow-bug-fix` (S if the cause is evident).
