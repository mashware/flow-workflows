# adapters — `flow` workflows for other harnesses

The `flow` plugin (in `../plugins/flow`) is for **Claude Code**. These adapters bring the same
`feat`/`bug`/`work` workflows to other terminal agents. They are **build output, not source**:
[`../script/adapter-build.py`](../script/adapter-build.py) reads every plugin command and the shared
rules in `../plugins/flow/skills/flow-core/SKILL.md`, and writes every file under
`opencode/commands/`, `codex/prompts/`, `gemini/commands/flow/` plus one `<harness>/CORE.md` each.
The **logic and prose are the plugin's, verbatim** — only the wrapper changes.

| Harness | Commands | Subagents | MCP | Autopilot watch |
|---|---|---|---|---|
| **opencode** | `commands/*.md` (`/flow-feat-start`) | `agents/*.md` `mode:subagent`, `@name` | `opencode.json` | cron + `opencode run -p` |
| **Gemini CLI** | `commands/**/*.toml` (`/flow:feat:start`) | `.gemini/agents/*.md`, `@name` | `settings.json` `mcpServers` | cron + `gemini -p` |
| **Codex CLI** | `prompts/*.md` (`/flow-feat-start`) | `[agents.*]` in `config.toml` | `[mcp_servers.*]` | cron + `codex exec` |

## What the generator changes per harness

Only the mechanics, and only these:

- **The wrapper** — opencode a `description:` frontmatter, Codex none, Gemini a TOML `description`
  + `prompt` string (backslashes and triple quotes escaped).
- **The prefix** — every `/flow…` invocation rewritten to the harness's own: `/flow-feat-build` for
  opencode and Codex, `/flow:feat:build` for Gemini.
- **`$ARGUMENTS`** → `{{args}}` for Gemini.
- **The CORE pointer** — the plugin's `flow:flow-core` skill and `${CLAUDE_PLUGIN_ROOT}` become
  `~/.claude/flow/CORE.<tool>.md`, the file `install.sh` places there.
- **A legend** right after the title, mapping the Claude Code primitives the prose names
  (`AskUserQuestion`, subagents and fan-out, `ScheduleWakeup`, `TaskCreate`, `Skill …`, `/model`,
  `knowledge.*` roles) to what that harness has. The legend is the `LEGEND` dict in the script;
  each adapter's `PRIMITIVES.md` is its long form.

Every generated file opens with a banner saying so. Editing one by hand is wasted work — the next
build undoes it.

## Adding or changing a command

1. Edit the command in `../plugins/flow/commands/` (or the shared rules in
   `../plugins/flow/skills/flow-core/SKILL.md`).
2. From the repo root: `python3 script/adapter-build.py` — rewrites every mirror, deletes orphans.
3. Commit the plugin file **and** the regenerated mirrors together.

The preflight (`script/check.py`) runs `adapter-build.py --check` and fails on any mirror that is
missing, stale or orphaned; CI runs the same on every push.

## Install

```bash
./install.sh opencode      # or: gemini | codex
./install.sh opencode project   # project-scoped variant (where applicable)
```

The script sweeps its own previous `flow-*` files and copies the **commands** where the harness
reads them, then puts under `~/.claude/flow/` what the plugin would read from
`${CLAUDE_PLUGIN_ROOT}`: **`CORE.<tool>.md`** (the shared rules every command reads once per
session), the **`CHANGELOG.md`** `/flow-news` · `/flow:news` shows, and the **`plugin.json`** it
takes the installed version from. It tells you which **config fragment** (MCP/subagents) to merge
by hand into your `opencode.json` / `settings.json` / `config.toml` — it never touches your configs.

After that: place a **`FLOW.md`** at the root of your repo (template at
`../plugins/flow/examples/FLOW.template.md`). It configures the tracker, git, test commands,
observability, and the subagent map for YOUR project.

## What ports and what doesn't (honest)

- **Ports unchanged**: phases (start→ship, diagnose→postmortem), rules, gates, `FLOW.md`, MCP
  (`knowledge.*` roles, e.g. `domain-memory`), Pre-deploy + blocking thread, and **subagents** (review/investigate) —
  all three harnesses support them; only the declaration format changes.
- **Translated by the legend** (long form in each adapter's `PRIMITIVES.md`):
  - **`AskUserQuestion`**: none of them have a structured menu UI → a plain-text question with
    numbered options.
  - **`models` per subagent**: all three declare a subagent's model in the subagent's own definition,
    not at the call site → a `models` key is honoured by invoking a subagent declared with that model.
    No harness lets a session switch its own model, so for the steps the conductor performs itself
    the configured value is reported at the phase handoff and the flow continues — same as on Claude Code.
  - **Autopilot for `/flow:work:watch`**: no in-session re-wakeup → **OS cron + headless execution**.
    One cycle per run; state lives in `monitor.md`, which each cycle re-reads. It works, but the
    trigger is external, not the session itself.

## What is checked, and what is still on you

Every preflight runs [`../script/adapter-smoke.py`](../script/adapter-smoke.py) over the generated files:

- each mirror **parses in the shape its harness reads** — opencode a `description:` frontmatter,
  Codex no frontmatter at all, Gemini a TOML `description` + `prompt`
- every `/flow…` invocation in the body uses **this harness's prefix** — the one mistake that hands
  you a command your harness does not have
- every command and repo path it cites **exists**
- `install.sh` is executed against a **throwaway `HOME`** and the files are checked to land where that
  harness looks for them, in the expected number, changelog included

⚠️ **What none of that proves**: that the harness *runs* a workflow the way Claude Code does. These
have never been executed inside opencode, Gemini CLI or Codex end to end. Validate as you use them,
and adjust paths if your version differs — especially Codex, where the prompts location changes
between versions (see `codex/README.md`).

> Single source of truth: `../plugins/flow/commands/` and `../plugins/flow/skills/flow-core/`.
> Change there, run `python3 script/adapter-build.py`, commit both.
