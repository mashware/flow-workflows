# flow → opencode adapter

This directory contains the `flow` plugin adapter for [opencode](https://opencode.ai). The 25 commands of the `feat`/`bug`/`work` flow system have been converted to opencode format (markdown with a `description` frontmatter field).

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

Once installed, invoke them with `/` in opencode:

### Feature flow
| Command | Description |
|---------|-------------|
| `/flow-feat-start <TICKET>` | Start a new feature |
| `/flow-feat-brainstorm` | Generate options and risks before designing |
| `/flow-feat-design` | Design the technical solution |
| `/flow-feat-plan` | Break the work into independent MRs/PRs |
| `/flow-feat-build` | Implement following the approved design |
| `/flow-feat-review` | Mandatory multi-agent code review |
| `/flow-feat-validate` | Validate tests, edge cases, and integrity |
| `/flow-feat-ship` | Commit, push, MR/PR, and offer to save knowledge |

### Bug flow
| Command | Description |
|---------|-------------|
| `/flow-bug-start <TICKET>` | Start the bug flow |
| `/flow-bug-diagnose` | Reproduce the failure and scope what is broken |
| `/flow-bug-investigate` | Find the root cause of the failure |
| `/flow-bug-fix` | Implement the minimal fix |
| `/flow-bug-validate` | Regression test and verification |
| `/flow-bug-review` | Multi-agent code review of the fix |
| `/flow-bug-postmortem` | Lessons learned and offer to save knowledge |
| `/flow-bug-ship` | Commit, push, MR/PR of the fix |

### Cross-cutting commands
| Command | Description |
|---------|-------------|
| `/flow-work-README` | Guide to the flow system |
| `/flow-work-status` | Overview of all open work items |
| `/flow-work-resume` | Resume work on the current branch |
| `/flow-work-abandon` | Close a work item without shipping |
| `/flow-work-try <branch>` | Point the main checkout at a branch to test it (and back), re-syncing per FLOW.md |
| `/flow-work-watch <TICKET> [duration]` | Monitor observability after a deployment (one cycle) |
| `/flow-init` | Generate/update the repo's FLOW.md |
| `/flow-config` | Show the repo's effective FLOW.md config and validate it |
| `/flow-save-knowledge` | Consolidate findings into the domain-memory store |

## Subagent configuration

The commands invoke subagents via `@name` according to the roles declared in `FLOW.md` under `agents.*`. If those fields are empty, the commands fall back to a general-purpose subagent.

To get the most out of the system, declare project-specific subagents in `agents/<name>.md` (project) or `~/.config/opencode/agents/<name>.md` (global). See `PRIMITIVES.md` for the exact format and the table of names the adapter expects.

## Continuous monitoring with work-watch

The `/flow-work-watch` command runs **one cycle** and persists state in `monitor.md`. For continuous monitoring, set up a cron job:

```bash
# Example: monitor every 5 minutes (adjust the path and ticket)
*/5 * * * * cd /path/to/repo && opencode run -p "/flow-work-watch PROJ-XXXXX"
```

See `PRIMITIVES.md` for more details on this difference from the original plugin.

## What does not port 1:1

See `PRIMITIVES.md` for the full breakdown. Summary:

- `AskUserQuestion` → plain-text question; no structured menu.
- `watch` autopilot → OS cron + `opencode run -p`; state between cycles lives in `monitor.md`.
