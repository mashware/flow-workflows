---
description: Implement the feature following the approved design and keep a running log
---

# `/flow:feat:build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Models — which one runs this step.** Read `models` from `FLOW.md`. **This command's key is `code`**; empty (or no `models` section) = run with the model you were launched with, and say nothing about it. When it is set: pass it to every subagent **this command decides to launch**, except one named in `agents.<role>` — that agent keeps the model its own definition sets, because you configured it there. Parallel fan-out rounds take `models.workers` when set, otherwise this command's key. For the parts you perform **yourself** you cannot switch your own model: when the configured value differs from the model you are running, state it in one line at the handoff (`this step is configured for <value>, you are on <current>` → `/model <value>`), record it in the phase artifact, and **continue**. That is flow mechanics — never a question in `guided`/`auto`, never a hard gate. If the harness cannot set a model per subagent, note it once and carry on with the inherited one.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

**Never a question in `guided`/`auto` — decide, record, continue.** The hard gates above stop in *every* mode; these stop in *none* of `guided`/`auto`, and asking them anyway is the single most common way an unattended run ends up feeling manual. (a) **Flow mechanics** — whether to launch a panel, challengers, a skeptic filter or a parallel fan-out, how wide it goes, how many reviewers, inline vs subagent: that is your judgement on cost and latency, not the user's decision, and each step's recommended default *is* the answer. (b) **WIP commits** on the work branch. (c) **Continuing to the next MR/PR of a train** when `git.train_chain` resolves to `always`. (d) **Size confirmation** — take the proposed size, record it, move on. (e) **Anything already decided and recorded** in this work's artifacts or `meta.json.notes`: reopening a settled decision is not prudence, it makes the user decide twice and costs them their trust that a decision *stays* decided. Reopen only when new evidence contradicts the premise it rested on — and then lead with the evidence, not with the question.

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

**Out of the chat, into the artifact**: narrating your own process or your own mistakes, correcting your subagents' reports, bookkeeping (directory names, how you located `meta.json`), and anything a previous stop already said. **Subagent completion or idle notifications never earn a turn of their own** — absorb them into the next real stop.

**Zero-context rule.** Write for someone who just sat down. The first mention of a code identifier (class, method, constant, error code) carries 4–6 words of what it is — not `fromStored()` but "`fromStored()`, the method that rehydrates a stored token". Never cite a section number (`§4.2`) without naming what it is. No jargon the user has not used first.

**If it is a question, it is `AskUserQuestion`.** Never end a message with a question in prose: in `manual` it hides among the text, and in `guided`/`auto` it is a stop the mode never authorized. If it does not deserve the menu, it is not a question — it is a decision you take and record.

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

Implementation phase. Code is written here.

## 1. Pre-flight

- Load `meta.json` by current branch.
- For `size` M/L: require that both `03-design.md` **and** `04-mr-plan.md` exist. If the plan is missing, send to `/flow:feat:plan`. If the design is missing, send to `/flow:feat:design`.
- For `size` XS/S: allow starting without a design but ask the user for a 2-3 line note on what will be done and save it as a minimal `03-design.md`. There is no MR/PR plan (always 1 MR/PR).
- Read all prior artifacts.
- **If `meta.json.mrs` has more than one entry**: pick the **startable** MR/PR — the `pending` one with the **lowest `n` whose `depends_on` are all `merged`**. An MR/PR whose dependencies are still `pending`/`in_progress` is **not** startable yet, even if its `n` is low. Because `n` follows the execution order (see `/flow:feat:plan`), the startable one is normally the lowest-`n` pending entry; `depends_on` is the guard for trains where an earlier MR/PR has not merged. (If entries have no `wave`/`depends_on` — an older plan — fall back to "first pending by `n`".)
  - **Parallel siblings**: if several `pending` MRs/PRs in the **same `wave`** are startable and have no dependency between them, they can be built in parallel or as a train. In `manual`, tell the user and let them choose which to take now (default: lowest `n`); in `guided`/`auto`, take the lowest `n` and record the choice. Mark the chosen one as `in_progress`.
  - If all are `merged`, warn: feature is done, nothing to build.
  - If some are `pending` but **none** is startable (all blocked by unmerged dependencies), do not start anything: tell the user which MR/PR needs to merge to unlock the next wave and stop.
  - **Train/stacked**: this MR/PR needs its own branch stacked on the previous one — do **not** keep committing on the previous MR/PR's branch. `/flow:feat:ship §6.2` creates and links it when it chains here; if you reached this step directly (not via that chain) and you are still on the previous branch, create the next branch now following `/flow:feat:start §5` (explicit base = the previous MR/PR's branch, `--no-track`, worktree per `git.worktree`) and, for `tracker.tool: gh`, the linked-branch step `/flow:feat:start §5.5`. Record `stacked_on` in `meta.json`. The train does **not** wait for the previous MR/PR to merge.

## 2. Business brief (before typing)

**Before loading skills, creating tasks, or any edits**, write a brief in **business** language (not technical) specific to **this concrete MR/PR** (the `in_progress` one in `meta.json.mrs`, not the full feature):

```
Brief MR/PR #N: <title>

After this MR/PR:
- The user will be able to <X>.
- The system <will do Y / will stop doing Z>.
- <success metric if applicable>.

This MR/PR does NOT include:
- <piece Y that belongs to MR/PR #N+1>.
- <related functionality decided against>.
- <tempting scope that is out>.
```

Rules for writing it:
- **Business language**: say "the user will be able to filter campaigns by date", not "create the endpoint `GET /campaigns?from=...`".
- **Specific to this MR/PR**: if the feature has 4 MRs/PRs, the brief only covers what this one contributes — not the full feature.
- **"Does NOT include" is mandatory**: even if it seems redundant with `04-mr-plan.md`, repeating it here fixes the scope. If you do not know what to put, the plan is wrong.
- 3-5 bullets in each list. More is noise.

**Ask the user with `AskUserQuestion`** whether the brief reflects what they expect — **in every autonomy mode, `auto` included**. This one is deliberate, not an oversight: it is the last point where the scope can be corrected before there is a diff to argue with, and scope creep is invisible in code review once it is mixed in with everything else.

Because in `guided`/`auto` this is one of the only two stops per MR/PR, it carries the **full stop header** from the Reporting preamble above it — ticket, size, phase, `MR #<n> of <N>`, plan state — followed by the brief. In a 7-MR/PR work the brief alone is unreadable: "#3 of 7, two shipped" is what tells the user where they are before they judge the scope. Options:
- **Yes, proceed** → start building.
- **No, something is extra or missing** → the user clarifies, adjust the brief, and ask again. **Do not touch code** until the brief is confirmed.

Save the brief at the top of `05-implementation.md` under "## Brief MR/PR #N". It acts as the contract for the rest of the build: if the temptation to do something not in the brief arises, return to §2.4 before doing it.

## 2.0bis Copy design contracts (verbatim, do not paraphrase)

**Before writing code**, open `03-design.md` and locate the **"External contracts"** section. For **each contract** declared there (HTTP body, header, route, event, column, metric), **copy it literally** into `05-implementation.md` under a new section:

```markdown
## Contracts to respect (copied verbatim from 03-design.md §"External contracts")

### Contract N: <description>
- **Literal shape**:
  <BLOCK COPIED AS-IS, no rewriting, no paraphrasing, no "I think it was like this">
- **Pattern deviation** (if applicable): <copied from design>
```

Hard rules:
- **Copy, do not rewrite.** The goal is to anchor attention: when later deciding between following a repo pattern or the declared contract, the contract lives in the file you are writing, not in another you are no longer reading.
- **If the design wrote the contract in prose** (without a literal shape), convert that contract to literal format here and note it in the user report: "contract N was in prose in the design, I have converted it to literal — please confirm it is correct". Do not advance until confirmed.
- **If there is a "Pattern deviation" section**: copy it too. It reminds you at coding time not to mimic the repo pattern even if your hand drifts there.
- **If the design says "none"** (no external surfaces), skip this step and record: "## Contracts to respect — none declared in design".

Without this copy, do not proceed to §2.1.

## 2.1 Work

Load the project skills (see `FLOW.md` section `conventions`).

**Comment discipline.** Add a comment only when it earns its place: to explain a *why* the code cannot (a non-obvious constraint, a workaround and its reason, a subtle invariant). Do not narrate *what* the code already states, do not restate the design, and match the surrounding file's comment density — an over-commented change reads as noise and rots as the code moves on. **Never write the ticket ID, task/step number, or "for MR #N" into a code comment**: that traceability belongs in the commit, branch and MR/PR, not in the source. A comment that only makes sense to someone reading this MR/PR today does not belong in the code.

**Borrowed code carries its reason.** When you lift a structure from another file in the repo — a `catch` block, a guard clause, a mapper, a config stanza, a test setup — you are importing decisions made for *that* file's situation, not for yours. Before keeping it, name under "Decisions made during implementation" in `05-implementation.md` where it came from and **what makes it apply here**: the exception it catches is actually thrown on this path, the guard's precondition can actually be false here, the mapped field actually exists on this shape. If you cannot name that reason, do not copy it — write what this code needs or leave it out. Borrowed-and-plausible is the most expensive kind of line to put in a diff: it reads as deliberate, so a reviewer spends real attention before discovering it was never chosen at all. This is the same anti-drift rule as §2.0bis, applied to code instead of contracts.

**A query is written against the schema, not against the mapping.** When you write or change a data-access query — raw SQL, the ORM's query language, a query-builder chain, a repository finder, an aggregate, a bulk write — check **before** you consider it done: the index that will serve its filter *and* its order **in that direction** actually exists (read the schema, not the entity mapping); the bound is real and, if the requirement is "the latest k per key", it is not a global limit; both key columns of every join have the same type, length and charset/collation; no heavy column is read in a pass that only decides which rows survive. Take the shape from the **Access paths** table in `03-design.md`; if what you are writing does not match a row there, that is a design deviation to log, not a detail to absorb. Where `data.explain_cmd` is set in `FLOW.md`, get the plan of the new query now and paste it under "Access paths implemented" in `05-implementation.md` — three lines here save the round trip that `/flow:feat:review §3.6` or a reviewer would otherwise spend. Where it is not set, say the plan is unverified. Do **not** invent an index or a schema change to make your query work: a new index or a collation change is a schema change, a hard gate, and it goes back through the design.

**If in a multi-MR/PR build**: limit yourself to what the current MR/PR covers per `04-mr-plan.md`. Any code belonging to a later MR/PR is scope creep; cut it or isolate it behind a feature flag / dead code temporarily per the plan. If it cannot be isolated, pause and return to `/flow:feat:plan` to cut it.

Choose execution mode:

- **Single-thread (XS/S/M)**: implement yourself, step by step, using subagents only as point consultants when blocked: the `agents.architecture` agent from `FLOW.md` for layer questions (or `Agent general-purpose` if empty), and the `agents.persistence` one for query/mapping questions (or `Agent general-purpose` if empty).
- **Partial delegation (M/L with clear pieces)**: use `Agent` for isolated endpoints, and the `agents.testing` agent from `FLOW.md` in parallel to prepare the test suite (or `Agent general-purpose` if empty). Pass the full `03-design.md` in the prompt so agents do not invent things.

Use `TaskCreate` to track the steps from the design's implementation plan. Mark each step `in_progress` when starting and `completed` when done — do not batch.

### 2.2 Checkpoints (local commits, gated by `autonomy.mode`)

The step's changes are **always reported before anything is recorded**. Who decides the commit is what changes with the mode from the preamble:

- **`manual`** — the agent **does not run `git commit` on its own**. Commits are **opt-in from the user**: without your explicit confirmation, changes stay in the working tree so you can validate them first (test the UI, run the flow, read the diff).
- **`guided`** — ask **once**, at the first step, and apply that answer to the rest of this build; record it in `05-implementation.md`. Do not re-ask per step.
- **`auto`** — commit the step's WIP yourself and continue, without asking. **Invoking a flow command with `autonomy.mode: auto` is the explicit authorization** the system rule (*never commit unless the user asks*) requires — the same reasoning that makes the commits in `/flow:feat:ship` authorized, because that is the command's stated purpose. It authorizes **only** WIP commits on the work branch: push and MR/PR creation remain hard gates in every mode.

**After completing each `TaskCreate` step**, the agent:

1. **Marks the step as `completed`** in `TaskCreate`.
2. **Reports to the user** a step summary (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<add> / -<del> lines
     Suggested validation: <e.g. "run the unit test command for Foo" or "open the UI at /section">
   ```
3. **Then, per mode**: in `guided`/`auto`, run `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` (per the rule above) and start the next step without pausing — **the step summary above is a report, not a question**, so do not append "shall I commit and move on?" to it in these modes; that stop is in the never-ask block of the preamble. In `manual`, **do not commit** — wait for the user to say what to do. Options:
   - **"Commit now"** or **"OK, continue"** → agent runs the same `git add … && git commit …` and continues with the next step.
   - **"Wait, I'll validate"** → agent stays still. You validate at your own pace. When you return, decide commit or adjustment.
   - **"Something needs to change"** → agent adjusts. The step's commit stays pending until you give OK.
   - **"Continue without committing, we'll group later"** → agent starts the next step without committing. Changes accumulate in the working tree (risk: if a hot cut occurs per §2.3, there are fewer clean points).

Rules for when a commit does happen:
- One commit per step (when done). Do not batch multiple steps into one commit unless you explicitly request it.
- `--no-verify` is allowed **only for WIP commits** (slow hooks will run at the end in `/flow:feat:review` and in the final commit of `/flow:feat:ship`).
- These commits are squashed on merge (if `git.squash` is `true`), so they do not need to be pretty — they are just cuttable units.
- If a step is left halfway (interruption, change of focus) and you ask for a commit, the message has the suffix: `WIP <TICKET>: <step> (partial)`.

**Why this model**: in `manual`, two reasons. (1) You validate locally before anything is committed, so you do not end up with a branch full of commits without having seen the changes running. (2) If you decide to commit occasionally, the WIP commits still serve as cuttable units for §2.3. If you decide not to commit until the end, you lose that granularity — that is your decision, not the agent's. In `guided`/`auto` you traded that step-by-step inspection for an unattended build, and the WIP commits are what you get in exchange: the diff is still all there to read, cut by step, and the branch is never pushed without the §6 gate in `/flow:feat:ship`.

### 2.3 Size thermometer and hot cut

**After each completed step** (whether committed or not), compare the real size against the estimate for the current MR/PR in `meta.json.mrs`. Check commits + staged + unstaged, not just commits:

```bash
# Committed changes over the base branch:
git diff --shortstat <git.default_base>..HEAD     # lines
git diff --name-only <git.default_base>..HEAD | wc -l   # files

# Working tree changes (uncommitted):
git diff --shortstat HEAD             # uncommitted lines
git status --short | wc -l            # modified/untracked files
```

Sum both sides to get the real total size of the current MR/PR.

Warning thresholds:
- **Real lines > `lines_est * 1.5`**, or
- **Real files > `files_est + 2`**.

If either is exceeded, **pause** and ask the user with `AskUserQuestion` (options, in this order):

1. **Cut here (recommended if the current piece is coherent)**. What has been built so far stays as this MR/PR. What remains of the plan is distributed into a new one inserted in `meta.json.mrs` right after. Zero code wasted.
2. **Continue and record the overrun**. Useful if the cut would be artificial. The deviation is noted in `05-implementation.md` to calibrate `/flow:feat:plan` on future tickets.
3. **Reopen plan**. Return to `/flow:feat:plan` to rethink the entire split. Only if the overrun indicates the plan is wrong at a deeper level, not just that this MR/PR is slightly underestimated.

**Hot cut mechanics (option 1)**:

0. **If there are uncommitted changes** in the working tree: warn the user and ask them to decide before cutting. Either commit what is done as a WIP for the corresponding step, or stash it (`git stash`) so it does not mix with the next MR/PR. Without this, the cut leaves loose changes that belong to one side or the other without knowing which.
1. Identify a cut point: the last WIP commit where the piece is coherent and mergeable (a closed sub-goal: "endpoint and DTO done", "migration applied", "flow X tests green"). Do not cut in the middle of a change.
2. Edit `meta.json.mrs`:
   - The current MR/PR keeps `n`, `title`, `wave` and `depends_on`, adjust `lines_est` and `files_est` to actuals, and stays `in_progress`.
   - Insert a new one with the next `n` (renumbering subsequent ones if any), `title` describing what remains, `status: "pending"`, `phases_done: []` (a fresh MR/PR earns its own review/validate), `depends_on: [n_current]` (the remainder needs the cut piece first), `wave` = one after the current one, and new `lines_est` and `files_est` (indicative). If you renumber subsequent entries, **update their `depends_on` references accordingly** so no `depends_on` points to a higher `n` than its own.
3. Edit `04-mr-plan.md`: split the original entry in two, keeping the standalone-mergeable justification for both halves.
4. Note in `05-implementation.md` under "Hot cut": date, reason, what stays and what moves to the next one.
5. **Do not rewrite history with `git rebase`**: the WIP commits that belong to the next MR/PR stay in the current branch. When the time comes to build the next one, start from a new branch over the base, and those commits are transferred with `git cherry-pick` or equivalent. This is documented and executed in `/flow:feat:ship` or when starting the next `/flow:feat:build`.

**If there was already a cut and overrun happens again**: ask the user before cutting again — a second cut on the same MR/PR signals that the plan is wrong, not just that the estimate is slightly off. The right option is probably **3 (reopen plan)**.

### 2.4 Does something fall outside the brief?

If during the build the temptation arises to add something **not in the §2 brief** ("while I'm here…", "this test would also cover X…", "this rename would improve Y…"):

**Pause before doing it** and ask the user with `AskUserQuestion`:
- **Yes, add it to the brief** — update the brief in `05-implementation.md` and continue. (If the addition is large, consider §2.3: it could trigger a MR/PR cut.)
- **No, leave it out** — note it in the "Ideas for separate tickets" section of `05-implementation.md` and continue with the original brief.

The rule: anything unforeseen **always** goes through the user before entering code. That is what filters scope creep that is invisible in code review (because it is already mixed in with everything else).

## 3. Log

Keep `.claude/work/<TICKET>/05-implementation.md` updated as you work (not at the end). Structure:

```markdown
# Implementation <TICKET>

## Brief MR/PR #N
<3-5 bullets of what the user will be able to do after this MR/PR, in business language>

**This MR/PR does NOT include**:
- <pieces that are out of scope>

## Changes per file
- <file> — what changed and why (1 line each)

## Decisions made during implementation
- Decision: …
  - Why: …
  - Discarded alternative: …

## Access paths implemented
<one row per query written or changed; omit the section if none. `Plan` is what `data.explain_cmd` returned, or "unverified" when the repo has no way to get one — never a guess.>

| Query (file:line) | Filter · order (direction) · bound | Index it uses | Plan |
|---|---|---|---|
| `FooRepository::findBar()` | `a IN (…)` · `b DESC` · 15 per key | `barIdx (a,b)` | backward index scan, 750 rows read |

## Deviations from design
- Design said X → did Y because Z

## Relevant commands executed
- <quality.style_fix from FLOW.md>
- <quality.db_update from FLOW.md>
- …

## Pending
- [ ] …

## Ideas for separate tickets
<things that came up during the build and were decided NOT to include; each with one line: "what" + "why it makes sense as its own ticket">
```

## 4. Quality during implementation

As larger pieces are completed:

- Run `quality.style_fix` from `FLOW.md` to fix style; if empty, auto-discover (e.g. from Makefile or npm scripts).
- Run `quality.static_analysis` from `FLOW.md` when a piece is stable; if empty, auto-discover.
- If tests were added, run them individually with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover. **A filtered run is judged by how many tests it executed, never by its exit code.** Almost every runner exits `0` when the filter matches nothing (`OK, 0 tests`, `No tests ran`, `no tests to run`, `0 passed`), so a typo in `{FILTER}`, a renamed test class, or a test living in a suite the filter never reaches are all indistinguishable from green. Read the executed count **and** the executed test names from the output: if the count is `0`, or the tests you just wrote are not among the names, **the run did not happen** — treat it as a failure, fix the filter, run again. If the runner reports no count, drop the filter and run the whole test file. In "Relevant commands executed", record the count you actually saw, not just the command — "green" without a number is not evidence that anything ran.

Do not do code review here — that is `/flow:feat:review`.

## 4.1 Is the design still valid?

Review the "Deviations from design" section of `05-implementation.md`. If **any** of the following applies:

- **2+ significant deviations** (module change, different event contract, different entity, unforeseen new repository).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.
- **A design piece appears that the prior inventory did not detect** and that changes the plan.
- **A primitive materialized with a different name/role than the design named it** (design said *Query*, code built a *Command*; design said *service*, code built a *handler* wired through a bus). This is **vocabulary drift**: either the design's naming was wrong (update `03-design.md`) or the code chose the wrong primitive (fix the code). Reconcile it now — do not let the design and the code disagree on what each piece *is*, because `/flow:feat:review §5.5` and the reader will judge the code, not the design's intent.

**Pause the build and return to `/flow:feat:design`** to update the document (and, if it affects splitting, also to `/flow:feat:plan`). Do not keep implementing against a design that is no longer true — `/flow:feat:review` and `/flow:feat:validate` read `03-design.md` as truth and will make incorrect judgments if it lies.

If the deviations are minor (renames, local adjustments), that is fine: note them and continue.

## 4.2 Textual contract check (before closing)

If §2.0bis copied contracts into `05-implementation.md`, **before marking the build as done** you must compare the code against each cited contract. **This is not a test to run** — it is a deliberate textual comparison you make as the agent, not delegated to the test runner.

For each contract in "Contracts to respect":

1. Locate in the code the construction of the shape (the controller array, the event constructor, the column migration, the metrics client call, etc.).
2. Dump the **keys and nesting** that code produces (or the literal it emits, in the case of a header/route).
3. Compare **key by key, character by character** against the literal quote copied in §2.0bis.
4. If anything differs — a key in camelCase vs snake_case, a different nesting level, an extra or missing key, a singular vs plural suffix — **go back and edit the code** to match. Do not advance to close with a mismatch.

Record the result in `05-implementation.md` under "## Contract verification":

```markdown
## Contract verification (§4.2)
- Contract N "<description>": code produces <actual shape>, declaration states <declared shape>. ✅ matches / ❌ adjusted in commit X.
```

If there were no copied contracts (design said "none"), skip this step and record: "## Contract verification — N/A (no external contracts)".

## 5. Close

- Update `meta.json`: `phase = "build"`, add to `phases_done`.
- If multi-MR/PR build, leave the current MR/PR as `in_progress` in `meta.json.mrs`; it will become `merged` when `/flow:feat:ship` confirms the merge. **Also add `build` to that MR/PR's own `phases_done`** (its `mrs[]` entry) — the per-MR/PR marker the downstream gates read.
- Report to the user **following the stop header** from the Reporting preamble, then in bullets: files touched (high level), pending items, **result of §4.2 (contracts verified)**. The next command is `/flow:feat:review` — in `guided`/`auto` you are about to run it in this same turn, so say that in the `I need:` line ("nothing, chaining into review"), never as a question.
- **Autonomy handoff.** Apply the `autonomy.mode` from the preamble — the summary is a report, not the end of the flow. In `manual`, stop here and propose `/flow:feat:review` with a single `AskUserQuestion` (recommended option by default); invoke it only if the user confirms, and never make them type it. In `guided`/`auto`, **chain into `/flow:feat:review` automatically** in this same turn, without asking. Do not end the turn leaving the next command as a suggestion: in these modes, "the next command is X" and stopping are contradictory, and the mode already decided which of the two wins.
