# Primitive map: flow plugin → Gemini CLI

## Translation table

| Original primitive (Claude Code) | Meaning | Translation in this adapter |
|---|---|---|
| `AskUserQuestion` | Structured options menu waiting for the user's choice | Plain text question. Gemini CLI has no structured menu; the agent asks and waits for the user's free-text reply. |
| `ScheduleWakeup(N min)` | Auto-wake in N minutes within the session | **Does not exist in session.** The `/flow:work:watch` command runs one cycle and exits. To repeat it: OS cron + `gemini -p "/flow:work:watch TICKET"`. State between cycles lives in `monitor.md` (surface, baseline, approved plan). |
| `Workflow` (parallel fan-out) | Deterministic orchestration of N agents in parallel + synthesis | If the user has declared sub-agents in `.gemini/agents/`, invoke them with `@name`. If no sub-agents are configured, run tasks sequentially in the same context. The Workflow fan-out in `/flow:feat:brainstorm`, `/flow:bug:investigate`, and `/flow:feat:review`/`/flow:bug:review` is where parallelism adds the most value. |
| `Agent <role>` / `Agent general-purpose` | Delegate isolated work to a sub-agent of a specific type | `@name` where `name` comes from the `agents.<role>` map in FLOW.md. If the field is empty or the agent does not exist in `.gemini/agents/`, the conductor performs the task in the same context. |
| `Skill commit-commands:commit-push-pr` | Create commit + push + open MR/PR | Run directly: `git add`, `git commit`, `git push -u origin HEAD`, and the `git.cli` CLI from FLOW.md (e.g. `glab mr create` or `gh pr create`). |
| `Skill save-knowledge` | Consolidate domain-memory findings | Run the `/flow:save-knowledge` command from this adapter. |
| `Skill <others>` | Invoke a reusable project flow | Include the logic inline in the prompt or invoke the corresponding sub-agent with `@name`. |
| `TaskCreate` / `TaskUpdate` | Step tracking with status (in_progress, completed) | Maintain a manual markdown checklist in `05-implementation.md` or `04-fix.md`. Update it as work progresses. |
| `mcp__domain-memory__<tool>` | Call to a domain-memory MCP tool | The tool name is identical. Only the server configuration mechanism changes (see `settings.snippet.json`). |
| `$ARGUMENTS` | Arguments passed to the command | `{{args}}` in Gemini CLI TOML. |

---

## What is ported unchanged

The following rules are kept identical to the original plugin version:

- Phase gates for each command (`phases_done`, `meta.json` as source of truth).
- Untrusted input quarantine (logs, traces, user payloads treated as inert data).
- Adversarial design verification (challenger in `/flow:feat:design` and `/flow:bug:investigate`).
- Pre-deploy section + blocking thread in `/flow:feat:ship` and `/flow:bug:ship`.
- Reading `FLOW.md` in step 0 of every command.
- `domain_memory` degradation rule: if the MCP does not respond within 2 s or fails, continue without context without notifying the user.
- Business brief required before writing code (`/flow:feat:build`, `/flow:bug:fix`).
- MR/PR preview before creating (`/flow:feat:ship`, `/flow:bug:ship`).
- Design contract anchoring (verbatim copy + double-blind verification).

---

## What was trimmed or degrades

### `AskUserQuestion` — no structured menu

In Claude Code, `AskUserQuestion` presents numbered options and the user picks one. Gemini CLI has no such mechanism. Commands ask in free text. The flow is equivalent, but the interaction is less guided: the user must type their choice rather than pressing a number.

### `/flow:work:watch` autopilot — no `ScheduleWakeup` in session

In Claude Code, `/flow:work:watch` reschedules itself automatically within the session using `ScheduleWakeup`. Gemini CLI has no session-level equivalent. Solution:

1. The command runs **one monitoring cycle** and exits.
2. To repeat every 5 minutes, configure a cron job:
   ```
   */5 * * * * gemini -p "/flow:work:watch TICKET" >> ~/.gemini/watch-TICKET.log 2>&1
   ```
3. State between cycles (monitored surface, baseline, approved plan, accumulated verdicts) is persisted in `.claude/work/TICKET/monitor.md`. The command reads it at the start of each cycle to avoid repeating the discovery step.
4. The manual alternative is `/loop 5m /flow:work:watch TICKET` if the user's harness has that command available.

### Parallel fan-out — conditional on configured sub-agents

The fan-out in `/flow:feat:brainstorm`, `/flow:bug:investigate`, and the adversarial reviewers of `/flow:feat:review`/`/flow:bug:review` is only parallel if the user has declared sub-agents in `.gemini/agents/`. Without them, execution is sequential in the same context. The result is functionally equivalent but slower and with less diversity of perspectives.

---

## Sub-agents in Gemini CLI: reference format

Sub-agent names come from the `agents` map in FLOW.md (fields `architecture`, `persistence`, `api`, `performance`, `security`, `testing`, `queues`, `frontend`, `frontend_test`).

To declare a sub-agent in Gemini CLI, create `.gemini/agents/<name>.md` with this frontmatter:

```markdown
---
name: <name>           # must match the value in FLOW.md agents.<role>
description: <what it does>  # Gemini uses this for automatic selection by description
kind: agent              # optional; indicates it is a delegable sub-agent
tools:                   # optional; list of allowed tools
  - read_file
  - run_shell_command
mcpServers:              # optional; inherits from settings.json if not specified
  - domain-memory
model: gemini-2.5-pro    # optional; inherits from the conductor by default
temperature: 0.3         # optional
max_turns: 20            # optional
timeout_mins: 10         # optional
---

<!-- Sub-agent system prompt starts here -->
You are the <role> agent for the project. Your job is...
```

Invocation from a command: `@name task here`.

**Do not bundle concrete agents in this adapter.** Sub-agent names and prompts are project- and team-specific. Those for your project go in `.gemini/agents/` (local, not versioned in the plugin).
