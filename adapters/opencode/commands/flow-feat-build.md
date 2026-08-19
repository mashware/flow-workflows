---
description: Implement the feature following the approved design and keep a running log
---

# `/flow-feat-build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes longer than 2 s, continue without that context — don't block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Models — which one runs this step.** Read `models` from `FLOW.md`. **This command's key is `code`**; empty (or no `models` section) = run with the model this session was launched with, and say nothing about it. When it is set, it applies to the subagents **this command decides to launch**: in this harness a subagent's model is declared in its own definition, so satisfy the key by launching a subagent declared with that model (see the adapter's `PRIMITIVES.md`), and an agent named in `agents.<role>` keeps whatever its own definition already sets. Parallel fan-out rounds take `models.workers` when set, otherwise this command's key. For the parts you perform **yourself** you cannot switch your own model: when the configured value differs from the model you are running, state it in one line at the handoff — naming this harness's own way to switch it (its model command, or the `--model` flag at launch) — record it in the phase artifact, and **continue**. That is flow mechanics: never a question in `guided`/`auto`, never a hard gate. If this harness cannot set a model per subagent at all, note it once and carry on with the inherited one.

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

**Product altitude — the effect, not the implementation.** The body is written in the language of what changed for whoever uses this software: what the product does now that it did not, what was breaking and for whom, what is still not covered. Not what you built. Code identifiers — classes, files, methods, error codes — earn a line only when the user has to *decide* about one, when they asked something technical, or when they named it first; the mechanics belong to the phase artifact, which is where they stay useful. Ten lines about `AttachmentUploader` say nothing to someone who has not read the diff; "attachments over 25 MB no longer break the send — they upload separately and the mail carries a link" says all of it. When an identifier is genuinely unavoidable, the Zero-context rule below applies to it.

**Short lines, not prose.** One or two lines of headline, then two to five bullets, one idea each. No chained subordinate clauses, no "for context", no restating what an earlier stop already said. The ~10-line limit above is a ceiling, not a target: ten lines of prose obey it and are still a wall of text. This governs the report you write unprompted — when the user asks a technical question, answer it in full.

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
    {"ref": "#1", "text": "batch read sources", "mark": "wait", "link": "https://gitlab.com/…/merge_requests/9977"},
    {"ref": "#2", "text": "per-event and per-recipient counters", "mark": "current"},
    {"ref": "#3–#6", "text": "channel map · use case · document detail · route", "mark": "pending"},
    "",
    {"ref": "Now", "text": "unit suite and the test agent over #2", "mark": "info"},
    {"ref": "Next", "text": "ship #2", "mark": "info"},
    {"ref": "Decision", "text": "confirm the MR/PR body before I create it", "mark": "wait"},
    "",
    {"text": "sibling-repo still needs the endpoint contract", "mark": "block"}
  ]
}
```

**`mark` says what a line *is*; the panel decides how to draw it.** `done` (merged, finished) · `current` (what is running right now — at most one) · `pending` (not started) · `wait` (shipped or asked, now waiting on someone else — an open MR/PR, a decision of the user's) · `block` (something is stopping this) · `info` (plain statement of fact). Lines carrying a `mark` form an aligned column: symbol, then `ref`, then the text, with the link pinned right. **Do not also set `style` on a marked line** — `style` overrides the mark's colour, and the colour is how the mark reads. The one exception is a line whose colour *is* the information (a monitoring cycle's verdict): there, `mark: "info"` plus `style: ok|warn|error` is the point.

**`ref` need not be a number.** `#1`, `#3–#6`, but equally `Now`, `Next`, `Decision`. Column width is computed **per block**, and blocks are separated by blank lines — so the MR/PR train aligns with the train and the labels below align with each other, without dragging one another wide. Use blank lines deliberately: they are what keeps two groups from distorting each other.

**`link` is a field, never text inside `text`.** The panel shortens it to its MR/PR number and pins it to the right of the line, or hangs it underneath when it does not fit. Pasting a raw URL into `text` gets you a 60-character line that wraps.

**What goes in, in this order.** (1) The work title (`style: title`, no mark). (2) The MR/PR train — one entry per `meta.json.mrs[]`, `ref` `#n`, a short title, the `mark` for its real state, and `link` for the ones that have a URL; entries not started yet collapse into a single `#a–#z` `pending` line; omit the block when the work has no `mrs`. (3) `Now` — what is actually running, the one fact `meta.json` cannot hold. (4) `Next`. (5) `Decision`, marked `wait`, **only** when the flow is parked on the user, naming the decision. (6) Blockers marked `block`: a sibling repo whose `contract_handoff` is `pending`, a red pipeline, a dependency that has not merged.

**When to write it.** (a) In pre-flight, as soon as `meta.json` is loaded. (b) Immediately **before** every stop header above. (c) **Before** any stretch that will run long without stopping — a subagent fan-out, a full test suite, a CI poll — never after: a panel written only when a step succeeds keeps showing as finished a step that in fact died halfway, and a truthful `updated_at` is what lets the panel flag that instead. When that stretch is expected to outlast the panel's staleness warning (~30 min), set **`stale_after_minutes`** to what it will really take, so a long CI poll is not reported as a dead agent. (d) Wherever `## Close` updates `meta.json`.

**Rules.** `phase` is **the phase you are running right now**, which is not `meta.json.phase` until you close: that field only advances at the end, so a header drawn from it shows the previous phase for as long as this one lasts. Write it on every panel. `header: true` means ticket, type, phase and age are drawn by the panel — never repeat them in `lines`. Keep it under ~14 lines; the panel wraps a long line and aligns the continuation under its text, so length is a matter of saying less, not of measuring columns. Every fact comes from `meta.json` and the artifacts, never from memory — an invented MR/PR state, read at a glance and trusted, is worse than a blank panel. Set `updated_at` from the real clock (`date -Iseconds`), local offset included; never carry over the previous value. Write in the language the work's artifacts are written in — the panel is read by the same person who reads them. No work folder (the lightweight mode of `respond`/`green`) → nothing to write, and that is fine.

Implementation phase. This is where code gets written.

## 1. Pre-flight

- Load `meta.json` for the current branch.
- For `size` M/L: require that both `03-design.md` **and** `04-mr-plan.md` exist. If the plan is missing, send to `/flow-feat-plan`. If the design is missing, send to `/flow-feat-design`.
- For `size` XS/S: allow starting without a design but ask the user for a 2-3 line note on what they're about to do and save it as a minimal `03-design.md`. No MR/PR plan (always 1 MR/PR).
- Read all previous artifacts.
- **If `meta.json.mrs` has more than one entry**: pick the **startable** MR/PR — the `pending` one with the **lowest `n` whose `depends_on` are all `merged`**. An MR/PR whose dependencies are still `pending`/`in_progress` is **not** startable yet, even if its `n` is low. Since `n` follows the execution order (see `/flow-feat-plan`), that is normally the lowest-`n` pending entry; `depends_on` is the guard for trains where an earlier MR/PR has not merged. (If entries have no `wave`/`depends_on` — an older plan — fall back to "first pending by `n`".)
  - **Parallel siblings**: if several `pending` MRs/PRs in the **same `wave`** are startable and have no dependency between them, they can be built in parallel or as a train. In `manual`, tell the user and let them choose which to take now (default: lowest `n`); in `guided`/`auto`, take the lowest `n` and record it. Mark the chosen one as `in_progress`.
  - If all are `merged`, warn: feature complete, nothing left to build.
  - If some are `pending` but **none** is startable (all blocked by unmerged dependencies), do not start anything: tell the user which MR/PR needs to merge to unlock the next wave and stop.

## 2. Business brief (before typing)

**Before loading conventions, creating tasks, or making any edit**, write a brief in **business language** (non-technical) specific to **this particular MR/PR** (the `in_progress` one in `meta.json.mrs`, not the whole feature):

```
Brief MR/PR #N: <title>

After this MR/PR:
- The user will be able to <X>.
- The system will <do Y / stop doing Z>.
- <success metric if applicable>.

This MR/PR does NOT include:
- <piece Y that belongs to MR/PR #N+1>.
- <related functionality that was decided against>.
- <tempting scope that's out of bounds>.
```

Rules for writing it:
- **Business language**: say "the user will be able to filter campaigns by date", not "a `GET /campaigns?from=...` endpoint is created".
- **Specific to the MR/PR**: if the feature has 4 MRs/PRs, the brief only covers what this one contributes — not the whole feature.
- **"Does NOT include" is mandatory**: even if it seems redundant with `04-mr-plan.md`, repeating it here fixes the scope. If you don't know what to put, the plan is wrong.
- 3-5 bullets in each list. More is noise.

**Ask the user** whether the brief reflects what they expect — **in every autonomy mode, `auto` included** (a deliberate gate: the last point where the scope can be fixed before there is a diff to argue with):
- **Yes, go ahead** → start building.
- **No, something is off** → the user clarifies, you adjust the brief and ask again. **Don't touch code** until the brief is confirmed.

Save the brief at the top of `05-implementation.md` under "## Brief MR/PR #N". It serves as the contract for the rest of the build: if the temptation arises to do something not in the brief, return to §2.4 before acting.

## 2.0bis Copy the design contracts (verbatim, do not paraphrase)

**Before writing any code**, open `03-design.md` and find the **"External contracts"** section. For **each contract** declared there (HTTP body, header, route, event, column, metric), **copy it literally** into `05-implementation.md` under a new section:

```markdown
## Contracts to respect (copied verbatim from 03-design.md §"External contracts")

### Contract N: <description>
- **Literal shape**:
  <BLOCK COPIED AS-IS, not rewritten, not paraphrased, not "I think it was like this">
- **Pattern deviation** (if applicable): <copied from the design>
```

Hard rules:
- **Copy, don't rewrite.** The goal is to anchor your attention: when you later decide between following a repo pattern or the declared contract, the contract lives in the file you're writing, not in another one you're no longer looking at.
- **If the design wrote the contract in prose** (without a literal shape), convert that contract to literal format here and flag it in the user report: "contract N was in prose in the design, I've converted it to literal — confirm it's correct". Don't proceed until confirmed.
- **If there's a "Pattern deviation" section**: copy it too. It reminds you at coding time not to mimic the repo pattern even if your hand drifts there.
- **If the design says "none"** (no external surfaces), skip this step and record it: "## Contracts to respect — none declared in design".

Without this copy, don't proceed to §2.1.

## 2.1 Work

Apply the repo's `conventions` from `FLOW.md` — free text (layers, patterns, prohibitions), so read it and follow it as written. If opencode also exposes project conventions as files or agents encoding them, load those too; with none, the `conventions` text is the whole instruction, not a pointer to something else.

**Comment discipline**: comment only a non-obvious *why* (a constraint, the reason for a workaround, a subtle invariant), never narrate what the code already says or restate the design, and match the file's comment density. **Never put the ticket ID, task/step number, or "for MR #N" in a code comment** — that lives in the commit/branch/MR-PR, not the source, where it just rots.

**Borrowed code carries its reason.** When you lift a structure from another file in the repo — a `catch` block, a guard clause, a mapper, a config stanza, a test setup — you are importing decisions made for *that* file's situation, not for yours. Before keeping it, name under "Decisions made during implementation" where it came from and **what makes it apply here**: the exception it catches is actually thrown on this path, the guard's precondition can actually be false here. If you cannot name that reason, do not copy it — write what this code needs or leave it out. Borrowed-and-plausible is the most expensive kind of line to put in a diff: it reads as deliberate, so a reviewer spends real attention before discovering it was never chosen. Same anti-drift rule as §2.0bis, applied to code instead of contracts.

**A query is written against the schema, not against the mapping.** When you write or change a data-access query, check **before** calling it done: the index that will serve its filter *and* its order **in that direction** exists (read the schema, not the entity mapping); the bound is real, and if the requirement is "the latest k per key" it is not a global limit; both key columns of every join share type, length and charset/collation; no heavy column is read in a pass that only decides which rows survive. Take the shape from the **Access paths** table in `03-design.md`; if what you write does not match a row there, that is a design deviation to log. Where `data.explain_cmd` is set in `FLOW.md`, get the plan now and paste it under "Access paths implemented" in `05-implementation.md`; where it is not, say the plan is unverified. Never invent an index or a schema change to make a query work — that is a schema change, a hard gate, and it goes back through the design.

**If you're in a multi-MR/PR build**: limit yourself to what the current MR/PR covers according to `04-mr-plan.md`. Any code belonging to a later MR/PR is expanded scope; trim it or isolate it behind a feature flag / temporary dead code as per the plan. If it can't be isolated, pause and go back to `/flow-feat-plan` to trim.

Decide execution mode:

- **Single thread (XS/S/M)**: implement yourself, step by step, using sub-agents only as point consultants when blocked: the architecture sub-agent from `FLOW.md` for layer questions (or a general-purpose sub-agent if empty), and the persistence one for query/mapping questions (or a general-purpose sub-agent if empty).
- **Partial delegation (M/L with clear pieces)**: use `@name` sub-agents for isolated endpoints, and the testing sub-agent from `FLOW.md` in parallel to prepare the test suite (or a general-purpose sub-agent if empty). Pass the full `03-design.md` in the prompt so they don't invent things.

### 2.2 Checkpoints (local commits, gated by `autonomy.mode`)

**Commits follow the mode** (from the preamble). The step's changes are **always reported before anything is recorded**; who decides the commit is what changes:

- **`manual`** — the agent **does not run `git commit` on its own**. Without your explicit confirmation, changes stay in the working tree so you can validate them first (try the UI, run the flow, read the diff).
- **`guided`** — ask **once**, at the first step, and apply that answer for the rest of this build; record it in `05-implementation.md`.
- **`auto`** — commit the step's WIP yourself and continue, without asking. **Invoking the command with `autonomy.mode: auto` is the explicit authorization** the system rule (*never commit unless the user asks*) requires. It covers **only** WIP commits on the work branch: push and MR/PR creation stay hard gates in every mode.

**After completing each step of the plan**, the agent:

1. Reports a step summary to the user (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<add> / -<del> lines
     Suggested validation: <e.g. "run the unit test for Foo" or "open the UI at /section">
   ```
2. **Then, per mode**: in `guided`/`auto`, run `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` and start the next step without pausing. In `manual`, **do not commit** — wait for the user to decide. Options: In `guided`/`auto` the step summary is a **report, not a question** — do not append "shall I commit and move on?" to it; that stop is in the never-ask block of the preamble.
   - **"Commit now"** or **"OK, continue"** → the agent runs `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` and continues with the next step.
   - **"Wait, I'll validate"** → the agent stops. The user validates at their own pace. When they return, they decide: commit or adjust.
   - **"Something needs changing"** → the agent adjusts. The step's commit stays pending until you give the OK.
   - **"Continue without committing, we'll group later"** → the agent starts the next step without committing. Changes accumulate in the working tree.

Rules for when a commit does happen:
- One commit per step. Don't group several steps into one commit unless the user explicitly asks.
- `--no-verify` is allowed **only on work-in-progress commits** (slow hooks will run at the end in `/flow-feat-review` and in the final commit of `/flow-feat-ship`).
- If a step is half-done and the user asks to commit, the message gets a suffix: `WIP <TICKET>: <step> (partial)`.

### 2.3 Size gauge and hot cut

**After each completed step** (with or without a commit), compare the real size against the estimate for the current MR/PR in `meta.json.mrs`. Look at commits + staged + unstaged, not just commits:

```bash
# Committed changes over base branch:
git diff --shortstat <git.default_base>..HEAD     # lines
git diff --name-only <git.default_base>..HEAD | wc -l   # files

# Working tree changes (pending commit):
git diff --shortstat HEAD             # uncommitted lines
git status --short | wc -l            # modified/untracked files
```

Add both sides to get the total real size of the current MR/PR.

Warning thresholds:
- **Real lines > `lines_est * 1.5`**, or
- **Real files > `files_est + 2`**.

If either is exceeded, **pause** and ask the user (options, in this order):

1. **Cut here (recommended if the current piece is coherent)**. What's built so far stays as this MR/PR. What remains from the plan is split into a new entry inserted in `meta.json.mrs` right after. Zero code thrown away.
2. **Keep going and record the overrun**. Useful if cutting would be artificial. The deviation is noted in `05-implementation.md` to calibrate `/flow-feat-plan` on future tickets.
3. **Reopen plan**. Go back to `/flow-feat-plan` to rethink the entire split. Only if the overrun indicates the plan is wrong at a deeper level, not just for this MR/PR.

**Hot cut mechanics (option 1)**:

0. **If there are uncommitted changes** in the working tree: warn the user and ask them to decide before cutting.
1. Identify a cut point: the last work-in-progress commit where the piece is coherent and mergeable.
2. Edit `meta.json.mrs`: the current MR/PR keeps its `n`, `title`, `wave` and `depends_on`, adjust `lines_est` and `files_est` to the real numbers, stays `in_progress`. Insert a new entry with the next `n`, `title` describing what remains, `status: "pending"`, `phases_done: []` (a fresh MR/PR earns its own review/validate), `depends_on: [n_current]`, `wave` = one after the current one. If you renumber later entries, update their `depends_on` references so none points to a higher `n` than its own.
3. Edit `04-mr-plan.md`: split the original entry in two.
4. Note in `05-implementation.md` under "Hot cut": date, reason, what stays and what moves to the next one.
5. **Don't rewrite history with `git rebase`**: work-in-progress commits that belong to the next MR/PR stay on the current branch and will be moved with `git cherry-pick` when the time comes.

**If there's already been a cut and you overflow again**: ask the user before cutting again — a second cut on the same MR/PR is a sign the plan is wrong. The right option is probably **3 (reopen plan)**.

### 2.4 Does something fall outside the brief?

If during the build you're tempted to add something **not in the §2 brief** ("while I'm here…", "this test would also cover X…", "this rename would improve Y…"):

**Pause before doing it** and ask the user:
- **Yes, add it to the brief** — update the brief in `05-implementation.md` and continue. (If the addition is large, consider §2.3: it may trigger an MR/PR cut.)
- **No, leave it out** — note it in the "Ideas for separate tickets" section of `05-implementation.md` and continue with the original brief.

## 3. Log

Keep `.claude/work/<TICKET>/05-implementation.md` updated as you work (not at the end). Structure:

```markdown
# Implementation <TICKET>

## Brief MR/PR #N
<3-5 bullets of what the user will be able to do after this MR/PR, in business language>

**This MR/PR does NOT include**:
- <pieces left out>

## Changes by file
- <file> — what changed and why (1 line each)

## Decisions made during implementation
- Decision: …
  - Why: …
  - Discarded alternative: …

## Access paths implemented
<one row per query written or changed; omit if none. `Plan` is what `data.explain_cmd` returned, or "unverified" when the repo has no way to get one — never a guess.>

| Query (file:line) | Filter · order (direction) · bound | Index it uses | Plan |
|---|---|---|---|

## Design deviations
- Design said X → did Y because Z

## Relevant commands run
- <quality.style_fix from FLOW.md>
- <quality.db_update from FLOW.md>
- …

## Pending
- [ ] …

## Ideas for separate tickets
<things that came up during the build and were decided NOT to include; each with one line: "what" + "why it makes sense as its own ticket">
```

## 4. Quality during implementation

As large pieces are finished:

- Run `quality.style_fix` from `FLOW.md` to fix style; if empty, auto-discover (e.g. from Makefile or npm scripts).
- Run `quality.static_analysis` from `FLOW.md` when a piece is stable; if empty, auto-discover.
- If you added tests, run them with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover. **A filtered run is judged by how many tests it executed, never by its exit code.** Almost every runner exits `0` when the filter matches nothing (`OK, 0 tests`, `No tests ran`, `0 passed`), so a typo in `{FILTER}`, a renamed test class, or a test in a suite the filter never reaches are indistinguishable from green. Read the executed count **and** the executed names: if the count is `0`, or the tests you just wrote are not among them, **the run did not happen** — treat it as a failure, fix the filter, run again. If the runner reports no count, drop the filter and run the whole test file. Record the count you actually saw, not just the command.

Don't do the code review here — that's `/flow-feat-review`.

## 4.1 Is the design still valid?

Review the "Design deviations" section of `05-implementation.md`. If **any** of the following is true:

- **2+ significant deviations** (module change, different event contract, different entity, new repository not foreseen).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.
- **A design piece appears that the previous inventory didn't detect** and that changes the plan.
- **A primitive materialized with a different name/role than the design named it** (design said *Query*, code built a *Command*; design said *service*, code built a *handler* wired through a bus). This is **vocabulary drift**: either the design's naming was wrong (update `03-design.md`) or the code chose the wrong primitive (fix the code). Reconcile it now — don't let the design and the code disagree on what each piece *is*, because `/flow-feat-review §5.5` and the reader will judge the code, not the design's intent.

**Pause the build and go back to `/flow-feat-design`** to update the document. Don't keep implementing against a design that's no longer true — `/flow-feat-review` and `/flow-feat-validate` read `03-design.md` as truth and will make wrong judgments if it lies.

If the deviations are small (renames, local adjustments), that's fine: note them and continue.

## 4.2 Textual contract check (before closing)

If in §2.0bis you copied contracts into `05-implementation.md`, **before marking the build as done** you must confront the code against each cited contract. **This is not a test to run** — it's a deliberate textual comparison you make as the agent, not delegated to a test runner.

For each contract in "Contracts to respect":

1. Locate the shape construction in the code (the controller's array, the event's constructor, the column migration, the metrics client call, etc.).
2. Dump the **keys and nesting** that code produces (or the literal it emits, in the case of a header/route).
3. Compare **key by key, character by character** against the literal quote copied in §2.0bis.
4. If anything differs — a key in camelCase vs snake_case, a different nesting level, an extra or missing key, a singular vs plural suffix — **go back and edit the code** to match. Don't proceed to close with a mismatch.

Record the result in `05-implementation.md` under "## Contract verification":

```markdown
## Contract verification (§4.2)
- Contract N "<description>": code produces <real shape>, declaration says <declared shape>. ✅ matches / ❌ fixed in commit X.
```

If there were no copied contracts (design said "none"), skip this step and record: "## Contract verification — N/A (no external contracts)".

## 5. Close

- Update `meta.json`: `phase = "build"`, add to `phases_done`.
- If it's a multi-MR/PR build, leave the current MR/PR as `in_progress` in `meta.json.mrs`; it will move to `merged` when `/flow-feat-ship` confirms the merge. **Also add `build` to that MR/PR's own `phases_done`** (its `mrs[]` entry) — the per-MR/PR marker the downstream gates read.
- Summarize to the user in bullets: files touched (high level), pending items, **result of §4.2 (contracts verified)**, and next command: `/flow-feat-review`.
- **Autonomy handoff.** In `manual`, stop here and propose `/flow-feat-review` as a question, invoking it only on confirmation. In `guided`/`auto`, **chain into `/flow-feat-review` automatically** in this same turn. Naming the next command and then stopping is only correct in `manual`.
