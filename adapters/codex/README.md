# `flow` workflow adapter for Codex CLI

Brings the `/flow-feat-*`, `/flow-bug-*`, and `/flow-work-*` workflows from the `flow` plugin to the **Codex CLI** (OpenAI) format.

## Adapter contents

```
adapters/codex/
├── prompts/              — 25 custom prompts (one per workflow command)
│   ├── flow-feat-start.md
│   ├── flow-feat-brainstorm.md
│   ├── flow-feat-design.md
│   ├── flow-feat-plan.md
│   ├── flow-feat-build.md
│   ├── flow-feat-review.md
│   ├── flow-feat-validate.md
│   ├── flow-feat-ship.md
│   ├── flow-bug-start.md
│   ├── flow-bug-diagnose.md
│   ├── flow-bug-investigate.md
│   ├── flow-bug-fix.md
│   ├── flow-bug-validate.md
│   ├── flow-bug-review.md
│   ├── flow-bug-postmortem.md
│   ├── flow-bug-ship.md
│   ├── flow-work-README.md
│   ├── flow-work-daily.md
│   ├── flow-work-resume.md
│   ├── flow-work-status.md
│   ├── flow-work-try.md
│   ├── flow-work-abandon.md
│   ├── flow-work-respond.md
│   ├── flow-work-watch.md
│   ├── flow-init.md
│   ├── flow-config.md
│   └── flow-save-knowledge.md
├── config.snippet.toml   — sections to merge into ~/.codex/config.toml
├── AGENTS.md             — repo guide that Codex reads as context
├── PRIMITIVES.md         — primitive translation table + trimmed features
└── README.md             — this file
```

## Installation

### 1. Custom prompts

> **Note on prompts path**: the exact path where Codex CLI looks for custom prompts **may vary by Codex version**. The common path in recent versions is `~/.codex/prompts/`, but confirm it with `/help` inside Codex or by checking your version's documentation before copying.
>
> **Skills alternative**: if your version of Codex supports skills in `.agents/skills/` in the repo (format `$name`), copy the files from `prompts/` to `.agents/skills/<name>/SKILL.md` inside the repository. The workflows will work the same way, invoked as `$flow-feat-start`, `$flow-bug-fix`, etc.

Copy the files from `prompts/` to the Codex prompts path:

```bash
# Common path (confirm with /help or your version's docs):
cp prompts/*.md ~/.codex/prompts/

# If the path is different, replace it:
cp prompts/*.md /path/indicated-by-your-version/of/codex/prompts/
```

Prompts are invoked with `/flow-feat-start {TICKET}`, `/flow-bug-diagnose`, `/flow-work-status`, etc.

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

See `PRIMITIVES.md` for the full table. The most important points:

- **AskUserQuestion**: no structured UI → questions become plain text.
- **ScheduleWakeup** (watch autopilot): does not exist in Codex → `/flow-work-watch` runs one cycle and exits; use OS cron or Codex app Automations to repeat it.
- **Workflow DSL**: parallel orchestration is expressed as natural-language instructions to the agent.
