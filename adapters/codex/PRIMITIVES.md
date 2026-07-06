# PRIMITIVES.md — primitive translation table

How each Claude Code-specific primitive was translated for the Codex CLI adapter, and what was trimmed or simplified.

## Translation table

| Primitive (Claude Code) | Meaning | Codex translation |
|-------------------------|---------|-------------------|
| `Agent <role>` / subagent | Delegates isolated work to a subagent | Subagent defined in `[agents.<name>]` of `~/.codex/config.toml`. The role name comes from the `agents.<role>` map in `FLOW.md`. If that field is empty in FLOW.md, a general subagent is used in the prompt. |
| `AskUserQuestion` | Structured option menu to the user (built-in UI in Claude Code) | **Plain text question**: the prompt instructs the agent to ask the user and wait for a response. No structured UI in Codex → becomes "ask the user and wait for a response" in prose. |
| `ScheduleWakeup` (watch autopilot) | Re-wake in N min within the current session | **Does not exist in Codex CLI**. See "What does NOT port 1:1" section below. |
| `Workflow` (parallel orchestration) | Deterministic parallel fan-out + synthesis | Subagents launched in parallel (Codex supports multiple simultaneous subagents in the same response). Explicit orchestration with the `Workflow` DSL is replaced by instructions to the main agent to launch N subagents in parallel and wait for their results before synthesizing. |
| `Skill commit-commands:commit-push-pr` | Create commit + push + MR/PR | Manual sequence: `git add`, `git commit`, `git push -u origin HEAD`, and the `git.cli` CLI from FLOW.md (e.g. `glab mr create` or `gh pr create`). The agent executes the steps directly. |
| `Skill <others>` (save-knowledge, code-review, etc.) | Invoke a reusable Claude Code workflow | Skills become their own prompts in the adapter (e.g. `/flow-save-knowledge`) or are referenced by name if the project has them configured in Codex. |
| `mcp__domain-memory__<tool>` | Call the domain-memory MCP | The **same MCP server** (same tool name). Only the configuration changes: in Claude Code it's referenced from `.mcp.json`; in Codex it's declared in `~/.codex/config.toml` under `[mcp_servers.domain-memory]`. See `config.snippet.toml`. |
| `TaskCreate` / `TaskStop` | Track steps with Claude Code's task UI | Does not exist in Codex. The agent tracks step progress through the markdown artifact log (`05-implementation.md`, `04-fix.md`) and reports progress to the user in text. |

## What does NOT port 1:1

### AskUserQuestion
Claude Code has an `AskUserQuestion` tool that presents options as buttons in the UI. Codex does not have this primitive — all questions to the user are asked as plain text in the response. The behavior is equivalent: the agent asks and waits for the user's response before continuing. Options are listed in prose (e.g. "Options: (1) Yes, go ahead. (2) No, something's missing. (3) Cancel.").

### ScheduleWakeup (watch autopilot)
The `ScheduleWakeup` primitive in Claude Code lets the agent automatically re-wake N minutes later within the same session, creating a self-piloted loop. **Codex CLI does not have this in-session auto-reschedule capability.**

Solution adopted in `/flow-work-watch`:
- The command runs **a single watch cycle** and exits.
- State between cycles is persisted in `.claude/work/<TICKET>/monitor.md` (watched surface, approved plan, concrete queries, baseline values, last readings).
- For continuous monitoring, the user sets up an OS cron job + `codex exec "/flow-work-watch {TICKET}"` at the desired interval; or uses the native Codex app Automations if available.
- On re-entry (when `monitor.md` already exists with the approved plan), the command skips directly to cycle §5 without repeating discovery or asking for confirmation again.

### Workflow DSL
Claude Code's `Workflow` DSL lets you define phases, per-agent structured schemas, and deterministic orchestration with typing. In Codex, parallel orchestration is expressed in natural language: the main agent receives instructions to launch N subagents in parallel with their respective assignments and wait for their structured results before synthesizing. The practical outcome is equivalent, though without the formal typing of the DSL.

### TaskCreate / TaskStop
Claude Code's task UI does not exist in Codex. Step tracking is done through the workflow's markdown artifacts (implementation log in `05-implementation.md`, `04-fix.md`) and reports to the user at the end of each step.
