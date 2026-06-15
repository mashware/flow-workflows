---
description: Implement the feature following the approved design and keep a running log
---

# `/feat-build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step indicates. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — don't block or notify the user.

Implementation phase. This is where code gets written.

## 1. Pre-flight

- Load `meta.json` for the current branch.
- For `size` M/L: require that both `03-design.md` **and** `04-mr-plan.md` exist. If the plan is missing, send to `/feat-plan`. If the design is missing, send to `/feat-design`.
- For `size` XS/S: allow starting without a design but ask the user for a 2-3 line note on what they're about to do and save it as a minimal `03-design.md`. No MR/PR plan (always 1 MR/PR).
- Read all previous artifacts.
- **If `meta.json.mrs` has more than one entry**: identify the first MR/PR with `status: "pending"`. That is the MR/PR for this iteration. If all are `merged`, warn: feature complete, nothing left to build. Mark the selected one as `in_progress` in `meta.json.mrs`.

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

**Ask the user** whether the brief reflects what they expect:
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

Load the project conventions (see `FLOW.md` section `conventions`).

**If you're in a multi-MR/PR build**: limit yourself to what the current MR/PR covers according to `04-mr-plan.md`. Any code belonging to a later MR/PR is expanded scope; trim it or isolate it behind a feature flag / temporary dead code as per the plan. If it can't be isolated, pause and go back to `/feat-plan` to trim.

Decide execution mode:

- **Single thread (XS/S/M)**: implement yourself, step by step, using sub-agents only as point consultants when blocked: the architecture sub-agent from `FLOW.md` for layer questions (or a general-purpose sub-agent if empty), and the persistence one for query/mapping questions (or a general-purpose sub-agent if empty).
- **Partial delegation (M/L with clear pieces)**: use `@name` sub-agents for isolated endpoints, and the testing sub-agent from `FLOW.md` in parallel to prepare the test suite (or a general-purpose sub-agent if empty). Pass the full `03-design.md` in the prompt so they don't invent things.

### 2.2 Checkpoints (local commits on user confirmation)

**Hard rule**: the agent **does not run `git commit` on its own** during `/feat-build`. Commits are **opt-in from the user** — without your explicit confirmation, changes stay in the working tree so you can validate them first (try the UI, run the flow, read the diff).

**After completing each step of the plan**, the agent:

1. Reports a step summary to the user (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<add> / -<del> lines
     Suggested validation: <e.g. "run the unit test for Foo" or "open the UI at /section">
   ```
2. **Does not commit**. Waits for the user to decide. Options:
   - **"Commit now"** or **"OK, continue"** → the agent runs `git add <files from step> && git commit -m "WIP <TICKET>: <step>" --no-verify` and continues with the next step.
   - **"Wait, I'll validate"** → the agent stops. The user validates at their own pace. When they return, they decide: commit or adjust.
   - **"Something needs changing"** → the agent adjusts. The step's commit stays pending until you give the OK.
   - **"Continue without committing, we'll group later"** → the agent starts the next step without committing. Changes accumulate in the working tree.

Rules for when a commit does happen:
- One commit per step. Don't group several steps into one commit unless the user explicitly asks.
- `--no-verify` is allowed **only on work-in-progress commits** (slow hooks will run at the end in `/feat-review` and in the final commit of `/feat-ship`).
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
2. **Keep going and record the overrun**. Useful if cutting would be artificial. The deviation is noted in `05-implementation.md` to calibrate `/feat-plan` on future tickets.
3. **Reopen plan**. Go back to `/feat-plan` to rethink the entire split. Only if the overrun indicates the plan is wrong at a deeper level, not just for this MR/PR.

**Hot cut mechanics (option 1)**:

0. **If there are uncommitted changes** in the working tree: warn the user and ask them to decide before cutting.
1. Identify a cut point: the last work-in-progress commit where the piece is coherent and mergeable.
2. Edit `meta.json.mrs`: the current MR/PR keeps its `n` and `title`, adjust `lines_est` and `files_est` to the real numbers, stays `in_progress`. Insert a new entry with the next `n`, `title` describing what remains, `status: "pending"`.
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
- If you added tests, run them with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover.

Don't do the code review here — that's `/feat-review`.

## 4.1 Is the design still valid?

Review the "Design deviations" section of `05-implementation.md`. If **any** of the following is true:

- **2+ significant deviations** (module change, different event contract, different entity, new repository not foreseen).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.
- **A design piece appears that the previous inventory didn't detect** and that changes the plan.

**Pause the build and go back to `/feat-design`** to update the document. Don't keep implementing against a design that's no longer true — `/feat-review` and `/feat-validate` read `03-design.md` as truth and will make wrong judgments if it lies.

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
- If it's a multi-MR/PR build, leave the current MR/PR as `in_progress` in `meta.json.mrs`; it will move to `merged` when `/feat-ship` confirms the merge.
- Summarize to the user in bullets: files touched (high level), pending items, **result of §4.2 (contracts verified)**, and next command: `/feat-review`.
