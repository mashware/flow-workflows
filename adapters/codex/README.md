# `flow` workflow adapter for Codex CLI

Brings the `feat`, `bug` and `work` workflows from the `flow` plugin to the **Codex CLI** (OpenAI)
format: one **skill** per command, invoked as `$flow-feat-start`, `$flow-bug-fix`, `$flow-work-status`.

## Adapter contents

```
adapters/codex/
├── skills/               — one skill folder per plugin command, generated (see ../README.md)
├── CORE.md               — the shared flow-core rules every skill reads once per session (generated)
├── config.snippet.toml   — sections to merge into ~/.codex/config.toml
├── AGENTS.md             — repo guide that Codex reads as context
├── PRIMITIVES.md         — primitive translation table, the long form of each skill's legend
└── README.md             — this file
```

`skills/*/SKILL.md` and `CORE.md` are written by `script/adapter-build.py` from the plugin — do not edit them by hand. Skill names follow the plugin's paths with `:` flattened to `-` (`feat/start.md` → `$flow-feat-start`); `ls skills/` is the current list.

### Two ways in, and when to pick which

**As a Codex plugin** — nothing to clone, upgrades with one command:

```bash
codex plugin marketplace add https://github.com/mashware/flow-workflows.git
codex plugin add flow@flow-plugins
codex plugin marketplace upgrade      # later, to update
```

Codex namespaces a plugin's skills, so those are invoked `$flow:feat-start`, `$flow:bug-fix`,
`$flow:work-status`, and the shared rules are the sibling skill `$flow:flow-core`. They are
generated into `plugins/flow/codex-skills/` and declared by `plugins/flow/.codex-plugin/plugin.json`;
Claude Code never reads either. One cosmetic wart: Codex's own importer also adds
`$flow:source-command-next`, a duplicate of `$flow:next`, and there is no way to turn it off.

**As loose skills** — this adapter, `../install.sh codex`. Pick it to install into a single repo's
`.agents/skills/`, or to run a build you have not published. The names keep their `flow-` prefix
because `~/.codex/skills/` is one flat namespace, so they are invoked `$flow-feat-start`.

Either way it is skills, never the Claude commands: Codex does not read `commands/`. On install it
converts them into skills itself — and that converter silently drops any command whose rendered
skill exceeds ~4 KB or whose body uses `$ARGUMENTS`, which is every `flow` command but one.

## Installation

The shared script does step 1 and the `~/.claude/flow/` copies (`CORE.codex.md`, the changelog, the manifest) in one go: `../install.sh codex` (globally) or `../install.sh codex project` (into this repo's `.agents/skills/`). By hand:

### 1. Skills

```bash
cp -r skills/. ~/.codex/skills/                     # every user, every repo
mkdir -p ~/.claude/flow && cp CORE.md ~/.claude/flow/CORE.codex.md

cp -r skills/. /root/of/your/repo/.agents/skills/   # or: this repo only
```

Skills are invoked with `$flow-feat-start {TICKET}`, `$flow-bug-investigate`, `$flow-work-status`. A running session does not pick up new skills — start a new one.

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
$flow-feat-start PROJ-12345

# Resume where you left off
$flow-work-resume

# Morning standup across all your work (local + forge + tracker)
$flow-work-daily

# See all open work
$flow-work-status

# Start a bug
$flow-bug-start PROJ-99999

# Watch after a deployment (one cycle; set up cron to repeat)
$flow-work-watch PROJ-12345 30m
```

## Dependencies

- **Codex CLI** installed and configured with your OpenAI API key.
- **domain-memory MCP** installed if you name its tools in the `knowledge` section of FLOW.md. Project: https://github.com/mashware/domain-memory
- **git CLI** configured (`glab`, `gh`, or other per `git.cli` in FLOW.md) to create MRs/PRs from the terminal.

## Differences from the original plugin (Claude Code)

Each skill opens with a legend mapping the Claude Code primitives to Codex; `PRIMITIVES.md` has the full table. The most important points:

- **AskUserQuestion**: no structured UI → questions become plain text.
- **ScheduleWakeup** (watch autopilot): does not exist in Codex → `$flow-work-watch` runs one cycle and exits; use OS cron or Codex app Automations to repeat it.
- **`$ARGUMENTS`**: Codex substitutes nothing into a skill, so the body's legend tells the agent to read the arguments off the user's message.
- **Parallel fan-out**: ports directly — the plugin describes it as parallel subagents, which Codex has. Leave `agents.fanout_tool` empty in `FLOW.md`; `agents.fanout_max` (empty → 4) caps each round.
