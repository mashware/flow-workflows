---
description: Show this repo's effective FLOW.md config — what is set, what is empty (and its fallback), and validate it
---

# `/flow:config`

Read-only. Shows what the `/flow:*` commands will actually use in this repo, so you do not have to
open `FLOW.md` and cross-check it against the template by hand. **Writes nothing** — to change the
config use `/flow:init` or edit `FLOW.md`.

Canonical key list and their meaning: `examples/FLOW.template.md` from the plugin. Report against
that contract — do not invent keys, and do report keys that are documented there but absent from
the repo's `FLOW.md` (those are the "empty → fallback" rows).

## 1. Load

- Read `FLOW.md` at the repo root. If it does not exist, say so, explain that every command still
  works by auto-detecting/asking, and suggest `/flow:init` to generate one. Then, so the output is
  still useful, run §2 treating **every** key as empty (all fallbacks).
- Parse it by section: `tracker`, `git`, `autonomy`, `quality`, `agents`, `models`, `data`, `conventions`,
  `notes`, `domain_memory`, `observability`.

## 2. Effective config (per section)

For **every** documented key in `examples/FLOW.template.md`, print one row:

- **set** → show the value (for a list key like `git.worktree_resync` or `quality.reviewers`, show the items).
- **empty / absent** → show `(empty → <what happens>)`, taking the "what happens" from that key's
  comment in the template (e.g. `quality.test` empty → "auto-discover from Makefile/npm/composer";
  `tracker.tool` empty → "manual paste"; `agents.security` empty → "general-purpose with the role";
  `git.worktree` empty → "off / in-place"; `git.worktree_resync` empty → "`/flow:work:try` only
  switches, no re-sync"). Never leave a reader guessing what an empty key does.

Group the output by section with a short header each, so it reads as a table/scan, not prose.
Keep set-vs-empty visually distinguishable (e.g. `✓` vs `·`).

### 2.1 Resolved model map (only if the `models` section exists and has any key set)

`models` is the one section where reading the keys is not enough to know what happens: the keys are
named by *kind of step*, and which step falls under which key lives inside the commands. Print that
mapping resolved, so the user reads it instead of inferring it:

```
study    fable    →  feat:start · brainstorm · design · plan · bug:start · diagnose · investigate · postmortem
code     opus     →  feat:build · bug:fix · work:green  ⚠ main agent — reported at the handoff, not enforced
test     sonnet   →  feat:validate · bug:validate
review   sonnet   →  feat:review · bug:review · work:query · work:respond (triage)
workers  (empty)  →  fan-out rounds inherit the running command's key
```

Mark with `⚠` the keys whose steps the **main agent performs itself** (`study`, and `code` for the
single-thread `build`/`fix` on XS/S/M): there the value is reported at the phase handoff and the flow
continues, because an agent cannot switch its own model. State that once, plainly — a user who reads
`code: opus` and assumes it is enforced has been misled by their own config file.

Also state, in one line each: a role set in `agents.*` keeps its own agent definition's model (the
keys apply where flow improvises the agent and to fan-out workers), and commands with no key
(`ship`, `status`, `daily`, `resume`, `try`, `clean`, `abandon`, `watch`) always inherit.

## 3. Validate (flag, do not fix)

Light checks — report problems, never change anything. **Scope: this file.** Whether the world it
describes exists — CLIs installed *and authenticated*, agents discoverable, hooks executable, the
MCP reachable, the base branch resolvable — belongs to `/flow:doctor`, which checks it properly
instead of twice and half. Point the user there in one line whenever a key below names a tool, an
agent or a command; do not duplicate those checks here.

- **Fan-out**: `agents.fanout_max` must be a positive integer; anything else → flag and note the
  default `4` applies. `agents.fanout_tool` names a harness tool, not an agent: if it is set and
  this harness does not expose it, note the fan-out falls back to plain parallel subagents (not an
  error — that is the portable path).
- **Models**: `models.*` values are **free text for the harness** — never flag a model name as invalid, never suggest a "better" one, and never invent a default. Only report: a key that is not one of `study` / `code` / `test` / `review` / `workers` (flag it — it is a typo and will be ignored), and whether this harness can set a model per subagent at all (if it cannot, note that every value degrades to inheritance). If `models.code` is set, note in one line that `build`/`fix` are single-thread on XS/S/M, so there the value is reported at the handoff rather than applied.
- **Coherence**: `git.worktree` is `ask`/`always` but `git.worktree_path` empty → note the default
  `.worktrees/{branch}` will be used. `git.host` and `git.cli` disagree → flag. These are about the
  file contradicting itself; whether the declared commands, agents and MCP actually exist here is
  `/flow:doctor`.
- **Tracker transitions**: if any of `tracker.start_cmd` / `done_cmd` / `abandon_cmd` is set but `tracker.tool`
  is `none`/empty → flag (there is no ticket to move). If `start_cmd` references `{ASSIGNEE}` but both
  `tracker.assignee` and `git.assignee` are empty → note the token won't substitute. If `git.host` is
  `github`/`gitlab` and `done_cmd` is set → note it is usually redundant with `Closes #N` auto-close (harmless,
  but the merge already closes the issue). These `*_cmd` run best-effort and never block.
- **Data access**: `data.explain_cmd` / `schema_cmd` / `sandbox_cmd` / `seed_cmd` are commands, not
  agents — never run them, and leave "does the binary exist" to `/flow:doctor`. If the whole `data`
  section is empty, do not flag it as an error: note that the query duel in `/flow:work:query` and
  `/flow:feat:review §3.6` runs on the schema alone and declares what it cannot prove. If
  `explain_cmd` or `schema_cmd` is set but has no `{QUERY}` / `{TABLE}` token → flag (nothing would
  be substituted). If any of them points at what looks like the **production** database, flag it
  loudly: these run against a development or throwaway database, never a live one. And if the whole
  section is empty while the repo clearly talks to a database (a migrations directory, an ORM
  config), say what filling `volumes` alone would buy — a reviewer that argues about real row counts
  instead of invented ones.
- **Autonomy**: `autonomy.mode` empty → note it defaults to `manual` (every phase stops and, at the
  end, proposes the next command as a one-click confirmation — never runs it without confirming). If set, echo the mode and remind that the hard gates (push/MR-PR,
  ambiguous-base branch creation, DB/migrations, high-severity review findings, the business brief) still
  stop and ask in every mode, and that in `guided`/`auto` the flow never asks about its own mechanics
  (panels, reviewer count), WIP commits, continuing a train, size confirmation, or anything already
  decided. An unrecognized value → flag it and state that `manual` will be assumed.

## 4. Close

- Print a one-line summary: `N keys set, M using fallbacks, K warnings`.
- If anything you flagged depends on the environment rather than the file, close with one line:
  `/flow:doctor` checks the tools, agents, hooks and repo state this config assumes.
- If there are warnings, suggest the concrete fix (install a CLI, create/rename an agent, correct a
  key) and, when the fix is a config change, point at `/flow:init` or the specific `FLOW.md` key.
- Do not proceed to any other command on your own.
