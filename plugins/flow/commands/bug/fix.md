---
description: Implement the minimal fix and keep a log
---

# `/flow:bug:fix`

Apply the fix. **Minimum viable**: do not take the opportunity to refactor adjacent areas. If you discover more problems, note them but do not touch them here.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — current behavior: stop at every decision point and, at the end, recommend the next command without invoking it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`.
- If `size` is `XS`: allow starting without `diagnose`/`investigate`, but require a 2-3 line description of the fix.
- If `size` ≥ S: require `diagnose` (and `investigate` for M/L) in `phases_done`.
- Read previous artifacts.

## 2. Fix brief (before touching code)

Before touching any code, write a brief in **plain** (non-technical) language specific to this fix:

```
Fix brief {TICKET}

What stops happening after the fix:
- <observable symptom the user reported, described in terms of what they saw>

What is changed:
- <one line, in business or behavior language, not in terms of files>

What is NOT touched:
- <adjacent areas that might be tempting to refactor>
- <potential regressions that are NOT addressed here>
```

**Ask the user with `AskUserQuestion`** whether this reflects the expected fix:
- **Yes, go ahead** → apply the fix.
- **No, something is missing or wrong** → adjust the brief, ask again. Do not touch code until confirmed.

Save the brief at the top of `04-fix.md`. If during implementation the temptation arises to "also fix X while we're at it" (common with bugs), return to §2.3 — fixes that expand into adjacent refactors are the primary way to introduce new regressions while fixing the original one.

## 2.1 Work

- Apply the minimal fix targeting the finding from `03-investigation.md` (or the diagnosis if you skipped investigate).
- If it touches a sensitive area (authentication, payments, sensitive data), consult the `agents.architecture` agent from FLOW.md to confirm the correct layer; if that is empty, check directly against `conventions` from FLOW.md.
- Use `TaskCreate` for fix steps if there are more than 2.
- Keep the log updated while editing.

**Opt-in commits**: the agent does **not run `git commit` on its own** during `/flow:bug:fix`. After completing each step (or the whole fix if it is a single step), report a summary (files, lines, validation suggestion) and wait for your decision: commit work-in-progress now, wait until you validate it, or continue without committing. Without your explicit confirmation, changes stay in the working tree so you can test the fix manually before it is recorded in history.

## 2.3 Something outside the brief comes up?

If during the fix a temptation arises that **is not in the brief of §2** ("while I'm at it, I'll also fix X", "this rename fits here", "this extra test covers another case"):

**Pause before touching it** and ask the user with `AskUserQuestion`:
- **Yes, add it to the brief** — update the brief in `04-fix.md` and continue.
- **No, leave it out** — note it under "Areas with similar risk" (if it is a risk from the same pattern) or create an "Ideas for separate tickets" section in `04-fix.md`.

Expanded fixes are the primary cause of collateral regressions — the flow pushes you to keep the fix truly minimal.

## 3. Log

`.claude/work/<TICKET>/04-fix.md`:

```markdown
# Fix {TICKET}

## Brief
**What stops happening after the fix**:
- <observable symptom>

**What is changed**:
- <one line of behavior>

**What is NOT touched**:
- <adjacent areas out of scope>

## Fix description
<one sentence: "The fix consists of …">

## Changes by file
- <file> — what changed and why (1 line)

## Areas with similar risk (noted, NOT touched here)
- open a separate ticket if warranted

## Ideas for separate tickets
<things that came up during the fix and were decided NOT to include>

## Relevant commands
- <commands used to install dependencies, etc.>
- …
```

## 4. Immediate quality

Use the `quality` commands from FLOW.md; if they are empty, auto-discover (Makefile, npm/composer scripts) and report what you use:

- `quality.style_fix`
- `quality.static_analysis`
- Run the test that covers the fix: `quality.test_one` (if it does not exist, you will add it in `/flow:bug:validate`).

## 4.1 Is the investigation still valid?

If while applying the fix you discover that the **root cause** was not what `03-investigation.md` pointed to (e.g. the suspected commit was not the culprit, or the broken pattern is elsewhere), **pause and go back to `/flow:bug:investigate`** to update the cause before continuing. A fix that does not target the real reason usually leaves the incident open in a different form. Do not proceed with an investigation you know is incomplete.

## 5. Close

- Update `meta.json`: `phase = "fix"`, add to `phases_done`.
- Suggest next: `/flow:bug:validate` (S/M/L) or `/flow:bug:review` (XS).
