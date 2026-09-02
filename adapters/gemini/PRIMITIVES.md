# Primitive map: flow plugin → Gemini CLI

> The generated commands carry a short **legend** right after their title; it comes from the `LEGEND`
> dict in `script/adapter-build.py`. This document is the long form of that legend. The command prose
> itself is the plugin's, untouched — the legend defines the terms, the body keeps using them.

## Translation table

| Original primitive (Claude Code) | Meaning | Translation in this adapter |
|---|---|---|
| `AskUserQuestion` | Structured options menu waiting for the user's choice | Plain text question with numbered options. Gemini CLI has no structured menu; the agent asks and waits for the user's free-text reply. |
| `ScheduleWakeup(N min)` | Auto-wake in N minutes within the session | **Does not exist in session.** One invocation of `/flow:work:watch` is one cycle. To repeat it: OS cron + `gemini -p "/flow:work:watch TICKET"`. State between cycles lives in `monitor.md` (surface, baseline, approved plan). |
| Parallel fan-out | N subagents in one round, main agent synthesizes | **Ports directly** — the plugin describes the fan-out as parallel subagents, not as a Claude Code tool. Invoke them with `@name` from `.gemini/agents/`; with no sub-agents configured, run the round sequentially in the same context (same rounds, same briefs, more wall-clock). Respect `agents.fanout_max` from FLOW.md (empty → 4) and leave `agents.fanout_tool` empty: it names a harness-specific orchestrator that Gemini CLI does not have. The fan-out points are `/flow:feat:brainstorm` §3.A, `/flow:bug:investigate` §3.A and `/flow:feat:review`/`/flow:bug:review`. |
| `Agent <role>` / `Agent general-purpose` | Delegate isolated work to a sub-agent of a specific type | `@name` where `name` comes from the `agents.<role>` map in FLOW.md. If the field is empty or the agent does not exist in `.gemini/agents/`, the conductor performs the task in the same context. |
| `Skill commit-commands:commit-push-pr` | Create commit + push + open MR/PR | Run directly: `git add`, `git commit`, `git push -u origin HEAD`, and the `git.cli` CLI from FLOW.md (e.g. `glab mr create` or `gh pr create`). |
| `Skill save-knowledge` | Consolidate the branch's knowledge findings | Run the `/flow:save-knowledge` command from this adapter. |
| `Skill flow:flow-core` | Load the shared rules once per session | Read `~/.claude/flow/CORE.gemini.md` — `install.sh` puts it there from `CORE.md`. |
| `/model <value>` | Switch the session's model | The `--model` flag at launch. Reported, not enforced — see `models` below. |
| `TaskCreate` / `TaskUpdate` | Step tracking with status (in_progress, completed) | Maintain a manual markdown checklist in `05-implementation.md` or `04-fix.md`. Update it as work progresses. |
| `mcp__domain-memory__<tool>` | Call to a domain-memory MCP tool | The tool name is identical. Only the server configuration mechanism changes (see `settings.snippet.json`). |
| `$ARGUMENTS` | Arguments passed to the command | `{{args}}` in Gemini CLI TOML — the generator rewrites it. |

---

## What is ported unchanged

Everything the plugin prose says — the generator does not rewrite a sentence of it. In particular:

- Phase gates for each command (`phases_done`, `meta.json` as source of truth).
- Untrusted input quarantine (logs, traces, user payloads treated as inert data).
- Adversarial design verification (challenger in `/flow:feat:design` and `/flow:bug:investigate`).
- Pre-deploy section + blocking thread in `/flow:feat:ship` and `/flow:bug:ship`.
- Reading `FLOW.md` in step 0 of every command.
- `knowledge` degradation rule: `knowledge.*` roles: if a tool does not respond within `knowledge.timeout_s` (2 s) or fails, continue without it, silently.
- Business brief required before writing code (`/flow:feat:build`, `/flow:bug:fix`).
- MR/PR preview before creating (`/flow:feat:ship`, `/flow:bug:ship`).
- Design contract anchoring (verbatim copy + double-blind verification).

---

## What degrades

### `AskUserQuestion` — no structured menu

In Claude Code, `AskUserQuestion` presents numbered options and the user picks one. Gemini CLI has no such mechanism. Commands ask in free text. The flow is equivalent, but the interaction is less guided: the user must type their choice rather than pressing a number.

### `/flow:work:watch` autopilot — no `ScheduleWakeup` in session

In Claude Code, `/flow:work:watch` reschedules itself automatically within the session using `ScheduleWakeup`. Gemini CLI has no session-level equivalent. What the legend asks instead:

1. One invocation is **one monitoring cycle**.
2. To repeat every 5 minutes, configure a cron job:
   ```
   */5 * * * * gemini -p "/flow:work:watch TICKET" >> ~/.gemini/watch-TICKET.log 2>&1
   ```
3. State between cycles (monitored surface, baseline, approved plan, accumulated verdicts) is persisted in `.claude/work/TICKET/monitor.md`. The plugin prose already reads it at the start of each cycle to avoid repeating the discovery step.

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

---

## `models` in `FLOW.md` — model per kind of step

`FLOW.md` has a `models` section with one key per **kind of step**: `study` (start, brainstorm,
design, plan, diagnose, investigate, postmortem), `code` (build, fix, green), `test` (validate),
`review` (review, query, respond triage) and `workers` (the parallel fan-out rounds only). **Every
key is empty by default, and empty means the step runs with the model the session was launched
with** — a repo that never fills the section behaves exactly as before. The values are free text
handed to the harness: flow neither validates nor ranks model names.

How it lands here:

- **Subagent steps** — a subagent's model is set in its own definition (`model:` in `.gemini/agents/<name>.md`),
  not at invocation time. To honour a `models` key, declare the subagent you invoke with that model.
  A subagent named in `agents.<role>` keeps whatever its own definition sets; the `models` keys apply
  where the command falls back to a general-purpose subagent, and to the fan-out workers.
- **What the conductor does itself** — reading the ticket, designing, and writing the code in
  `build`/`fix` (single-thread on XS/S/M): a session cannot switch its own model. There the
  configured value is **reported, not enforced**: the phase handoff says it in one line (relaunching with `gemini -m <model>`),
  records it in the phase artifact, and continues. It is deliberately not a gate — model choice is
  flow mechanics, and `guided`/`auto` never stop for mechanics.

Full reference: `docs/CONFIGURATION.md` §`models` in the repo.
