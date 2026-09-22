---
description: Implement the feature following the approved design and keep a running log
---

# `/flow:feat:build`

Load the `flow:flow-core` skill first (shared rules: `FLOW.md` step 0, models, autonomy modes and hard gates, how a stop reads, the live panel, `00-summary.md`) — skip if it is already in this session's context. **Models: the subagents it launches take `models.agents`.**

Implementation phase. Code is written here.

## 1. Pre-flight

- Load `meta.json` by current branch. Read `meta.json` and `00-summary.md`; open in full only `03-design.md` (§"External contracts", verbatim) and the current MR/PR entry of `04-mr-plan.md`. (flow-core §5)
- `size` M/L: require both `03-design.md` **and** `04-mr-plan.md`. Plan missing → send to `/flow:feat:plan`; design missing → send to `/flow:feat:design`.
- `size` XS/S: may start without a design — ask the user for a 2-3 line note on what will be done and save it as a minimal `03-design.md`. No MR/PR plan (always 1 MR/PR).
- **If `meta.json.mrs` has more than one entry**: pick the **startable** MR/PR — the `pending` one with the **lowest `n` whose `depends_on` are all `merged`**. Dependencies still `pending`/`in_progress` → not startable, even with a low `n`. (No `wave`/`depends_on` — an older plan — → "first pending by `n`".)
  - **Parallel siblings**: startable `pending` MRs/PRs in the **same `wave`** with no dependency between them can be built in parallel or as a train. `manual`: let the user choose which to take now (default: lowest `n`); `guided`/`auto`: take the lowest `n`, record the choice. Mark the chosen one `in_progress`.
  - All `merged` → warn: feature is done, nothing to build.
  - Some `pending` but **none** startable → start nothing: tell the user which MR/PR must merge to unlock the next wave, and stop.
  - **Train/stacked**: this MR/PR needs its own branch stacked on the previous one — do **not** keep committing on the previous MR/PR's branch. `/flow:feat:ship §6.2` creates and links it when it chains here; if you arrived directly and are still on the previous branch, create it now per `/flow:feat:start §5` (explicit base = the previous MR/PR's branch, `--no-track`, worktree per `git.worktree`) and, for `tracker.tool: gh`, the linked-branch step `/flow:feat:start §5.5`. Record `stacked_on` in `meta.json`. The train does **not** wait for the previous MR/PR to merge.

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
- **Business language**: "the user will be able to filter campaigns by date", not "create the endpoint `GET /campaigns?from=...`".
- **Specific to this MR/PR**: with 4 MRs/PRs, the brief covers only what this one contributes — not the full feature.
- **"Does NOT include" is mandatory**, even if it seems redundant with `04-mr-plan.md`. If you do not know what to put, the plan is wrong.
- 3-5 bullets in each list.

**Ask the user with `AskUserQuestion`** whether the brief reflects what they expect — **hard gate, in every autonomy mode, `auto` included**: it is the last point where scope can be corrected before there is a diff to argue with.

In `auto` this is one of the only two stops per MR/PR (`guided` adds the plan of §2.0ter on a big one), so it carries the **full stop header** (flow-core §3) — ticket, size, phase, `MR #<n> of <N>`, plan state — followed by the brief. Options:
- **Yes, proceed** → start building.
- **No, something is extra or missing** → the user clarifies, adjust the brief, ask again. **Do not touch code** until the brief is confirmed.

Save the brief at the top of `05-implementation.md` under "## Brief MR/PR #N". It is the contract for the rest of the build: anything not in the brief goes through §2.4 before it is done.

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
- **Copy, do not rewrite.** The contract must live in the file you are writing, so it wins when a repo pattern tempts you away from it.
- **If the design wrote the contract in prose** (no literal shape), convert it to literal format here and note it in the user report: "contract N was in prose in the design, I have converted it to literal — please confirm it is correct". Do not advance until confirmed.
- **If there is a "Pattern deviation" section**: copy it too — it reminds you at coding time not to mimic the repo pattern.
- **If the design says "none"** (no external surfaces), skip this step and record: "## Contracts to respect — none declared in design".

Without this copy, do not proceed to §2.0ter.

## 2.0ter Plan this MR/PR (size-gated)

`03-design.md` §"Implementation plan (order)" is the **feature's** order, written before `/flow:feat:plan` split anything — it does not know which of its steps belong to this MR/PR. The brief above says what this MR/PR delivers in business terms; neither says which files are touched in which order. On a MR/PR big enough to lose its thread, that plan is written here.

**Gate — run this step only when the current `mrs[]` entry is big enough**: `lines_est > 150` **or** `files_est > 5`. No estimates in the entry (an older plan) → fall back to its `size`: `M`/`L` run it, `XS`/`S` skip. No `mrs[]` at all (XS/S, single MR/PR) → skip; the brief and the contracts are the whole plan, and a 30-line change does not earn a planning round. Skipped → record one line in `05-implementation.md` — the estimates that let it through (`plan: skipped — 40 lines / 2 files`), or `plan: skipped — single MR/PR` when there is no entry to read — and go to §2.1.

Write it against `03-design.md` and the contracts just copied — **no code yet, no exploratory edits**. Under 250 words, as numbered steps:

```markdown
## Plan MR/PR #N
1. <step> — `<file or path>` — <test that proves it, or "covered by step M">
2. …

- **Point of no return**: <the migration, contract, published event or flag after which rollback stops being a revert — or "none">.
- **Out of this plan**: <what belongs to a later MR/PR and will be tempting while inside these files>.
```

Rules for the steps:
- **A step is a thing on disk**, not a phase of thought: "add the nullable column + migration", not "analyse the schema". A step nobody can tell is finished is two steps or none.
- **Order by what unblocks what**, and put the point of no return as late as the design allows: everything reversible lands before it.
- **Every step names its test** or the step that covers it. A step that proves no acceptance criterion and guards no contract is a candidate to cut — same bar as `03-design.md` §"Planned tests".
- Steps come from the **design**, not from the repo you are about to open. A step the design never mentions is either a deviation to log (§3 "Deviations from design") or scope that belongs in §2.4.

**Present it, then behave by mode:**
- `manual` / `guided` → **stop**: full stop header (flow-core §3), the plan, and one `AskUserQuestion` — **Approve and build** · **Change the order or the steps** (the user edits, rewrite it, ask again). This is a genuine decision point: the order of an irreversible step is exactly what is expensive to argue with once there is a diff.
- `auto` → **do not stop**. Print the numbered steps and the point of no return, record the plan as accepted, and open the same message with the call that starts §2.1 (flow-core §3: a report is never the last thing in a turn you meant to continue).

Save it in `05-implementation.md` under `## Plan MR/PR #N`, right after the brief. It is what seeds `TaskCreate` in §2.1, and what a §2.3 hot cut splits: the steps already done stay in this MR/PR, the ones still pending move to the new entry.

## 2.1 Work

Apply the repo's `conventions` from `FLOW.md` (free text: layers, patterns, prohibitions) as written. Load project skills that encode them if the harness exposes any; otherwise the `conventions` text is the whole instruction.

**Comment discipline.** Comment only for a *why* the code cannot state (non-obvious constraint, workaround and its reason, subtle invariant). Do not narrate *what* the code does or restate the design; match the file's comment density. **Never write the ticket ID, task/step number, or "for MR #N" into a code comment** — traceability lives in the commit, branch and MR/PR.

**Borrowed code carries its reason.** When you lift a structure from another file (a `catch` block, guard clause, mapper, config stanza, test setup), record under "Decisions made during implementation" in `05-implementation.md` where it came from and **what makes it apply here** (the exception is actually thrown on this path, the guard's precondition can actually be false here, the mapped field exists on this shape). No nameable reason → do not copy it; write what this code needs or leave it out. Same anti-drift rule as §2.0bis, applied to code.

**A query is written against the schema, not against the mapping.** Before any data-access query (raw SQL, ORM query, query-builder chain, repository finder, aggregate, bulk write) counts as done, check:
- the index serving its filter *and* its order **in that direction** exists — read the schema, not the entity mapping;
- the bound is real; "the latest k per key" is not a global limit;
- both key columns of every join share type, length and charset/collation;
- no heavy column is read in a pass that only decides which rows survive.

Take the shape from the **Access paths** table in `03-design.md`; a query matching no row there is a design deviation to log. `data.explain_cmd` set in `FLOW.md` → get the plan now and paste it under "Access paths implemented" in `05-implementation.md` (spares `/flow:feat:review §3.6` the round trip); not set → say the plan is unverified. Do **not** invent an index or a collation change to make a query work: that is a schema change, a hard gate, back through the design.

**Multi-MR/PR build**: only what the current MR/PR covers per `04-mr-plan.md`. Code for a later MR/PR is scope creep: cut it or isolate it behind a feature flag / dead code temporarily per the plan; if it cannot be isolated, pause and return to `/flow:feat:plan` to cut it.

Execution mode:

- **Single-thread (XS/S/M)**: implement yourself, step by step; subagents only as point consultants when blocked — `agents.architecture` from `FLOW.md` for layer questions, `agents.persistence` for query/mapping questions (`Agent general-purpose` if either is empty).
- **Partial delegation (M/L with clear pieces)**: `Agent` for isolated endpoints, plus `agents.testing` from `FLOW.md` in parallel to prepare the test suite (`Agent general-purpose` if empty). Pass the full `03-design.md` in the prompt so agents do not invent things.

  A brief here states the **output** as explicitly as the input (flow-core §6):
  - **Name the path the agent writes**, and require it to **save after each finished piece, not at the end**. Code, tests and generated content are the deliverable; the report is not. Then **verify the file** instead of believing the report — a piece half-written on disk is recoverable, what only exists in the agent's context is lost the moment it is stopped.
  - **End the brief with the report contract** — under `agents.report_max_words` (empty → 250): what it wrote, where, what it could not do. A report long enough for the harness to truncate reaches you as silence.
  - **Give it a bounded first step.** A piece with no natural first move ("do the whole module") produces nothing for hours; split it by file or by numbered step until it has one.
  - **Check the round at every stop of this command**, not only at the end: an agent past `agents.stall_after_minutes` (empty → 25) with nothing written to its path is stopped, split in two and relaunched.

Use `TaskCreate` to track the steps of the **§2.0ter plan for this MR/PR** — one task per numbered step, same order. Step skipped there (small MR/PR) → seed from `03-design.md` §"Implementation plan (order)", taking only the steps this MR/PR covers per `04-mr-plan.md`; the feature's plan predates the split and carries steps that belong to siblings. Mark each step `in_progress` when starting and `completed` when done — do not batch.

### 2.1bis The premise this change rests on (any size, XS included)

`/flow:feat:design §6` challenges the beliefs a plan rests on — and XS never runs `design`. On a
small change, nobody contrasts the premise: `/flow:feat:review §6` will not, because it refutes
findings that were already reported and its gate needs M/L plus a diff over 150 lines. The
cheapness of the change is what closes every gate flow has, and a belief does not get safer because
the diff around it is short. Like the data-access duel (`/flow:feat:review §3.6`), this is a
**category, not a depth tier**.

**When it runs.** A premise qualifies only when all four hold:

- the implementation **depends** on it — take the belief away and the code is wrong, not merely unproven;
- it is about **code outside this diff**, a runtime behaviour, or an external contract;
- **nothing in the diff, `03-design.md` or `01-context.md` verifies it** — no test, no constraint, no plan;
- being wrong costs **data, money, a silent wrong result, or a security hole** — not a retry, a log line or a loud failure.

Fewer than four → it is a doubt, not a premise, and doubts do not get an agent: write it under
"Premises the change depends on" in §3 as the assumption it is and move on. **Once per MR/PR**: the
first qualifying premise gets the round, and a second one is recorded with what it would take to
settle it.

**How it runs.** One `Agent general-purpose`, read-only, refute-by-default, launched **before the
code that depends on the premise is finished** — a premise contested after the fact is a rewrite:

> You are a skeptic. The implementation of `<TICKET>` depends on this premise: `<premise, one sentence>`. It rests on `<file / system / contract>`, outside the diff under way. Try to REFUTE it: read the real code, schema, contract or test that would settle it, and answer FALSE (refuted), TRUE (holds — with what you read), or UNSETTLED (with what would settle it). The burden of proof is on the premise: do not argue from what is likely, and do not propose implementation. Report the premise, the evidence for and against, and what happens to the caller if it is false. Under `agents.report_max_words` words (empty → 250).

**Budget, and the autonomy rule.** It counts against `agents.budget_max` like any other round
(flow-core §6) and is **the first round this command gives up** when the budget cannot cover it —
said in one line, never silently skipped. `manual` → offer it with `AskUserQuestion` ("Challenge the
premise that X before building on it?"). `guided`/`auto` → run it and record it; it is flow
machinery, not a decision.

**The verdict, and the rule that makes it worth running.** **Refuted** → the brief or the design is
wrong, not the code: stop, say what fell, and go back (§2.4 for a brief, `/flow:feat:design` for a
contract) rather than patching around it. **Holds** → one row in §3 with what was read. **Unsettled
stays unsettled** — the same rule as the query duel's *no number, no win*: it is recorded as an open
premise, carried into the stop, and never promoted to an assumption by prose. `review` reads
`05-implementation.md` in full, so an open premise arrives there named instead of as a surprise.

### 2.2 Checkpoints (local commits, gated by `autonomy.mode`)

The step's changes are **always reported before anything is recorded**. Who decides the commit depends on `autonomy.mode`:

- **`manual`** — the agent **does not run `git commit` on its own**. Commits are **opt-in from the user**: without explicit confirmation, changes stay in the working tree for the user to validate first.
- **`guided`** — ask **once**, at the first step; apply the answer to the rest of this build and record it in `05-implementation.md`. Do not re-ask per step.
- **`auto`** — commit the step's WIP yourself and continue. **Invoking a flow command with `autonomy.mode: auto` is the explicit authorization** the system rule (*never commit unless the user asks*) requires. It authorizes **only** WIP commits on the work branch: push and MR/PR creation remain hard gates in every mode.

**After completing each `TaskCreate` step**:

1. **Mark the step `completed`** in `TaskCreate`.
2. **Report to the user** a step summary (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<add> / -<del> lines
     Suggested validation: <e.g. "run the unit test command for Foo" or "open the UI at /section">
   ```
3. **Then, per mode**: `guided`/`auto` → run `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` and start the next step without pausing — **the step summary is a report, not a question**; never append "shall I commit and move on?" (never-ask list, flow-core §2). `manual` → **do not commit**; wait for the user:
   - **"Commit now"** / **"OK, continue"** → run the same `git add … && git commit …`, continue with the next step.
   - **"Wait, I'll validate"** → stay still until the user returns and decides commit or adjustment.
   - **"Something needs to change"** → adjust; the step's commit stays pending until OK.
   - **"Continue without committing, we'll group later"** → next step without committing; changes accumulate in the working tree (fewer clean points if §2.3 cuts).

4. **Write the step into the log, committed or not.** Append one line to a `## Steps` section of `05-implementation.md` (create it at the first step):

   ```
   - <short sha> · <step name> · <n files, +a −b>
   - — · <step name> · <n files, +a −b>          ← not committed
   ```

   No question, in every autonomy mode — this is flow machinery on the never-ask list of flow-core §2. A step that was **not** committed gets its line too, with `—` where the sha would be: that is the case in `manual`, and the *"continue without committing, we'll group later"* branch above. The log then has no holes, and the absence of a commit is itself what the reader needs to see.

   The step summary was already written for every step; the sha is the one identifier that makes the log line and the git history the same record. Without it `05-implementation.md` explains *why* each change was made and names not one commit that did it, so §2.3 reads the cut point off `git log --oneline` and matches it by the prose in `WIP <TICKET>: <step>`, and a delta-scoped review (`/flow:feat:review §1.5`) can say which lines are new but not which steps they came from.

Rules when a commit does happen:
- One commit per step. Do not batch steps unless the user explicitly requests it.
- `--no-verify` **only for WIP commits** (slow hooks run in `/flow:feat:review` and in the final commit of `/flow:feat:ship`).
- WIP commits are squashed on merge when `git.squash` is `true`; they only need to be cuttable units.
- A step left halfway (interruption, change of focus) that gets committed: `WIP <TICKET>: <step> (partial)`.

In `manual`, not committing until the end loses the §2.3 cut granularity — the user's decision, not the agent's. The branch is never pushed without the §6 gate in `/flow:feat:ship`.

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

1. **Cut here (recommended if the current piece is coherent)**. What is built so far stays as this MR/PR; what remains — the §2.0ter steps still pending, or what is left of `04-mr-plan.md` where that step was skipped — goes into a new one inserted in `meta.json.mrs` right after. Zero code wasted.
2. **Continue and record the overrun**. When the cut would be artificial. Note the deviation in `05-implementation.md` to calibrate `/flow:feat:plan` on future tickets.
3. **Reopen plan**. Return to `/flow:feat:plan` to rethink the entire split. Only if the overrun shows the plan is wrong at a deeper level, not just that this MR/PR is slightly underestimated.

**None of the three is "make the diff smaller"** (flow-core §9). The estimate is a thermometer: an
overrun is answered by cutting at a coherent point or by recording it, never by deleting comments,
tests or blank lines, compressing readable code, or cutting mid-change to land under the number. The
same holds downhill — `/flow:feat:review §2.0` scales the review to the diff, so a diff trimmed to
slip under a threshold buys itself the review a smaller change had earned.

**Hot cut mechanics (option 1)**:

0. **If there are uncommitted changes** in the working tree: warn the user and ask them to decide before cutting — commit what is done as a WIP for the corresponding step, or stash it (`git stash`) so it does not mix with the next MR/PR.
1. Identify a cut point from the `## Steps` lines of `05-implementation.md` (§2.2): the last committed step where the piece is coherent and mergeable (a closed sub-goal: "endpoint and DTO done", "migration applied", "flow X tests green"). Those lines pair each step with its sha, so the cut is chosen on what the step *was* rather than re-derived from `git log --oneline` and matched by the prose in a commit message. **Name the sha in the proposal** — the user confirms an identifier, not a description. A step with `—` instead of a sha is not a cut point; it never got one. Do not cut in the middle of a change.
2. Edit `meta.json.mrs`:
   - The current MR/PR keeps `n`, `title`, `wave` and `depends_on`, adjusts `lines_est` and `files_est` to actuals, and stays `in_progress`.
   - Insert a new one with the next `n` (renumbering subsequent ones if any), `title` describing what remains, `status: "pending"`, `phases_done: []` (a fresh MR/PR earns its own review/validate), `depends_on: [n_current]`, `wave` = one after the current one, and new indicative `lines_est` and `files_est`. If you renumber subsequent entries, **update their `depends_on` references accordingly** so no `depends_on` points to a higher `n` than its own.
3. Edit `04-mr-plan.md`: split the original entry in two, keeping the standalone-mergeable justification for both halves.
4. Note in `05-implementation.md` under "Hot cut": date, reason, what stays and what moves to the next one.
5. **Do not rewrite history with `git rebase`**: WIP commits belonging to the next MR/PR stay in the current branch. When building the next one, start from a new branch over the base and transfer them with `git cherry-pick` or equivalent — executed in `/flow:feat:ship` or when starting the next `/flow:feat:build`. The shas to transfer are the `## Steps` lines below the cut point, which is what that section is for on this side of the cut too.

**If there was already a cut and overrun happens again**: ask the user before cutting again — a second cut on the same MR/PR signals the plan is wrong. The right option is probably **3 (reopen plan)**.

### 2.4 Does something fall outside the brief?

If during the build the temptation arises to add something **not in the §2 brief** ("while I'm here…", "this test would also cover X…", "this rename would improve Y…"), **pause before doing it** and ask the user with `AskUserQuestion`:
- **Yes, add it to the brief** — update the brief in `05-implementation.md` and continue. (If the addition is large, consider §2.3: it could trigger a MR/PR cut.)
- **No, leave it out** — note it in the "Ideas for separate tickets" section of `05-implementation.md` **and append it to `meta.json.followups[]`** as `kind: "out-of-scope"`, `source: "build"` (flow-core §7): the section keeps it in context, the record is what survives the archive. **Only when it clears the bar of flow-core §7** — a named subject, a path that has actually been seen, and waiting costing more than doing it now; short of that the artifact section keeps it and `followups[]` never sees it. Continue with the original brief.

Anything unforeseen **always** goes through the user before entering code.

A correction the user makes here — *«not a listener, a message handler»*, *«never mock the repository in that layer»* — is a **convention** when it would apply to an unrelated ticket in this repo: one row in `meta.json.conventions_candidates[]` and under `## Conventions learned` in `05-implementation.md`, nothing asked (flow-core §8). `ship` offers it to `FLOW.md` once, at the end.

A **product decision** the build turns out to need is neither option — not scope to add, not work to park: ask it the moment it surfaces, in every mode, and write the answer under "Decisions made during implementation" (flow-core §7, `decision`). Only a decision the user explicitly defers becomes a `followups[]` entry. A gap in the repo's own machinery (a guard that did not bind, a floor with slack) is `kind: "tooling"`: recorded, never asked about, and never sent to the tracker.

## 3. Log

Keep `.claude/work/<TICKET>/05-implementation.md` updated as you work (not at the end). Structure:

```markdown
# Implementation <TICKET>

## Brief MR/PR #N
<3-5 bullets of what the user will be able to do after this MR/PR, in business language>

**This MR/PR does NOT include**:
- <pieces that are out of scope>

## Plan MR/PR #N
<the numbered steps of §2.0ter, its point of no return and its "out of this plan" line — or one line saying the step was skipped and why (`plan: skipped — 40 lines / 2 files`). What §2.1 seeds `TaskCreate` from and what a §2.3 cut splits. Steps are struck through or annotated as they are reworked, never deleted: a plan edited to match what happened records nothing.>

## Changes per file
- <file> — what changed and why (1 line each)

## Steps
<one line per step of §2.2, in order: `- <short sha> · <step name> · <n files, +a −b>`, and `—` in place of the sha where the step was not committed. Written as each step closes, in every autonomy mode. This is what joins the log to the git history: §2.3 reads its cut point here, the transfer after a cut picks its shas here, and a delta-scoped review can say which steps a range came from. A section with no holes is the point — an uncommitted step still gets its line.>

## Decisions made during implementation
- Decision: …
  - Why: …
  - Discarded alternative: …

## Premises the change depends on
<one row per premise put through §2.1bis, plus any belief recorded as an assumption without a round. Omit the section when the change depends on nothing outside its own diff — most builds.>

| Premise | Rests on | Verdict | Evidence, or what would settle it |
|---|---|---|---|
| the upstream normalises the address before it reaches us | `InboundMailer`, outside the diff | unsettled | no test covers the unnormalised path; needs one run against prod-shaped data |

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

## Conventions learned
<rules the user taught here that would apply to any ticket in this repo, `C<n>` + the line in their own words + the stop it came from. Also `meta.json.conventions_candidates[]` (flow-core §8). Nothing is asked; `ship` offers them to `FLOW.md` once, at Close. Empty for most builds — a correction about this ticket is not a convention.>

## Ideas for separate tickets
<things that came up during the build and were decided NOT to include; each with one line: `F<n>` + "what" + "why it makes sense as its own ticket". Each row is also a `meta.json.followups[]` entry (`kind: "out-of-scope"`, `source: "build"`) — flow-core §7, and only for what clears its bar: an unpretty-but-correct shape, a coupling with no symptom or a state that is not trimmed belongs in this section and nowhere else. Nothing is asked here; `ship` puts the survivors of one skeptic round to the user, once, at the end.>
```

## 4. Quality during implementation

As larger pieces are completed:

- Run `quality.style_fix` from `FLOW.md` to fix style; if empty, auto-discover (Makefile, npm scripts, Gradle, dotnet, Xcode, Flutter…).
- Run `quality.static_analysis` from `FLOW.md` when a piece is stable; if empty, auto-discover.
- If tests were added, run them individually with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover. **A filtered run is judged by how many tests it executed, never by its exit code** — most runners exit `0` when the filter matches nothing (`OK, 0 tests`, `No tests ran`, `no tests to run`, `0 passed`). Read the executed count **and** test names: count `0`, or your new tests missing from the names → **the run did not happen**; treat as failure, fix the filter, run again. No count reported → drop the filter and run the whole test file. In "Relevant commands executed", record the count you saw, not just the command — "green" without a number is not evidence.

Do not do code review here — that is `/flow:feat:review`.

## 4.1 Is the design still valid?

Review the "Deviations from design" section of `05-implementation.md`. If **any** of the following applies:

- **2+ significant deviations** (module change, different event contract, different entity, unforeseen new repository).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.
- **A design piece appears that the prior inventory did not detect** and that changes the plan.
- **A primitive materialized with a different name/role than the design named it** (design said *Query*, code built a *Command*; design said *service*, code built a *handler* wired through a bus) — **vocabulary drift**: fix the design's naming (update `03-design.md`) or fix the code, now. `/flow:feat:review §5.5` and the reader judge the code, not the design's intent.

**Pause the build and return to `/flow:feat:design`** to update the document (and to `/flow:feat:plan` if it affects splitting). Do not keep implementing against a design that is no longer true — `/flow:feat:review` and `/flow:feat:validate` read `03-design.md` as truth.

Minor deviations (renames, local adjustments): note them and continue.

## 4.2 Textual contract check (before closing)

If §2.0bis copied contracts into `05-implementation.md`, **before marking the build as done** compare the code against each cited contract. **This is not a test to run** — it is a deliberate textual comparison you make as the agent, not delegated to the test runner.

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
- Multi-MR/PR build: leave the current MR/PR `in_progress` in `meta.json.mrs` (it becomes `merged` when `/flow:feat:ship` confirms the merge). **Also add `build` to that MR/PR's own `phases_done`** (its `mrs[]` entry) — the per-MR/PR marker the downstream gates read.
- Overwrite `00-summary.md` whole (≤15 lines, flow-core §5).
- Report **following the stop header** (flow-core §3) **only when this is a stop** — `manual`, or a blocker in any mode. Then in bullets: files touched (high level), pending items, **result of §4.2 (contracts verified)**, and **any premise left unsettled by §2.1bis** — one line, in the language of what breaks if it is false. An open premise the user never hears about is an assumption they were not asked about. In `guided`/`auto` `/flow:feat:review` runs in this same turn, so there is no report here: those same points go to the phase artifact, the panel carries `Now`/`Next`, and the turn opens with the call that chains.
- **Autonomy handoff.** The summary is a report, not the end of the flow. `manual`: stop and propose `/flow:feat:review` with a single `AskUserQuestion` (recommended option by default); invoke it only on confirmation, never make the user type it. `guided`/`auto`: **chain into `/flow:feat:review` automatically** in this same turn, without asking — never end the turn with the next command as a suggestion.
