---
description: Check that the environment the flow assumes actually exists here — CLIs, auth, agents, hooks, MCP, repo state
---

# `/flow:doctor`

Read-only. Answers one question: **will the flow actually work in this repo, right now?**
**Writes nothing, runs nothing that has side effects, and never fixes anything** — it reports, with
the one-line fix next to each problem.

`/flow:config` reads the *configuration*: which `FLOW.md` keys are set, what the empty ones fall
back to, and whether the file contradicts itself. This command checks the *world that configuration
assumes* — the binaries, the credentials, the agents, the hooks, the branch. The split matters
because a `FLOW.md` can be perfectly valid and still describe a machine you are not on: an agent you
renamed, a `gh` that expired its token, a hook that lost its executable bit. Every failure below is
one that currently surfaces mid-phase, as a confusing error, at the worst possible moment — the git
host CLI discovered at `ship` **after** the work is done, a missing reviewer discovered never,
because review just runs with fewer of them and reports success.

Run it when you land in an unfamiliar repo, after changing machines, after `/flow:init`, or when a
command failed in a way that smelled like the environment rather than the code.

## 1. Load

- Read `FLOW.md` at the repo root. Absent is **not** an error here: every command still works by
  auto-detecting and asking. Say so in one line, check what can be checked without it (git, hooks,
  harness, base branch), and note that `/flow:init` would let this command check the rest.
- Do not re-print the effective config — that is `/flow:config`. This command names a key only when
  something about it is broken.

## 2. Checks

Each check reports exactly one of **ok** (silent, see §3) · **missing** (the flow will degrade or
refuse) · **degraded** (it will run, quietly worse than the config promises), plus the fix.

### 2.1 Tools

- **Git host CLI** (`git.cli`, or auto-detected from `git.host`): installed (`command -v gh glab tea az`)
  **and authenticated** — `gh auth status`, `glab auth status`. Installed-but-unauthenticated is the
  case that matters and the one nothing checks today: it passes every presence test and then fails at
  `ship`, with the work finished and the push refused. Read-only, no network writes.
- **Tracker CLI** (`tracker.tool`): installed, and authenticated where the tool can say so cheaply.
  Missing → ticket reads become manual paste; `start`/`done`/`abandon` transitions silently do nothing.
- **Quality commands** (`quality.test`, `test_one`, `static_analysis`, `style_fix`, `db_update`,
  `db_diff`, `frontend_test`) and `git.worktree_resync` entries: for `make <target>`, the target
  exists in the `Makefile`; for npm/composer scripts, the script exists; otherwise the binary is on
  `PATH`. **Never run them** — presence only. Declared-but-absent is worth flagging loudly: `validate`
  gates on a command that cannot run.
- **Data-access commands** (`data.explain_cmd`, `schema_cmd`, `sandbox_cmd`, `seed_cmd`): the binary or
  `make` target exists. Never run them, and never touch a database. Absent section → not a failure:
  note that `/flow:work:query` argues from the schema alone and says what it cannot prove.

### 2.2 Agents

- Every **role** set in `agents.*` (not `fanout_max` / `fanout_tool` — those are not agents), plus
  `quality.reviewers` and `quality.review_skill`: discoverable in `~/.claude/agents`, the repo's
  `.agents/agents`, or a plugin. This is the check whose absence costs the most and shows the least:
  a review panel missing two of its five agents does not fail, it just reviews less and still reports
  a clean pass. Report each missing name and that it falls back to `general-purpose` (or, for a
  skill, is skipped).
- Note when the harness cannot set a model per subagent, since then every `models.*` value degrades
  to inheritance regardless of what the file says.

### 2.3 MCP

- `domain_memory.enabled` is `true` → the MCP is actually reachable **this session**. Unreachable →
  `/flow:save-knowledge` and the domain steps of `start`/`design`/`postmortem` are skipped, quietly,
  which is how a repo ends up with months of decisions recorded nowhere.
- Declared `false`/empty while the MCP *is* available → say so once. Nothing is broken; you are
  leaving the memory unused.

### 2.4 Hooks

- The plugin's hooks are installed, **executable**, and the version this plugin expects: the
  push guard (`hooks/block-push-to-master.sh`) and the session-start update notice. A hook that lost
  its `+x` bit is the bad case — it fails open and silently, so the only symptom is a push to `main`
  that nobody stopped. Check the bit, not just the path.
- `hooks.json` parses. Nothing but the loader reads it, so a syntax error there disables the hooks
  without a word.

### 2.5 Repo state

- The base branch (`git.default_base`, empty → detected) **exists and is reachable** from here
  (`git rev-parse --verify`, `git ls-remote --exit-code`). A base that does not resolve makes `start`
  create a branch off the wrong thing and `ship` diff against nothing.
- Worktree coherence: `git.worktree` is `ask`/`always` → `git.worktree_path` resolves and its parent
  is writable; existing worktrees in `git worktree list` are not stale (a worktree whose directory is
  gone). Flag, never prune — pruning is `/flow:work:clean`.
- The repo has a remote, and the current branch's upstream is not another branch's (the shape that
  makes a blind push land somewhere surprising).
- `.claude/work/` exists or can be created, and no `meta.json` in it fails to parse. An unparseable
  `meta.json` is a work the flow will refuse to resume — better to hear it now than at `resume`.

### 2.6 Harness

- The tool named in `agents.fanout_tool` is exposed by this harness. Absent → the fan-out falls back
  to plain parallel subagents, which is the portable path and not an error.
- `agents.fanout_max` is a positive integer (else the default `4` applies).

## 3. Output

**Quiet on success.** A wall of green ticks is noise that trains you to stop reading it, so print
one line per check that is *not* ok, grouped by the six areas above, plus a single summary line:

```
flow doctor — 3 findings

  Tools     ✗ glab installed but not authenticated     → glab auth login
  Agents    ✗ quality.reviewers: security-auditor not found  → review runs with 4 of 5, silently
  Hooks     · block-push-to-master.sh is not executable  → chmod +x (fails open: pushes to main are NOT blocked)

  ok: tracker CLI · quality commands · domain-memory MCP · base branch · worktrees · harness
```

- Everything ok → say it in one line and name what was checked, so the reader knows the silence was
  earned rather than skipped.
- Order findings by **what they cost**, not by area: something that fails open and silently (a dead
  hook, a missing reviewer) outranks something that will fail loudly the moment you hit it (a missing
  CLI), because the loud one cannot ship a mistake.
- Every finding carries its fix on the same line. A finding whose fix is a config change points at
  the `FLOW.md` key or `/flow:init`; one whose fix is the machine gives the command to run.
- Never fix anything, never install anything, never write to `FLOW.md`, and do not chain into another
  command — including in `guided`/`auto`. This command exists to be trusted as read-only.
