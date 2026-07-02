# flow → opencode adapter

This directory contains the `flow` plugin adapter for [opencode](https://opencode.ai). The 24 commands of the `feat`/`bug`/`work` flow system have been converted to opencode format (markdown with a `description` frontmatter field).

## Command notation: `:` → `-`

opencode does not support the `:` namespace separator that Claude Code uses, so every command is
flattened to a hyphenated name. When following the docs or the main README, translate accordingly:

| Claude Code | opencode |
|---|---|
| `/flow:init` | `/flow-init` |
| `/flow:config` | `/flow-config` |
| `/flow:feat:start` | `/feat-start` |
| `/flow:bug:diagnose` | `/bug-diagnose` |
| `/flow:work:status` | `/work-status` |

The logic and prose of each command are identical; only the invocation name changes.

## Requirements

- opencode installed and configured.
- A `FLOW.md` file at the root of each repo where you want to use the flows. You can start from the template:
  ```
  ../../plugins/flow/examples/FLOW.template.md
  ```
  If `FLOW.md` does not exist, the commands work with default behavior (they auto-discover repo conventions).

## Installation

### Option A: global installation (available in all projects)

Copy the commands to the opencode global directory:

```bash
cp commands/*.md ~/.config/opencode/commands/
```

Copy the MCP configuration to the global directory (or merge it into your existing `opencode.json`):

```bash
# If you don't have a global opencode.json yet:
cp opencode.json ~/.config/opencode/opencode.json

# If you already have one, manually merge the "mcp" section:
# Add to ~/.config/opencode/opencode.json:
# "mcp": { "domain-memory": { "command": "npx", "args": ["-y", "domain-memory-mcp"] } }
```

### Option B: per-project installation (current repo only)

Copy the commands to the project's opencode directory:

```bash
mkdir -p .opencode/commands
cp /path/to/adapters/opencode/commands/*.md .opencode/commands/
```

Copy or merge the `opencode.json` into the project root:

```bash
cp /path/to/adapters/opencode/opencode.json .opencode/opencode.json
# or merge the "mcp" section into the existing opencode.json
```

## Available commands

Once installed, invoke them with `/` in opencode:

### Feature flow
| Command | Description |
|---------|-------------|
| `/feat-start <TICKET>` | Start a new feature |
| `/feat-brainstorm` | Generate options and risks before designing |
| `/feat-design` | Design the technical solution |
| `/feat-plan` | Break the work into independent MRs/PRs |
| `/feat-build` | Implement following the approved design |
| `/feat-review` | Mandatory multi-agent code review |
| `/feat-validate` | Validate tests, edge cases, and integrity |
| `/feat-ship` | Commit, push, MR/PR, and offer to save knowledge |

### Bug flow
| Command | Description |
|---------|-------------|
| `/bug-start <TICKET>` | Start the bug flow |
| `/bug-diagnose` | Reproduce the failure and scope what is broken |
| `/bug-investigate` | Find the root cause of the failure |
| `/bug-fix` | Implement the minimal fix |
| `/bug-validate` | Regression test and verification |
| `/bug-review` | Multi-agent code review of the fix |
| `/bug-postmortem` | Lessons learned and offer to save knowledge |
| `/bug-ship` | Commit, push, MR/PR of the fix |

### Cross-cutting commands
| Command | Description |
|---------|-------------|
| `/work-README` | Guide to the flow system |
| `/work-status` | Overview of all open work items |
| `/work-resume` | Resume work on the current branch |
| `/work-abandon` | Close a work item without shipping |
| `/work-try <branch>` | Point the main checkout at a branch to test it (and back), re-syncing per FLOW.md |
| `/work-watch <TICKET> [duration]` | Monitor observability after a deployment (one cycle) |
| `/flow-init` | Generate/update the repo's FLOW.md |
| `/flow-config` | Show the repo's effective FLOW.md config and validate it |
| `/save-knowledge` | Consolidate findings into the domain-memory store |

## Subagent configuration

The commands invoke subagents via `@name` according to the roles declared in `FLOW.md` under `agents.*`. If those fields are empty, the commands fall back to a general-purpose subagent.

To get the most out of the system, declare project-specific subagents in `agents/<name>.md` (project) or `~/.config/opencode/agents/<name>.md` (global). See `PRIMITIVES.md` for the exact format and the table of names the adapter expects.

## Continuous monitoring with work-watch

The `/work-watch` command runs **one cycle** and persists state in `monitor.md`. For continuous monitoring, set up a cron job:

```bash
# Example: monitor every 5 minutes (adjust the path and ticket)
*/5 * * * * cd /path/to/repo && opencode run -p "/work-watch PROJ-XXXXX"
```

See `PRIMITIVES.md` for more details on this difference from the original plugin.

## What does not port 1:1

See `PRIMITIVES.md` for the full breakdown. Summary:

- `AskUserQuestion` → plain-text question; no structured menu.
- `watch` autopilot → OS cron + `opencode run -p`; state between cycles lives in `monitor.md`.
