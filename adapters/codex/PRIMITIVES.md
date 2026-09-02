# PRIMITIVES.md — primitive translation table

How each Claude Code-specific primitive maps to the Codex CLI adapter, and what has no equivalent.

> The generated prompts carry a short **legend** right after their title; it comes from the `LEGEND`
> dict in `script/adapter-build.py`. This document is the long form of that legend. The prompt body
> itself is the plugin's, untouched — the legend defines the terms, the body keeps using them.

## Translation table

| Primitive (Claude Code) | Meaning | Codex translation |
|-------------------------|---------|-------------------|
| `Agent <role>` / subagent | Delegates isolated work to a subagent | Subagent defined in `[agents.<name>]` of `~/.codex/config.toml`. The role name comes from the `agents.<role>` map in `FLOW.md`. If that field is empty in FLOW.md, do it in this context. |
| `AskUserQuestion` | Structured option menu to the user (built-in UI in Claude Code) | **Plain text question**: ask with numbered options and wait for the reply. No structured UI in Codex. |
| `ScheduleWakeup` (watch autopilot) | Re-wake in N min within the current session | **Does not exist in Codex CLI**. See "What does NOT port 1:1" below. |
| Parallel fan-out | N subagents in one round + synthesis by the main agent | **Ports directly** — the plugin describes fan-out as parallel subagents, and Codex supports multiple simultaneous subagents in the same response. Cap the round at `agents.fanout_max` from FLOW.md (empty → 4); leave `agents.fanout_tool` empty, it names a harness-specific orchestrator Codex does not have. |
| `Skill commit-commands:commit-push-pr` | Create commit + push + MR/PR | Manual sequence: `git add`, `git commit`, `git push -u origin HEAD`, and the `git.cli` CLI from FLOW.md (e.g. `glab mr create` or `gh pr create`). |
| `Skill save-knowledge` | Consolidate the branch's knowledge findings | `/flow-save-knowledge` from this adapter. |
| `Skill flow:flow-core` | Load the shared rules once per session | **Read `~/.claude/flow/CORE.codex.md`** — `install.sh` puts it there from `CORE.md`. |
| `/model <value>` | Switch the session's model | The `--model` flag at launch (or `/model` if your Codex version has it). Reported, not enforced — see `models` below. |
| `mcp__domain-memory__<tool>` | Call the domain-memory MCP | The **same MCP server** (same tool name). Only the configuration changes: in Claude Code it's referenced from `.mcp.json`; in Codex it's declared in `~/.codex/config.toml` under `[mcp_servers.domain-memory]`. See `config.snippet.toml`. |
| `TaskCreate` / `TaskStop` | Track steps with Claude Code's task UI | Does not exist in Codex. Track progress through the markdown artifact log (`05-implementation.md`, `04-fix.md`) and report it to the user in text. |

## What does NOT port 1:1

### AskUserQuestion
Claude Code has an `AskUserQuestion` tool that presents options as buttons in the UI. Codex does not have this primitive — all questions to the user are asked as plain text in the response. The behavior is equivalent: the agent asks and waits for the user's response before continuing. Options are listed in prose (e.g. "Options: (1) Yes, go ahead. (2) No, something's missing. (3) Cancel.").

### ScheduleWakeup (watch autopilot)
The `ScheduleWakeup` primitive in Claude Code lets the agent automatically re-wake N minutes later within the same session, creating a self-piloted loop. **Codex CLI does not have this in-session auto-reschedule capability.**

What the legend asks of `/flow-work-watch` instead:
- One invocation is **one watch cycle**.
- State between cycles is persisted in `.claude/work/<TICKET>/monitor.md` (watched surface, approved plan, concrete queries, baseline values, last readings).
- For continuous monitoring, the user sets up an OS cron job + `codex exec "/flow-work-watch {TICKET}"` at the desired interval; or uses the native Codex app Automations if available.
- On re-entry the plugin prose already finds the approved plan in `monitor.md` and skips straight to the cycle without repeating discovery or asking for confirmation again.

### TaskCreate / TaskStop
Claude Code's task UI does not exist in Codex. Step tracking is done through the workflow's markdown artifacts (implementation log in `05-implementation.md`, `04-fix.md`) and reports to the user at the end of each step.

---

## `models` in `FLOW.md` — model per kind of step

`FLOW.md` has a `models` section with one key per **kind of step**: `study` (start, brainstorm,
design, plan, diagnose, investigate, postmortem), `code` (build, fix, green), `test` (validate),
`review` (review, query, respond triage) and `workers` (the parallel fan-out rounds only). **Every
key is empty by default, and empty means the step runs with the model the session was launched
with** — a repo that never fills the section behaves exactly as before. The values are free text
handed to the harness: flow neither validates nor ranks model names.

How it lands here:

- **Subagent steps** — a subagent's model is set where it is declared (`model = "..."` under `[agents.<name>]` in
  `config.toml`), not at invocation time. To honour a `models` key, invoke a subagent declared with that model.
  A subagent named in `agents.<role>` keeps whatever its own definition sets; the `models` keys apply
  where the command falls back to a general-purpose subagent, and to the fan-out workers.
- **What the conductor does itself** — reading the ticket, designing, and writing the code in
  `build`/`fix` (single-thread on XS/S/M): a session cannot switch its own model. There the
  configured value is **reported, not enforced**: the phase handoff says it in one line (the `--model` flag at launch, or `/model` if your Codex version has it),
  records it in the phase artifact, and continues. It is deliberately not a gate — model choice is
  flow mechanics, and `guided`/`auto` never stop for mechanics.

Full reference: `docs/CONFIGURATION.md` §`models` in the repo.
