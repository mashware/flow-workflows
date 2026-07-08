# `/flow-feat-build`

Read `FLOW.md` at the repo root for this repo's conventions (tracker, git, quality, domain, observability). If it doesn't exist or a key is empty, use the default value or auto-discover as each step specifies. Regarding `domain_memory`: if it's active but the MCP fails or takes more than 2 s, continue without that context — do not block or notify the user. Also, if `FLOW.md` has a `notes` entry for this command (or an `all` entry), follow it as mandatory additional guidance for this step.

**Autonomy.** Read `autonomy.mode` from `FLOW.md` (`manual` | `guided` | `auto`; empty = `manual`) and apply it throughout this command. `manual` — stop at every decision point; at the end, propose the next command by asking the user to confirm it (write the question with the recommended next step as the default numbered option) and invoke it only when the user confirms — never advance without that confirmation, never make the user type it. `guided` — resolve low-risk, unambiguous decisions yourself using the recommended default and record the choice in the phase artifact instead of asking; still ask at genuine decision points; at the end, chain into the recommended next command automatically. `auto` — as `guided`, and also auto-resolve the remaining decision points with sensible (recorded) defaults, chaining phases without pausing. **Hard gates — ALWAYS stop and ask the user, in every mode, no exceptions:** (1) any push or MR/PR creation (all of `ship`); (2) creating or switching a branch when the base is ambiguous (not on a clean main, or a possible train/stacked branch); (3) DB schema changes or migrations; (4) a `review` that surfaced high-severity findings — never chain into `ship` on those. Rule of thumb for everything else: ask only when a decision is (a) irreversible or costly to undo, (b) ambiguous and not resolved by the ticket + domain-memory, or (c) a hard gate; otherwise take the sensible default and record it in the artifact.

Implementation phase. This is where code gets written.

## 1. Pre-flight

- Load `meta.json` by current branch.
- For `size` M/L: require that both `03-design.md` **and** `04-mr-plan.md` exist. If the plan is missing, send to `/flow-feat-plan`. If the design is missing, send to `/flow-feat-design`.
- For `size` XS/S: allow starting without a design but ask the user for a 2-3 line note on what they're going to do and save it as a minimal `03-design.md`. No MR/PR plan (always 1 MR/PR).
- Read all previous artifacts.
- **If `meta.json.mrs` has more than one entry**: identify the first MR/PR with `status: "pending"`. That's the MR/PR for this iteration. If all are `merged`, warn: feature is done, nothing left to build. Mark the selected one as `in_progress` in `meta.json.mrs`.

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

**Ask the user** whether the brief reflects what they expect:
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

**If in a multi-MR/PR build**: limit yourself to what the current MR/PR touches per `04-mr-plan.md`. Any code that belongs to a later MR/PR is scope expansion; cut it or isolate it behind a feature flag / temporary dead code per the plan.

Decide execution mode:

- **Single thread (XS/S/M)**: implement yourself, step by step, using subagents only as point consultants if blocked: the `agents.architecture` agent from `FLOW.md` for layer questions, and `agents.persistence` for query/mapping questions.
- **Partial delegation (M/L with clear pieces)**: use subagents for isolated endpoints, and the `agents.testing` agent from `FLOW.md` in parallel to prepare the suite. Pass the entire `03-design.md` in the prompt so they don't invent.

### 2.2 Commit confirmation (user opt-in)

**Hard rule**: the agent **does not `git commit` on its own** during `/flow-feat-build`. Commits are **user opt-in** — without explicit confirmation, changes stay in the working tree.

**After completing each step**, the agent:

1. Reports a step summary to the user (≤ 5 lines):
   ```
   Step N done: <description>
     Files: <short list>
     Diff: +<added> / -<removed> lines
     Suggested validation: <e.g. "run the unit test command for Foo">
   ```
2. **Does not commit**. Waits for you to decide:
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
- If you added tests, run them individually with `quality.test_one` from `FLOW.md` (substituting `{FILTER}`); if empty, auto-discover.

## 4.1 Is the design still valid?

Review the "Deviations from the design" section of `05-implementation.md`. If **any** of the following apply:

- **2+ significant deviations** (module change, different event contract, different entity, new unpredicted repository).
- **1 deviation that invalidates a decision** from the ADR-light in `03-design.md`.

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

- Update `meta.json`: `phase = "build"`, add to `phases_done`.
- Summarize for the user in bullets: touched files (high level), pending items, **§4.2 result (contracts verified)**, and next command: `/flow-feat-review`.
