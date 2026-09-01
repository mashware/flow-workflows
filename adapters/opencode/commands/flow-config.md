---
description: Show this repo's effective FLOW.md config — what is set, what is empty (and its fallback), and validate it
---

# flow-config

Read-only. Shows what the `/flow-feat-*`, `/flow-bug-*` and `/flow-work-*` commands will actually use in this repo, so
you don't have to open `FLOW.md` and cross-check it against the template by hand. **Writes nothing** — to
change the config use `/flow-init` or edit `FLOW.md`.

Canonical key list and their meaning: the plugin's `examples/FLOW.template.md`. Report against
that contract — don't invent keys, and do report keys that are documented there but absent from
the repo's `FLOW.md` (those are the "empty → fallback" rows).

## 1. Load

- Read `FLOW.md` at the repo root. If it doesn't exist, say so, explain that every command still
  works by auto-detecting/asking, and suggest `/flow-init` to generate one. Then, so the output is
  still useful, run §2 treating **every** key as empty (all fallbacks).
- Parse it by section: `tracker`, `git`, `quality`, `agents`, `models`, `data`, `conventions`, `notes`,
- **Resolved model map** (only if `models` has any key set): the keys are named by *kind of step*, and
  which step falls under which key lives inside the commands — so print the mapping resolved, one line
  per key: the key, its value, and the commands it covers (`study` → start · brainstorm · design · plan
  · diagnose · investigate · postmortem; `code` → build · fix · green; `test` → validate; `review` →
  review · query · respond triage; `workers` → the fan-out rounds, inheriting the running command's key
  when empty). Mark `study` and `code` with a warning: those steps are performed by the conductor
  itself, which cannot switch its own model, so there the value is **reported at the phase handoff, not
  enforced**. Say in one line that a subagent named in `agents.*` keeps its own definition's model, and
  that commands with no key (`ship`, `status`, `daily`, `resume`, `try`, `clean`, `abandon`, `watch`)
  always inherit. Never flag a model name as invalid or suggest a different one — the values are free
  text for the harness; only flag a key that is not one of the five.
  `domain_memory`, `observability`.

## 2. Effective config (per section)

For **every** documented key in `examples/FLOW.template.md`, print one row:

- **set** → show the value (for a list key like `git.worktree_resync` or `quality.reviewers`, show the items).
- **empty / absent** → show `(empty → <what happens>)`, taking the "what happens" from that key's
  comment in the template (e.g. `quality.test` empty → "auto-discover from Makefile/npm/composer";
  `tracker.tool` empty → "manual paste"; `agents.security` empty → "general-purpose subagent with the role";
  `git.worktree` empty → "off / in-place"; `git.worktree_resync` empty → "`/flow-work-try` only
  switches, no re-sync"). Never leave a reader guessing what an empty key does.

Group the output by section with a short header each, so it reads as a table/scan, not prose.
Keep set-vs-empty visually distinguishable (e.g. `✓` vs `·`).

## 3. Validate (flag, do not fix)

Light checks — report problems, never change anything:

- **CLIs**: for the tools referenced (`tracker.tool`, `git.cli`), check they are installed
  (`command -v gh glab acli tea az …`). Missing → warn that the corresponding step degrades
  (e.g. tracker read → manual paste; MR/PR creation → manual).
- **Subagents**: for each non-empty `agents.*` and `quality.reviewers` / `quality.review_skill`,
  check it is discoverable (project `agents/<name>.md` or `~/.config/opencode/agents/<name>.md`). Not
  found → warn it will fall back to a general-purpose subagent (or be skipped).
- **Commands**: for `quality.*` and `git.worktree_resync` entries that look like `make <target>`,
  optionally check the target exists in the `Makefile`; for npm/composer scripts, check they exist.
  Don't run them — only check presence. Unresolvable → flag as "declared but not found".
- **Environment is `/flow-doctor`'s job, not this command's**: whether the declared CLIs are *authenticated*, the named agents exist here, the hooks are executable, the MCP answers and the base branch resolves. Flag a key that contradicts another key; point at `/flow-doctor` for a key that describes a machine.
- **Coherence**: `git.worktree` is `ask`/`always` but `git.worktree_path` empty → note the default
  `.worktrees/{branch}` will be used. `git.host` and `git.cli` disagree → flag. `domain_memory.enabled`
  is `true` but the MCP is not available this session → note the domain steps will be skipped.
- **Tracker transitions**: if any of `tracker.start_cmd` / `done_cmd` / `abandon_cmd` is set but `tracker.tool`
  is `none`/empty → flag (there is no ticket to move). If `start_cmd` references `{ASSIGNEE}` but both
  `tracker.assignee` and `git.assignee` are empty → note the token won't substitute. If `git.host` is
  `github`/`gitlab` and `done_cmd` is set → note it is usually redundant with `Closes #N` auto-close (harmless,
  but the merge already closes the issue). These `*_cmd` run best-effort and never block.

- **Data access**: `data.explain_cmd`/`schema_cmd`/`sandbox_cmd`/`seed_cmd` are commands, not agents — check the binary or `make` target exists, never run them. An empty `data` section is not an error: note that the query duel runs on the schema alone and declares what it cannot prove. Flag an `explain_cmd`/`schema_cmd` with no `{QUERY}`/`{TABLE}` token (nothing would substitute), and flag **loudly** any of them pointing at what looks like production — these run against a development or throwaway database. If the section is empty while the repo clearly has a database, say what filling `volumes` alone would buy: a reviewer arguing about real row counts instead of invented ones.
## 4. Close

- Print a one-line summary: `N keys set, M using fallbacks, K warnings`.
- If there are warnings, suggest the concrete fix (install a CLI, create/rename a subagent, correct a
  key) and, when the fix is a config change, point at `/flow-init` or the specific `FLOW.md` key.
- Don't proceed to any other command on your own.
