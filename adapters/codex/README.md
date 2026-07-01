# `flow` workflow adapter for Codex CLI

Brings the `/feat-*`, `/bug-*`, and `/work-*` workflows from the `flow` plugin to the **Codex CLI** (OpenAI) format.

## Adapter contents

```
adapters/codex/
├── prompts/              — 24 custom prompts (one per workflow command)
│   ├── feat-start.md
│   ├── feat-brainstorm.md
│   ├── feat-design.md
│   ├── feat-plan.md
│   ├── feat-build.md
│   ├── feat-review.md
│   ├── feat-validate.md
│   ├── feat-ship.md
│   ├── bug-start.md
│   ├── bug-diagnose.md
│   ├── bug-investigate.md
│   ├── bug-fix.md
│   ├── bug-validate.md
│   ├── bug-review.md
│   ├── bug-postmortem.md
│   ├── bug-ship.md
│   ├── work-README.md
│   ├── work-resume.md
│   ├── work-status.md
│   ├── work-try.md
│   ├── work-abandon.md
│   ├── work-watch.md
│   ├── flow-init.md
│   ├── flow-config.md
│   └── save-knowledge.md
├── config.snippet.toml   — sections to merge into ~/.codex/config.toml
├── AGENTS.md             — repo guide that Codex reads as context
├── PRIMITIVES.md         — primitive translation table + trimmed features
└── README.md             — this file
```

## Installation

### 1. Custom prompts

> **Note on prompts path**: the exact path where Codex CLI looks for custom prompts **may vary by Codex version**. The common path in recent versions is `~/.codex/prompts/`, but confirm it with `/help` inside Codex or by checking your version's documentation before copying.
>
> **Skills alternative**: if your version of Codex supports skills in `.agents/skills/` in the repo (format `$name`), copy the files from `prompts/` to `.agents/skills/<name>/SKILL.md` inside the repository. The workflows will work the same way, invoked as `$feat-start`, `$bug-fix`, etc.

Copy the files from `prompts/` to the Codex prompts path:

```bash
# Common path (confirm with /help or your version's docs):
cp prompts/*.md ~/.codex/prompts/

# If the path is different, replace it:
cp prompts/*.md /path/indicated-by-your-version/of/codex/prompts/
```

Prompts are invoked with `/feat-start {TICKET}`, `/bug-diagnose`, `/work-status`, etc.

### 2. MCP and subagent configuration

Merge the contents of `config.snippet.toml` into your existing `~/.codex/config.toml`:

```bash
# Read config.snippet.toml and copy the sections you need manually into your config.toml
cat config.snippet.toml
```

Adjust the `command` and `args` values in `[mcp_servers.domain-memory]` to match the actual domain-memory installation on your machine.

For subagents, define the `[agents.<name>]` sections you need in `~/.codex/config.toml`, using the names you set in the `agents.*` map in `FLOW.md`.

### 3. FLOW.md in the repo

Every repo using these workflows needs a `FLOW.md` at its root. Without it, workflows run with default values (auto-discovery), but having it is recommended for project-specific conventions.

Start from the template:

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
/feat-start PROJ-12345

# Resume where you left off
/work-resume

# See all open work
/work-status

# Start a bug
/bug-start PROJ-99999

# Watch after a deployment (one cycle; set up cron to repeat)
/work-watch PROJ-12345 30m
```

## Dependencies

- **Codex CLI** installed and configured with your OpenAI API key.
- **domain-memory MCP** installed if you want `domain_memory.enabled: true` in FLOW.md. Project: https://github.com/mashware/domain-memory
- **git CLI** configured (`glab`, `gh`, or other per `git.cli` in FLOW.md) to create MRs/PRs from the terminal.

## Differences from the original plugin (Claude Code)

See `PRIMITIVES.md` for the full table. The most important points:

- **AskUserQuestion**: no structured UI → questions become plain text.
- **ScheduleWakeup** (watch autopilot): does not exist in Codex → `/work-watch` runs one cycle and exits; use OS cron or Codex app Automations to repeat it.
- **Workflow DSL**: parallel orchestration is expressed as natural-language instructions to the agent.
