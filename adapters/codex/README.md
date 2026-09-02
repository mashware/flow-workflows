# `flow` workflow adapter for Codex CLI

Brings the `/flow-feat-*`, `/flow-bug-*`, and `/flow-work-*` workflows from the `flow` plugin to the **Codex CLI** (OpenAI) format.

## Adapter contents

```
adapters/codex/
├── prompts/              — one custom prompt per plugin command, generated (see ../README.md)
├── CORE.md               — the shared flow-core rules every prompt reads once per session (generated)
├── config.snippet.toml   — sections to merge into ~/.codex/config.toml
├── AGENTS.md             — repo guide that Codex reads as context
├── PRIMITIVES.md         — primitive translation table, the long form of each prompt's legend
└── README.md             — this file
```

`prompts/*.md` and `CORE.md` are written by `script/adapter-build.py` from the plugin — do not edit them by hand. Prompt names follow the plugin's paths with `:` flattened to `-` (`feat/start.md` → `/flow-feat-start`); `ls prompts/` is the current list.

## Installation

The shared script does steps 1 and the `~/.claude/flow/` copies (`CORE.codex.md`, the changelog, the manifest) in one go: `../install.sh codex`. By hand:

### 1. Custom prompts

> **Note on prompts path**: the exact path where Codex CLI looks for custom prompts **may vary by Codex version**. The common path in recent versions is `~/.codex/prompts/`, but confirm it with `/help` inside Codex or by checking your version's documentation before copying.
>
> **Skills alternative**: if your version of Codex supports skills in `.agents/skills/` in the repo (format `$name`), copy the files from `prompts/` to `.agents/skills/<name>/SKILL.md` inside the repository. The workflows will work the same way, invoked as `$flow-feat-start`, `$flow-bug-fix`, etc.

```bash
# Common path (confirm with /help or your version's docs):
cp prompts/*.md ~/.codex/prompts/
mkdir -p ~/.claude/flow && cp CORE.md ~/.claude/flow/CORE.codex.md

# If the path is different, replace it:
cp prompts/*.md /path/indicated-by-your-version/of/codex/prompts/
```

Prompts are invoked with `/flow-feat-start {TICKET}`, `/flow-bug-diagnose`, `/flow-work-status`, etc.

### 2. MCP and subagent configuration

Merge the contents of `config.snippet.toml` into your existing `~/.codex/config.toml`:

```bash
cat config.snippet.toml   # copy the sections you need into your config.toml
```

Adjust the `command` and `args` values in `[mcp_servers.domain-memory]` to match the actual domain-memory installation on your machine.

For subagents, define the `[agents.<name>]` sections you need in `~/.codex/config.toml`, using the names you set in the `agents.*` map in `FLOW.md`.

### 3. FLOW.md in the repo

Every repo using these workflows needs a `FLOW.md` at its root. Without it, workflows run with default values (auto-discovery), but having it is recommended for project-specific conventions.

```bash
cp ../../plugins/flow/examples/FLOW.template.md FLOW.md
# Edit FLOW.md with your project's conventions
```

### 4. AGENTS.md in the repo (optional)

Copy or symlink `AGENTS.md` to the repo root so Codex reads it as a context guide:

```bash
cp /path/to/adapters/codex/AGENTS.md /root/of/your/repo/AGENTS.md
```

## Quick start

```
# Start a feature
/flow-feat-start PROJ-12345

# Resume where you left off
/flow-work-resume

# Morning standup across all your work (local + forge + tracker)
/flow-work-daily

# See all open work
/flow-work-status

# Start a bug
/flow-bug-start PROJ-99999

# Watch after a deployment (one cycle; set up cron to repeat)
/flow-work-watch PROJ-12345 30m
```

## Dependencies

- **Codex CLI** installed and configured with your OpenAI API key.
- **domain-memory MCP** installed if you want `domain_memory.enabled: true` in FLOW.md. Project: https://github.com/mashware/domain-memory
- **git CLI** configured (`glab`, `gh`, or other per `git.cli` in FLOW.md) to create MRs/PRs from the terminal.

## Differences from the original plugin (Claude Code)

Each prompt opens with a legend mapping the Claude Code primitives to Codex; `PRIMITIVES.md` has the full table. The most important points:

- **AskUserQuestion**: no structured UI → questions become plain text.
- **ScheduleWakeup** (watch autopilot): does not exist in Codex → `/flow-work-watch` runs one cycle and exits; use OS cron or Codex app Automations to repeat it.
- **Parallel fan-out**: ports directly — the plugin describes it as parallel subagents, which Codex has. Leave `agents.fanout_tool` empty in `FLOW.md`; `agents.fanout_max` (empty → 4) caps each round.
