# PRIMITIVES.md — Primitive translation map

This document explains how each Claude Code-specific primitive was translated to the opencode adapter, and which capabilities have no direct equivalent.

## Translation table

| Claude Code primitive | Original meaning | opencode translation | Notes |
|---|---|---|---|
| `Agent <role>` / subagent | Delegates isolated work to a subagent with its own tools | `@name` (invoke a subagent declared in `agents/<name>.md` with `mode: subagent`) | See "How to declare subagents" below |
| `AskUserQuestion` | Structured menu with clickable options | **Plain-text question to the user, wait for reply** | No structured UI exists in opencode — the agent writes the question with numbered options and the user replies in text |
| `ScheduleWakeup` | Re-wake the session in N minutes (watch autopilot) | **OS cron + `opencode run -p "<prompt>"`** | No in-session rescheduling exists; `work-watch` runs one cycle and exits; state between cycles is saved in `monitor.md`; the user configures the cron |
| `Workflow` (deterministic parallel orchestration) | Parallel fan-out with synthesis — multiple agents running in parallel without seeing each other | **Multiple `@name` subagents launched in the same prompt** (opencode may run them in parallel if the tool supports it); otherwise sequential with manual consolidation | The main agent synthesizes results from all subagents before continuing |
| `Skill commit-commands:commit-push-pr` | Create commit + push + MR/PR using the tool's built-in skill | **Manual git + `git.cli` CLI from `FLOW.md`** (e.g. `glab mr create` or `gh pr create`) | If an equivalent skill/command exists in opencode, use it; otherwise the steps are explicit in `/flow-feat-ship` and `/flow-bug-ship` |
| `Skill <name>` (other skills) | Invoke a reusable flow from the tool | **Inline**: the skill content is incorporated into the prompt of the command that used to invoke it | Project convention skills are loaded by reading the files referenced in `FLOW.md` under `conventions` |
| `mcp__domain-memory__search_knowledge` | Query the domain-memory MCP | **Same tool name**: `mcp__domain-memory__search_knowledge` | The MCP server is configured in `opencode.json` under `mcp.domain-memory` |
| `mcp__domain-memory__stage_finding` | Stage a domain finding | **Same name**: `mcp__domain-memory__stage_finding` | Idem |
| `mcp__domain-memory__read_staging` | Read the current branch's staging area | **Same name**: `mcp__domain-memory__read_staging` | Idem |
| `mcp__domain-memory__save_knowledge` | Save to the domain-memory store | **Same name**: `mcp__domain-memory__save_knowledge` | Idem |
| `TaskCreate` (create task list) | Track implementation steps | **Markdown checklist in the artifact** (`05-implementation.md`): steps are noted as `- [ ] step` and marked `- [x]` when done | opencode has no native TaskCreate tool; the artifact log serves the same purpose |

## What does NOT port 1:1

### AskUserQuestion
In Claude Code, `AskUserQuestion` shows a structured menu with buttons/options the user can click. opencode has no such UI — the agent writes the question with the options listed as text (e.g. "Choose an option: 1) Yes, go ahead. 2) No, edit. 3) Cancel.") and the user replies with the number or the option text.

**Practical effect**: confirmations and user choices remain explicit and mandatory; only the mechanism changes (text vs structured UI).

### Watch autopilot (ScheduleWakeup)
In Claude Code, `work:watch` uses `ScheduleWakeup` to reschedule itself automatically within the same session: the agent sleeps N minutes and wakes up on its own, without user intervention.

In opencode **this mechanism does not exist in-session**. The equivalent is:

1. **One cycle per run**: `work-watch` executes **one monitoring cycle** (queries signals, reports, updates `monitor.md`) and exits.
2. **Persisted state**: everything needed for the next cycle (plan, baseline, T0, T_fin, signals, accumulated state) is saved in `.claude/work/<TICKET>/monitor.md`.
3. **Continuous cycles via cron**: the user sets up an OS cron job or scheduled task that runs `opencode run -p "/flow-work-watch {TICKET}"` every ~5 minutes. Example:
   ```bash
   # Example crontab: monitor PROJ-15421 every 5 minutes
   */5 * * * * cd /path/to/repo && opencode run -p "/flow-work-watch PROJ-15421"
   ```
4. **Clean re-entry**: at the start of each cycle, `work-watch` detects whether `monitor.md` already has an approved plan and jumps directly to §5 (cycle) without repeating discovery.

**Practical effect**: continuous monitoring requires explicit cron configuration by the user; in Claude Code it was automatic. The manual alternative (`/loop 5m /flow-work-watch {TICKET}` from Claude Code) does not exist in opencode either — the closest option is the cron.

## How to declare subagents in opencode

The commands in this adapter invoke subagents via `@name`. For them to work, the user must declare them in `agents/<name>.md` (in the project or global opencode directory).

### Subagent format

```markdown
---
description: <Brief description of the subagent's role>
mode: subagent
model: <model, e.g. claude-sonnet-4-5>
temperature: 0.3
---

<Subagent system prompt here>
```

### Where to declare subagents

- **Project**: `.opencode/agents/<name>.md`
- **Global**: `~/.config/opencode/agents/<name>.md`

### Names the adapter expects

Subagent names are not defined in the adapter — the user defines them in `FLOW.md` under the `agents.*` fields. The adapter references them as `@<agents.architecture>`, `@<agents.persistence>`, etc. If an `agents.*` field is empty, the command uses a general-purpose subagent with the role described in the prompt.

**Example `FLOW.md`**:
```yaml
## agents
- architecture: ddd-symfony-architect
- persistence: doctrine-orm-specialist
- testing: test-writer
- security: security-backend
- performance: performance-analyzer
- frontend: frontend-react-specialist
- frontend_test: frontend-testing-specialist
- queues: dlx-analyzer
```

With this, `/flow-feat-design` will launch `@ddd-symfony-architect` for architecture, `@doctrine-orm-specialist` for persistence, etc.

## Graceful degradation when a subagent is unavailable

If subagent `@name` does not exist in `agents/`, opencode will report an error. The commands are written with explicit degradation: if the `agents.*` field in `FLOW.md` is empty, a general-purpose subagent with the role described in the prompt is used instead. Therefore the adapter works with no declared subagents — it simply loses the specialization.
