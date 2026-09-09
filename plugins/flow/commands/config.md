---
description: Show this repo's effective FLOW.md config — what is set, what is empty (and its fallback), and validate it
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(ls:*), Bash(cat:*)
---

# `/flow:config`

Read-only. Shows what the `/flow:*` commands will actually use in this repo. **Writes nothing** —
to change the config use `/flow:init` or edit `FLOW.md`.

Canonical key list and meaning: `examples/FLOW.template.md` from the plugin. Report against that
contract — do not invent keys, and do report keys documented there but absent from the repo's
`FLOW.md` (the "empty → fallback" rows).

## 1. Load

- Read `FLOW.md` at the repo root. Missing → say so, note that every command still works by
  auto-detecting/asking, suggest `/flow:init`, then run §2 treating **every** key as empty (all fallbacks).
- Parse by section: `tracker`, `git`, `autonomy`, `quality`, `agents`, `models`, `data`, `conventions`,
  `notes`, `knowledge`, `observability`.

## 2. Effective config (per section)

For **every** documented key in `examples/FLOW.template.md`, one row:

- **set** → the value (list keys like `git.worktree_resync` or `quality.reviewers`: the items).
- **empty / absent** → `(empty → <what happens>)`, taken from the key's comment in the template
  (e.g. `quality.test` → "auto-discover from Makefile/npm/composer/Gradle/dotnet/Xcode/Flutter"; `tracker.tool` → "manual paste";
  `agents.security` → "general-purpose with the role"; `git.worktree` → "off / in-place";
  `git.worktree_resync` → "`/flow:work:try` only switches, no re-sync"; `quality.review_depth` →
  "proportional" — the other depths are `light` and `full`). Never leave a reader guessing what an empty key does.

For `knowledge`, print the four roles resolved with who decided each: the `knowledge` key, or empty with its fallback (`search` → no lookups; `stage` → artifact only; `read_staging` → artifacts; `save` → `KNOWLEDGE.md`). A `domain_memory` section still in the file → one line: *"`domain_memory` is no longer read; name the tools you want under `knowledge`"* — it is retired configuration, not an error.

Group by section with a short header each, so it scans as a table; keep set-vs-empty visually
distinct (e.g. `✓` vs `·`).

### 2.1 Resolved models (only if the `models` section exists and has any key set)

Two keys, both about subagents. Print what each one actually reaches:

```
agents   fable    →  improvised subagents: review panel members with no named agent, blinded
                     auditors, delegated build pieces, the general-purpose challenger
workers  (empty)  →  fan-out rounds — falls back to `agents`
```

- State once, plainly: **the main agent's own steps are not covered by either key** — reading the
  ticket, the design, and the single-thread `build`/`fix` run on the model the command was launched
  with, because an agent cannot switch its own model. A phase that wants another one says so at the
  handoff; nothing enforces it.
- One line: a role set in `agents.*` keeps its own agent definition's model, so a round can mix
  configured and self-declared models.

### 2.2 Defaults that keep being used

`FLOW.md` is written small on purpose and grows by use (flow-core §0): a phase that resolves an
empty key in `guided`/`auto` records it rather than asking. This block is where that record is read
back.

Aggregate `defaults_used[]` from every `.claude/work/*/meta.json`, **`_archive/` included**. One row
per key: the key, the default that was used, in how many works, and the last phase that used it.
Sort by count, most-used first, and cap the block at the ten busiest keys with a count of the rest.

```
agents.security      general-purpose   4 works   last: review
quality.review_depth proportional      4 works   last: review
data.volumes         (none — duel ran schema-only)  2 works   last: query
```

- **Print the line to paste**, per row, so pinning one is a copy: `- security: <agent name>` under
  `## agents`. `/flow:config` writes nothing — that has not changed.
- No `defaults_used[]` anywhere (a fresh repo, or every work ran in `manual`) → skip the block
  entirely, no empty table.
- One line under it: a default used in four works out of four is a decision that has already been
  taken four times; a default used once is not yet worth a key.

## 3. Validate (flag, do not fix)

Report problems, change nothing. **Scope: this file.** Whether the world it describes exists —
CLIs installed *and authenticated*, agents discoverable, hooks executable, the MCP reachable, the
base branch resolvable — is `/flow:doctor`. Point there in one line whenever a key below names a
tool, an agent or a command; do not duplicate those checks.

- **Fan-out and cost ceilings**: `agents.fanout_max` must be a positive integer; else flag and note
  the default `4` applies. `agents.budget_max` must be a non-negative integer (`0` = no ceiling);
  else flag and note the default `12`. **Both absent → say so as a finding, not a pass**: the review
  chain is the plugin's most expensive command and these are its only brake, so report the effective
  numbers and where to lower them. `budget_max` under the count of reviewers `quality.review_skill`
  or `quality.reviewers` defines → flag: the panel alone will exhaust the command's budget and every
  later phase gets skipped for cost. `agents.fanout_tool` names a harness tool, not an agent: set
  but not exposed by this harness → note the fan-out falls back to plain parallel subagents (not an
  error).
- **Models**: `models.*` values are **free text for the harness** — never flag a model name as
  invalid, never suggest a "better" one, never invent a default. Report only: a key outside
  `agents` / `workers` (flag — a typo, it will be ignored; the retired `study` / `code` / `test` /
  `review` keys get one line saying they are no longer read and that `agents` covers the subagents
  they used to name), and whether this harness can set a model per subagent (if not, every value
  degrades to inheritance).
- **Coherence**: `git.worktree` is `ask`/`always` with `git.worktree_path` empty → note the default
  `.worktrees/{branch}` applies. `git.host` and `git.cli` disagree → flag. Whether the declared
  commands, agents and MCP exist here is `/flow:doctor`.
- **Tracker transitions**: any of `tracker.start_cmd` / `done_cmd` / `abandon_cmd` set while
  `tracker.tool` is `none`/empty → flag (no ticket to move). `start_cmd` references `{ASSIGNEE}` with
  both `tracker.assignee` and `git.assignee` empty → note the token won't substitute. `git.host` is
  `github`/`gitlab` and `done_cmd` is set → note it is usually redundant with `Closes #N` auto-close
  (harmless). These `*_cmd` run best-effort and never block.
- **Data access**: `data.explain_cmd` / `schema_cmd` / `sandbox_cmd` / `seed_cmd` are commands, not
  agents — never run them; "does the binary exist" is `/flow:doctor`. Whole `data` section empty →
  not an error: note the query duel in `/flow:work:query` and `/flow:feat:review §3.6` runs on the
  schema alone and declares what it cannot prove; if the repo clearly talks to a database (a
  migrations directory, an ORM config), say what filling `volumes` alone buys — a reviewer arguing
  about real row counts. `explain_cmd`/`schema_cmd` without a `{QUERY}` / `{TABLE}` token → flag
  (nothing substituted). Anything that looks like the **production** database → flag loudly: these
  run against a development or throwaway database, never a live one.
- **Autonomy**: `autonomy.mode` empty → note it defaults to `manual` (every phase stops and, at the
  end, proposes the next command as a one-click confirmation — never runs it unconfirmed). Set →
  echo the mode and remind that the hard gates stop and ask in every mode and that `guided`/`auto`
  never ask about the flow's own mechanics or anything already decided (both lists: `flow:flow-core`
  skill §2). Unrecognized value → flag, `manual` assumed.

## 4. Close

- One-line summary: `N keys set, M using fallbacks, K warnings`.
- Anything flagged that depends on the environment rather than the file → one line:
  `/flow:doctor` checks the tools, agents, hooks and repo state this config assumes.
- Warnings → suggest the concrete fix (install a CLI, create/rename an agent, correct a key);
  when the fix is a config change, point at `/flow:init` or the specific `FLOW.md` key.
- Do not proceed to any other command on your own.
