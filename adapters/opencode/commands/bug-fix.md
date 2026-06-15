---
description: Implement the minimal fix and keep a log
---

# `/bug-fix`

Apply the fix. **Minimum viable**: do not use this as an opportunity to refactor adjacent areas. If you discover more problems, note them but don't touch them here.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. On `domain_memory`: if enabled but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user.

- Load `meta.json`.
- If `size` is `XS`: allow starting without `diagnose`/`investigate`, but require a 2-3 line description of the fix.
- If `size` ≥ S: require `diagnose` (and `investigate` for M/L) in `phases_done`.
- Read prior artifacts.

## 2. Fix brief (before touching code)

Before touching any code, write a brief in **plain language** (non-technical) specific to this fix:

```
Fix brief {TICKET}

What stops happening after the fix:
- <observable symptom the user reported, described in terms of what they saw>

What changes:
- <one line, in business or behavioral terms, not file names>

What is NOT touched:
- <adjacent areas that might tempt a refactor>
- <potential regressions that are NOT addressed here>
```

**Ask the user** whether this reflects the expected fix:
- **Yes, go ahead** → apply the fix.
- **No, something is missing or wrong** → adjust the brief, ask again. Do not touch code until confirmed.

Save the brief at the top of `04-fix.md`. If during implementation the temptation arises to "while we're here, also fix X" (common with bugs), return to §2.3 — fixes that expand into adjacent refactors are the main path to introducing new regressions while fixing the old one.

## 2.1 Work

- Apply the minimal fix targeting the finding in `03-investigation.md` (or the diagnosis if you skipped investigate).
- If touching a sensitive area (authentication, payments, sensitive data), consult the `agents.architecture` subagent from FLOW.md to confirm the correct layer; if empty, cross-check directly against `conventions` in FLOW.md.
- Keep the log updated while editing.

**Opt-in commits**: the agent **does not run `git commit` on its own** during `/bug-fix`. After completing each step (or the entire fix if it's a single step), report a summary (files, lines, validation suggestion) and wait for your decision: commit work in progress now, wait until you validate, or continue without committing. Without your explicit confirmation, changes stay in the working tree so you can test the fix manually before it's recorded in the history.

## 2.3 Does something arise outside the brief?

If during the fix something tempts you that **is not in the §2 brief** ("while we're here, fix X too", "this rename fits here", "this extra test covers another case"):

**Pause before touching it** and ask the user:
- **Yes, add it to the brief** — update the brief in `04-fix.md` and continue.
- **No, leave it out** — note it under "Areas with similar risk" (if it's a risk from the same pattern) or create an "Ideas for separate tickets" section in `04-fix.md`.

Scope-expanding fixes are the main cause of collateral regressions — the flow pushes you to keep the fix genuinely minimal.

## 3. Log

`.claude/work/<TICKET>/04-fix.md`:

```markdown
# Fix {TICKET}

## Brief
**What stops happening after the fix**:
- <observable symptom>

**What changes**:
- <one line of behavior>

**What is NOT touched**:
- <adjacent areas out of scope>

## Fix description
<one sentence: "The fix consists of …">

## Changes by file
- <file> — what changed and why (1 line)

## Areas with similar risk (noted, NOT touched here)
- open a separate ticket if appropriate

## Ideas for separate tickets
<things that came up during the fix and were decided NOT to include>

## Relevant commands
- <commands used to install dependencies, etc.>
- …
```

## 4. Immediate quality

Use the commands from `quality` in FLOW.md; if empty, auto-discover (Makefile, npm/composer scripts) and report what you use:

- `quality.style_fix`
- `quality.static_analysis`
- Run the test that covers the fix: `quality.test_one` (if it doesn't exist, you'll add it in `/bug-validate`).

## 4.1 Is the investigation still valid?

If while applying the fix you discover that the **root cause** wasn't what `03-investigation.md` pointed to (e.g. the suspected commit wasn't the culprit, or the broken pattern is somewhere else), **pause and return to `/bug-investigate`** to update the cause before continuing. A fix that doesn't target the real "why" usually leaves the issue open in another form. Do not advance with an investigation you know is incomplete.

## 5. Wrap-up

- Update `meta.json`: `phase = "fix"`, add to `phases_done`.
- Suggest next step: `/bug-validate` (S/M/L) or `/bug-review` (XS).
