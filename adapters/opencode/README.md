# flow → opencode adapter

The `flow` plugin adapter for [opencode](https://opencode.ai): **one file per plugin command,
generated** by `script/adapter-build.py` (see [`../README.md`](../README.md)) in opencode's format
— markdown with a `description` frontmatter field — plus `CORE.md`, the shared flow-core rules every
command reads once per session. Do not edit these files by hand; edit the plugin and rebuild.

## Command notation: `:` → `-`

opencode does not support the `:` namespace separator that Claude Code uses, so every command is
flattened to a hyphenated name. When following the docs or the main README, translate accordingly:

| Claude Code | opencode |
|---|---|
| `/flow:init` | `/flow-init` |
| `/flow:config` | `/flow-config` |
| `/flow:feat:start` | `/flow-feat-start` |
| `/flow:bug:diagnose` | `/flow-bug-diagnose` |
| `/flow:work:status` | `/flow-work-status` |

The logic and prose of each command are identical; only the invocation name changes.

## Requirements

- opencode installed and configured.
- A `FLOW.md` file at the root of each repo where you want to use the flows. You can start from the template:
  ```
  ../../plugins/flow/examples/FLOW.template.md
  ```
  If `FLOW.md` does not exist, the commands work with default behavior (they auto-discover repo conventions).

## Installation

The simple path is the shared script, which also places `CORE.md`, the changelog and the manifest
under `~/.claude/flow/`:

```bash
../install.sh opencode            # global
../install.sh opencode project    # current repo only (.opencode/commands)
```

### By hand — Option A: global installation (available in all projects)

```bash
cp commands/*.md ~/.config/opencode/commands/
mkdir -p ~/.claude/flow && cp CORE.md ~/.claude/flow/CORE.opencode.md
```

Copy the MCP configuration to the global directory (or merge it into your existing `opencode.json`):

```bash
# If you don't have a global opencode.json yet:
cp opencode.json ~/.config/opencode/opencode.json

# If you already have one, manually merge the "mcp" section:
# "mcp": { "domain-memory": { "command": "npx", "args": ["-y", "domain-memory-mcp"] } }
```

### By hand — Option B: per-project installation (current repo only)

```bash
mkdir -p .opencode/commands
cp /path/to/adapters/opencode/commands/*.md .opencode/commands/
mkdir -p ~/.claude/flow && cp /path/to/adapters/opencode/CORE.md ~/.claude/flow/CORE.opencode.md
cp /path/to/adapters/opencode/opencode.json .opencode/opencode.json   # or merge the "mcp" section
```

## Autonomy

How far each phase advances on its own is controlled by `autonomy.mode` in `FLOW.md`
(documented in `../../plugins/flow/examples/FLOW.template.md`):

- `manual` (default) — every phase stops at each decision and only recommends the next command.
- `guided` — resolves low-risk, unambiguous decisions itself (recorded in the phase artifact) and
  chains into the next command; still asks at genuine decision points.
- `auto` — as `guided`, plus auto-resolves the remaining decisions with recorded defaults.

**Hard gates always stop and ask, in every mode:** any push or MR/PR, creating a branch on an
ambiguous base, DB schema changes/migrations, and a review with high-severity findings.

## Available commands

Every command in `../../plugins/flow/commands/` has its mirror here, named by the `:` → `-` rule
(`feat/ship.md` → `/flow-feat-ship`). `ls commands/` is the current list; `/flow-work-README` is
the guide to the whole system, and each file's `description` frontmatter says what it does.

## Subagent configuration

The commands invoke subagents via `@name` according to the roles declared in `FLOW.md` under `agents.*`. If those fields are empty, the commands fall back to a general-purpose subagent.

To get the most out of the system, declare project-specific subagents in `agents/<name>.md` (project) or `~/.config/opencode/agents/<name>.md` (global). See `PRIMITIVES.md` for the exact format and the table of names the adapter expects.

## Continuous monitoring with work-watch

`/flow-work-watch` runs **one cycle** per invocation and persists state in `monitor.md`. For continuous monitoring, set up a cron job:

```bash
# Example: monitor every 5 minutes (adjust the path and ticket)
*/5 * * * * cd /path/to/repo && opencode run -p "/flow-work-watch PROJ-XXXXX"
```

See `PRIMITIVES.md` for more details on this difference from the original plugin.

## What does not port 1:1

The legend at the top of every generated command maps the Claude Code primitives to opencode;
`PRIMITIVES.md` is the full breakdown. Summary:

- `AskUserQuestion` → plain-text question; no structured menu.
- `watch` autopilot → OS cron + `opencode run -p`; state between cycles lives in `monitor.md`.
