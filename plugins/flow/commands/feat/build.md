---
description: Implement the feature following the approved design and keep a running log
---

# `/flow:feat:build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it does not exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it is active but the MCP fails or takes longer than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command with a single `AskUserQuestion` (the recommended next step as the default option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

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

**Ask the user with `AskUserQuestion`** whether the brief reflects what they expect:
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

**If in a multi-MR/PR build**: limit yourself to what the current MR/PR covers per `04-mr-plan.md`. Any code belonging to a later MR/PR is scope creep; cut it or isolate it behind a feature flag / dead code temporarily per the plan. If it cannot be isolated, pause and return to `/flow:feat:plan` to cut it.

Choose execution mode:

- **Single-thread (XS/S/M)**: implement yourself, step by step, using subagents only as point consultants when blocked: the `agents.architecture` agent from `FLOW.md` for layer questions (or `Agent general-purpose` if empty), and the `agents.persistence` one for query/mapping questions (or `Agent general-purpose` if empty).
- **Partial delegation (M/L with clear pieces)**: use `Agent` for isolated endpoints, and the `agents.testing` agent from `FLOW.md` in parallel to prepare the test suite (or `Agent general-purpose` if empty). Pass the full `03-design.md` in the prompt so agents do not invent things.

Use `TaskCreate` to track the steps from the design's implementation plan. Mark each step `in_progress` when starting and `completed` when done — do not batch.

### 2.2 Checkpoints (local commits on user confirmation)

**Hard rule**: the agent **does not run `git commit` on its own** during `/flow:feat:build`. Commits are **opt-in from the user** — without your explicit confirmation, changes stay in the working tree so you can validate them first (test the UI, run the flow, read the diff).

**After completing each `TaskCreate` step**, the agent:

1. **Marks the step as `completed`** in `TaskCreate`.
2. **Reports to the user** a step summary (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<add> / -<del> lines
     Suggested validation: <e.g. "run the unit test command for Foo" or "open the UI at /section">
   ```
3. **Does not commit**. Waits for you to say what to do. Options:
   - **"Commit now"** or **"OK, continue"** → agent runs `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` and continues with the next step.
   - **"Wait, I'll validate"** → agent stays still. You validate at your own pace. When you return, decide commit or adjustment.
   - **"Something needs to change"** → agent adjusts. The step's commit stays pending until you give OK.
   - **"Continue without committing, we'll group later"** → agent starts the next step without committing. Changes accumulate in the working tree (risk: if a hot cut occurs per §2.3, there are fewer clean points).

Rules for when a commit does happen:
- One commit per step (when done). Do not batch multiple steps into one commit unless you explicitly request it.
- `--no-verify` is allowed **only for WIP commits** (slow hooks will run at the end in `/flow:feat:review` and in the final commit of `/flow:feat:ship`).
- These commits are squashed on merge (if `git.squash` is `true`), so they do not need to be pretty — they are just cuttable units.
- If a step is left halfway (interruption, change of focus) and you ask for a commit, the message has the suffix: `WIP <TICKET>: <step> (partial)`.

**Why this model**: two reasons. (1) You validate locally before anything is committed, so you do not end up with a branch full of commits without having seen the changes running. (2) If you decide to commit occasionally, the WIP commits still serve as cuttable units for §2.3. If you decide not to commit until the end, you lose that granularity — that is your decision, not the agent's.

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
- If tests were added, run them individually with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover.

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
- Summarize to the user in bullets: files touched (high level), pending items, **result of §4.2 (contracts verified)**, and next command: `/flow:feat:review`.
