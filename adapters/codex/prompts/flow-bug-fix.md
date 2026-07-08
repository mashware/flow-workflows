# `/flow-bug-fix`

Apply the fix. **Minimum viable**: don't take the opportunity to refactor adjacent areas. If you discover more problems, note them but don't touch them here.

## 1. Pre-flight

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

- Load `meta.json`.
- If `size` is `XS`: allow starting without `diagnose`/`investigate`, but require a 2-3 line description of the fix.
- If `size` ≥ S: require `diagnose` (and `investigate` for M/L) in `phases_done`.
- Read previous artifacts.

## 2. Fix brief (before typing)

Before touching code, write a brief in **clear** language (not technical) specific to this fix:

```
Brief fix {TICKET}

What stops happening after the fix:
- <observable symptom the user reported, described in terms of what they saw>

What changes:
- <one line, in business or behavioral language, not file names>

What is NOT touched:
- <adjacent areas that might be tempting to refactor>
- <potential regressions that are NOT being addressed here>
```

**Ask the user** whether this reflects the expected fix:
- **Yes, go ahead** → apply the fix.
- **No, something is wrong or missing** → adjust the brief, ask again. Don't touch code until confirmed.

Save the brief at the start of `04-fix.md`.

## 2.1 Work

- Apply the minimal fix targeting the finding from `03-investigation.md` (or the diagnosis if you skipped investigate).
- If it touches a sensitive area (authentication, payments, sensitive data), consult the `agents.architecture` agent from FLOW.md point-by-point to confirm the correct layer; if empty, check directly against `conventions` in FLOW.md.

**Commit confirmation**: the agent **does not `git commit` on its own** during `/flow-bug-fix`. After completing each step (or the entire fix if it's a single step), report a summary (files, lines, validation suggestion) and wait for your decision: commit the work in progress now, wait for you to validate, or continue without a commit. Without your explicit confirmation, changes stay in the working tree so you can test the fix manually before it's recorded in history.

## 2.3 Does something fall outside the brief?

If during the fix the temptation arises to do something **not in the §2 brief**:

**Pause** and ask the user:
- **Yes, add it to the brief** — update the brief in `04-fix.md` and continue.
- **No, leave it out** — note it in "Areas with similar risk" or create "Ideas for separate tickets" in `04-fix.md`.

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

## Changes per file
- <file> — what changed and why (1 line)

## Areas with similar risk (noted, NOT touched here)
- open a separate ticket if appropriate

## Ideas for separate tickets
<things that came up during the fix and were decided NOT to include>

## Relevant commands
- <commands used to install dependencies, etc.>
```

## 4. Immediate quality

Use the `quality` commands from FLOW.md; if empty, auto-discover and flag what you're using:

- `quality.style_fix`
- `quality.static_analysis`
- Run the test that covers the fix: `quality.test_one` (if it doesn't exist, you'll add it in `/flow-bug-validate`).

## 4.1 Is the investigation still valid?

If when applying the fix you discover that the **root cause** was not what `03-investigation.md` indicated, **pause and return to `/flow-bug-investigate`** to update the cause before continuing.

## 5. Close

- Update `meta.json`: `phase = "fix"`, add to `phases_done`.
- Suggest next: `/flow-bug-validate` (S/M/L) or `/flow-bug-review` (XS).
