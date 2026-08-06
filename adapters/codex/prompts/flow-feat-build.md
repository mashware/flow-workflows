# `/flow-feat-build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a subagent panel, challengers or a skeptic filter, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

**Reporting — how every stop reads.** When this command stops — a question, a hard gate, or the end of the turn — the user is coming back to a screen they walked away from, often with other works running in other panes. They have **not** read your tool calls, your subagents' reports, or the artifacts you wrote. So every stop **opens with this header**, before any prose:

```
<TICKET> · <size> · phase <phase> · MR #<n> of <N>
Plan: <k> of <N> shipped — #1 <url/id> <state> · #2 <state> · #3–#N pending
Now: <one line — what just finished>
I need: <one line — the decision or action you need from them, or "nothing, continuing with X">
```

Take every fact from `meta.json` (`ticket`, `size`, `phase`, `mrs[]`), never from memory. Drop the `MR #<n> of <N>` and `Plan:` lines when the work has no `mrs`. After the header, **at most ~10 lines of body**, and only what could change a decision the user might take. Everything else goes to the phase artifact, which is where it stays useful.

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion notices never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**A question is asked as a question.** Never end a message with one buried in prose: write it as an explicit numbered choice with the recommended option marked, and wait. In `manual` a question hidden in the text is invisible; in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve to be numbered and waited on, it is not a question — it is a decision you take and record.

**Live panel — the same stop, written to disk.** The user typically has several works in flight at once and a panel open per work, so "where is this one at?" is a question they should never have to type at you. Whenever the state such a panel would show changes, overwrite `.claude/work/<work>/panel.json` **whole** (never patch it) with a snapshot built from `meta.json` plus what you know right now:

```json
{
  "updated_at": "2026-08-06T16:45:00+02:00",
  "phase": "validate",
  "header": true,
  "lines": [
    {"text": "Expose a thread's tracking state and events", "style": "title"},
    "",
    {"text": "#1 batch read sources        MR open", "style": "ok"},
    {"text": "https://gitlab.com/…/merge_requests/9977", "style": "dim", "indent": 3},
    {"text": "#2 per-message grouping      validating"},
    {"text": "#3–#6 channel map · use case · detail · route", "style": "dim"},
    "",
    "Right now: unit suite and the test agent over #2",
    {"text": "Next: ship #2 — needs your confirmation", "style": "dim"},
    "",
    {"text": "Waiting on you: confirm the MR/PR body before I create it", "style": "accent"},
    {"text": "sibling-repo still needs the endpoint contract", "style": "warn"}
  ]
}
```

**What goes in, in this order.** (1) The work title. (2) The MR/PR train — one line per `meta.json.mrs[]` entry, `#n`, short title, and **its real state as the last column**, with the **URL indented underneath every entry that is still open**, because chasing you for a link is the single most common thing the user has to ask for; the ones not started yet collapse into a single `#a–#z` line; omit the block entirely when the work has no `mrs`. **Never group the entries under headings like "done" / "left"**: in a train an MR/PR that has shipped is *open, waiting to merge*, and a heading that calls it done states something false in the one place the user is trusting at a glance. The state column says it; nothing above it needs to. (3) `Right now:` — one line of prose on what is actually running, the one fact `meta.json` cannot hold. (4) `Next:` — what follows. (5) `Waiting on you:` in `accent`, **only** when the flow is parked on a decision of theirs, naming that decision. (6) Blockers in `warn`: a sibling repo whose `contract_handoff` is `pending` (from `related_repos`), a red pipeline, a dependency that has not merged. Styles are semantic — `normal` `dim` `title` `accent` `ok` `warn` `error` — the panel owns the palette.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a panel that reads the phase from it shows the previous one for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, age — and the phase, from `phase` when present — are already drawn by the panel; never repeat them in `lines`. Keep it under ~14 lines, and keep **each line short enough not to wrap** (~55 characters is the safe width): a wrapped line loses its column and its continuation does not inherit `indent`, so it is better to say less than to say it in two ragged lines. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

Implementation phase. This is where code gets written.

## 1. Pre-flight

- Load `meta.json` by current branch.
- For `size` M/L: require that both `03-design.md` **and** `04-mr-plan.md` exist. If the plan is missing, send to `/flow-feat-plan`. If the design is missing, send to `/flow-feat-design`.
- For `size` XS/S: allow starting without a design but ask the user for a 2-3 line note on what they're going to do and save it as a minimal `03-design.md`. No MR/PR plan (always 1 MR/PR).
- Read all previous artifacts.
- **If `meta.json.mrs` has more than one entry**: pick the **startable** MR/PR — the `pending` one with the **lowest `n` whose `depends_on` are all `merged`**. An MR/PR whose dependencies are still `pending`/`in_progress` is **not** startable yet, even if its `n` is low. Since `n` follows the execution order (see `/flow-feat-plan`), that is normally the lowest-`n` pending entry; `depends_on` is the guard for trains where an earlier MR/PR has not merged. (Older plan without `wave`/`depends_on` → fall back to "first pending by `n`".) If several `pending` MRs/PRs share the same `wave` and have no dependency between them, they can go in parallel or as a train: default to the lowest `n`, but tell the user. If all are `merged`, warn: feature is done. If some are `pending` but none is startable, say which merge unlocks the next wave and stop. Mark the chosen one as `in_progress` in `meta.json.mrs`.

## 2. Business brief (before typing)

**Before loading skills, creating tasks, or any edit**, write a brief in **business language** (not technical) specific to **this particular MR/PR**:

```
Brief MR/PR #N: <title>

After this MR/PR:
- The user will be able to <X>.
- The system will <do Y / stop doing Z>.
- <success metric if applicable>.

This MR/PR does NOT include:
- <piece Y that belongs to MR/PR #N+1>.
- <related functionality that was decided not to do>.
- <tempting scope that stays out>.
```

Rules for writing it:
- **Business language**: say "the user will be able to filter campaigns by date", not "creates the `GET /campaigns?from=...` endpoint".
- **Specific to the MR/PR**: if the feature has 4 MRs/PRs, the brief covers only what this one delivers — not the full feature.
- **The "does NOT include" is mandatory**: even if it seems redundant with `04-mr-plan.md`, repeating it here fixes the scope. If you don't know what to put, the plan is wrong.
- 3-5 bullets in each list. More is noise.

**Ask the user** whether the brief reflects what they expect — **in every autonomy mode, `auto` included** (a deliberate gate: the last point where the scope can be fixed before there is a diff to argue with):
- **Yes, go ahead** → start building.
- **No, something is wrong or missing** → user clarifies, you adjust the brief and ask again. **Don't touch code** until the brief is confirmed.

Save the brief at the start of `05-implementation.md` under "## Brief MR/PR #N". It serves as the contract for the rest of the build: if the temptation arises to do something not in the brief, return to §2.4 before doing it.

## 2.0bis Copy the contracts from the design (verbatim, don't paraphrase)

**Before typing code**, open `03-design.md` and locate the **"External contracts"** section. For **each contract** declared there (HTTP body, header, route, event, column, metric), **copy it literally** to `05-implementation.md` under:

```markdown
## Contracts to respect (copied verbatim from 03-design.md §"External contracts")

### Contract N: <description>
- **Literal shape**:
  <BLOCK COPIED AS-IS, without re-writing or paraphrasing>
- **Pattern deviation** (if applicable): <copied from the design>
```

Hard rules:
- **Copy, don't rewrite.** The goal is to anchor your attention.
- **If the design wrote the contract in prose**, convert it to literal format here and flag it to the user.
- **If there's a "Pattern deviation" section**: copy it too.
- **If the design says "none"**, skip this step and record: "## Contracts to respect — none declared in design".

Without this copy, §2.1 cannot begin.

## 2.1 Work

Load the project skills (see `FLOW.md` section `conventions`).

**Comment discipline**: comment only a non-obvious *why* (a constraint, the reason for a workaround, a subtle invariant), never narrate what the code already says or restate the design, and match the file's comment density. **Never put the ticket ID, task/step number, or "for MR #N" in a code comment** — that lives in the commit/branch/MR-PR, not the source, where it just rots.

**Borrowed code carries its reason.** When you lift a structure from another file in the repo — a `catch` block, a guard clause, a mapper, a config stanza, a test setup — you are importing decisions made for *that* file's situation, not for yours. Before keeping it, name under "Decisions made during implementation" where it came from and **what makes it apply here**: the exception it catches is actually thrown on this path, the guard's precondition can actually be false here. If you cannot name that reason, do not copy it — write what this code needs or leave it out. Borrowed-and-plausible is the most expensive kind of line to put in a diff: it reads as deliberate, so a reviewer spends real attention before discovering it was never chosen. Same anti-drift rule as §2.0bis, applied to code instead of contracts.

**If in a multi-MR/PR build**: limit yourself to what the current MR/PR touches per `04-mr-plan.md`. Any code that belongs to a later MR/PR is scope expansion; cut it or isolate it behind a feature flag / temporary dead code per the plan.

Decide execution mode:

- **Single thread (XS/S/M)**: implement yourself, step by step, using subagents only as point consultants if blocked: the `agents.architecture` agent from `FLOW.md` for layer questions, and `agents.persistence` for query/mapping questions.
- **Partial delegation (M/L with clear pieces)**: use subagents for isolated endpoints, and the `agents.testing` agent from `FLOW.md` in parallel to prepare the suite. Pass the entire `03-design.md` in the prompt so they don't invent.

### 2.2 Checkpoints (local commits, gated by `autonomy.mode`)

**Commits follow the mode** (from the preamble). The step's changes are **always reported before anything is recorded**; who decides the commit is what changes:

- **`manual`** — the agent **does not run `git commit` on its own**. Without your explicit confirmation, changes stay in the working tree so you can validate them first (try the UI, run the flow, read the diff).
- **`guided`** — ask **once**, at the first step, and apply that answer for the rest of this build; record it in `05-implementation.md`.
- **`auto`** — commit the step's WIP yourself and continue, without asking. **Invoking the command with `autonomy.mode: auto` is the explicit authorization** the system rule (*never commit unless the user asks*) requires. It covers **only** WIP commits on the work branch: push and MR/PR creation stay hard gates in every mode.

**After completing each step**, the agent:

1. Reports a step summary to the user (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<added> / -<removed> lines
     Suggested validation: <e.g. "run the unit test command for Foo">
   ```
2. **Then, per mode**: in `guided`/`auto`, run `git add <step files> && git commit -m "WIP <TICKET>: <step>" --no-verify` and start the next step without pausing. In `manual`, **do not commit** — wait for the user: In `guided`/`auto` the step summary is a **report, not a question** — do not append "shall I commit and move on?" to it; that stop is in the never-ask block of the preamble.
   - **"Commit now"** or **"OK, continue"** → does `git add <step files> && git commit -m "WIP <TICKET>: <step>" --no-verify` and continues.
   - **"Wait, I'll validate"** → stays put. You validate at your own pace.
   - **"Change X"** → adjusts. The step's commit stays pending until you give the OK.
   - **"Continue without committing, we'll group later"** → starts the next step without a commit.

Rules for when a commit does happen:
- One commit per step. Don't group multiple steps unless you explicitly ask for it.
- `--no-verify` is allowed **only on WIP commits** (slow hooks will run in `/flow-feat-review` and in the final commit of `/flow-feat-ship`).
- These commits get squashed when merging (if `git.squash` is `true`), so they don't need to be clean.

### 2.3 Size gauge and mid-build cut

**After each completed step** (with or without a commit), compare the actual size against the current MR/PR estimate in `meta.json.mrs`:

```bash
# Changes committed on top of the base branch:
git diff --shortstat <git.default_base>..HEAD
git diff --name-only <git.default_base>..HEAD | wc -l

# Changes in the working tree (pending commit):
git diff --shortstat HEAD
git status --short | wc -l
```

Add both sides to get the total actual size.

Warning thresholds:
- **Actual lines > `lines_est * 1.5`**, or
- **Actual files > `files_est + 2`**.

If either is exceeded, **pause** and ask the user (options in this order):

1. **Cut here (recommended if the current piece is coherent)**.
2. **Continue and record the overrun**.
3. **Reopen plan**. Return to `/flow-feat-plan` to rethink the entire split.

### 2.4 Does something fall outside the brief?

If during the build the temptation arises to add something **not in the §2 brief**, **pause** and ask the user:
- **Yes, add it to the brief** — update the brief in `05-implementation.md` and continue.
- **No, leave it out** — note it in the "Ideas for separate tickets" section of `05-implementation.md`.

## 3. Implementation log

Keep `.claude/work/<TICKET>/05-implementation.md` updated while you work (not at the end):

```markdown
# Implementation <TICKET>

## Brief MR/PR #N
<3-5 bullets of what the user will be able to do after this MR/PR, in business language>

**This MR/PR does NOT include**:
- <pieces that stay out>

## Changes per file
- <file> — what changed and why (1 line each)

## Decisions made during implementation
- Decision: …
  - Why: …
  - Discarded alternative: …

## Deviations from the design
- Design said X → did Y because Z

## Relevant commands run
- <quality.style_fix from FLOW.md>
- <quality.db_update from FLOW.md>

## Pending
- [ ] …

## Ideas for separate tickets
<things that came up during the build and were decided NOT to include>
```

## 4. Quality during implementation

As larger pieces are completed:

- Run `quality.style_fix` from `FLOW.md` to fix style; if empty, auto-discover.
- Run `quality.static_analysis` from `FLOW.md` when a piece is stable; if empty, auto-discover.
- If you added tests, run them individually with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover. **A filtered run is judged by how many tests it executed, never by its exit code.** Almost every runner exits `0` when the filter matches nothing (`OK, 0 tests`, `No tests ran`, `0 passed`), so a typo in `{FILTER}`, a renamed test class, or a test in a suite the filter never reaches are indistinguishable from green. Read the executed count **and** the executed names: if the count is `0`, or the tests you just wrote are not among them, **the run did not happen** — treat it as a failure, fix the filter, run again. If the runner reports no count, drop the filter and run the whole test file. Record the count you actually saw, not just the command.

## 4.1 Is the design still valid?

Review the "Deviations from the design" section of `05-implementation.md`. If **any** of the following apply:

- **2+ significant deviations** (module change, different event contract, different entity, new unpredicted repository).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.
- **A primitive materialized with a different name/role than the design named it** (design said *Query*, code built a *Command*; design said *service*, code built a *handler* wired through a bus). This is **vocabulary drift**: either the design's naming was wrong (update `03-design.md`) or the code chose the wrong primitive (fix the code). Reconcile it now — don't let the design and the code disagree on what each piece *is*, because `/flow-feat-review §5.5` and the reader judge the code, not the design's intent.

**Pause the build and return to `/flow-feat-design`** to update the document.

## 4.2 Textual contract verification (before closing)

If in §2.0bis you copied contracts, **before marking the build as done** compare the code against each cited contract — **this is not a test to run**, it's a deliberate textual comparison:

For each contract in "Contracts to respect":
1. Locate in the code where the shape is constructed.
2. List the **keys and nesting** that code produces.
3. Compare **key by key, character by character** against the literal quote copied in §2.0bis.
4. If anything differs, **go back and edit the code** to match.

Note the result in `05-implementation.md` under "## Contract verification":
```
## Contract verification (§4.2)
- Contract N "<description>": code produces <actual shape>, quote declares <declared shape>. ✅ matches / ❌ adjusted.
```

## 5. Close

- Update `meta.json`: `phase = "build"`, add to `phases_done`. **If multi-MR/PR build, also add `build` to the current `in_progress` MR/PR's own `phases_done`** (its `mrs[]` entry) — the per-MR/PR marker the downstream gates (`/flow-feat-review §1`, `/flow-feat-validate §1`, `/flow-feat-ship §1`) read.
- Summarize for the user in bullets: touched files (high level), pending items, **§4.2 result (contracts verified)**, and next command: `/flow-feat-review`.
- **Autonomy handoff.** In `manual`, stop here and propose `/flow-feat-review` as a question, invoking it only on confirmation. In `guided`/`auto`, **chain into `/flow-feat-review` automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
