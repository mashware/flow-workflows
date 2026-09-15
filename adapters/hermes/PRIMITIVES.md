# PRIMITIVES.md — primitive translation table

How each Claude Code-specific primitive maps to the Hermes Agent adapter, and what has no equivalent.

> The generated skills carry a short **legend** right after their title; it comes from the `LEGEND`
> dict in `script/adapter-build.py`. This document is the long form of that legend. The skill body
> itself is the plugin's, untouched — the legend defines the terms, the body keeps using them.

## Translation table

| Primitive (Claude Code) | Meaning | Hermes translation |
|-------------------------|---------|--------------------|
| `Agent <role>` / subagent | Delegates isolated work to a subagent | **`delegate_task`**, which builds the child from the `goal` and `context` it is handed — Hermes has no predeclared agents. The name in `agents.<role>` of `FLOW.md` is therefore a role to state in that prompt, not a definition to install. Empty in FLOW.md → do it in this context. |
| `AskUserQuestion` | Structured option menu to the user (built-in UI in Claude Code) | **Plain text question**: ask with numbered options and wait for the reply. No structured UI in Hermes. |
| `ScheduleWakeup` (watch autopilot) | Re-wake in N min within the current session | **The closest of the four adapters**: Hermes has its own scheduler (`cronjob` tool · `/cron add`), so the repetition is native rather than OS cron. Not the same thing, though — see below. |
| Parallel fan-out | N subagents in one round + synthesis by the main agent | **Ports directly** — several `delegate_task` calls in one response. Two ceilings apply, and the lower one wins: `agents.fanout_max` from FLOW.md (empty → 4) and `delegation.max_concurrent_children` in `config.yaml` (default 10). Leave `agents.fanout_tool` empty, it names a harness-specific orchestrator Hermes does not have. |
| `Skill commit-commands:commit-push-pr` | Create commit + push + MR/PR | Manual sequence: `git add`, `git commit`, `git push -u origin HEAD`, and the `git.cli` CLI from FLOW.md (e.g. `glab mr create` or `gh pr create`). |
| `Skill save-knowledge` | Consolidate the branch's knowledge findings | `/flow-save-knowledge` from this adapter. |
| `Skill flow:flow-core` | Load the shared rules once per session | **Read `~/.claude/flow/CORE.hermes.md`** — `install.sh` puts it there from `CORE.md`. |
| `/model <value>` | Switch the session's model | Hermes's own `/model`. For children, `delegation.model` in `config.yaml` — see `models` below. |
| `mcp__domain-memory__<tool>` | Call the domain-memory MCP | The **same MCP server** (same tool name). Only the configuration moves: `mcp_servers` in `~/.hermes/config.yaml`, or `hermes mcp install`. See `config.snippet.yaml`. |
| `TaskCreate` / `TaskStop` | Track steps with Claude Code's task UI | Track progress through the markdown artifact log (`05-implementation.md`, `04-fix.md`) and report it to the user in text. (Hermes has a kanban of its own; the flow does not assume it.) |
| `$ARGUMENTS` | What the user typed after the command | Hermes reads the leading `/skill` tokens and hands the agent everything from the first non-skill token on. So `/flow-feat-start PROJ-412` arrives with `PROJ-412` as the instruction. |

## What does NOT port 1:1

### AskUserQuestion
Claude Code presents options as buttons. Hermes has no such primitive, so every question is plain
text in the response. The behavior is equivalent: the agent asks and waits before continuing.
Options are listed in prose (e.g. "Options: (1) Yes, go ahead. (2) No, something's missing. (3) Cancel.").

### ScheduleWakeup (watch autopilot)
`ScheduleWakeup` lets a Claude Code session re-wake itself N minutes later **inside the same
session**, so the watch keeps its context from cycle to cycle. Hermes does not re-wake a session —
it starts a new one on a schedule:

```
/cron add "every 30m" "/flow-work-watch PROJ-412"
```

What that changes, and why the flow is written the way it is:

- One firing is **one watch cycle**, and it carries **no chat history**. The scheduled text has to
  stand alone — which is what the plugin prose already assumes.
- State between cycles lives in `.claude/work/<TICKET>/monitor.md` (watched surface, approved plan,
  concrete queries, baseline values, last readings). On re-entry the prose finds the approved plan
  there and jumps straight to the cycle, without repeating discovery or re-asking for confirmation.
- Job output lands in `~/.hermes/cron/output/{job_id}/{timestamp}.md`, and the jobs themselves in
  `~/.hermes/cron/jobs.json`. `hermes cron` (or `/cron`) lists and removes them.
- **A firing cannot retire its own job** unless you set `cron.allow_agent_scheduling: true`. Off (the
  default), the watch runs until you stop it by hand; on, it can delete the job when the window closes.
- Each firing resolves its model as per-job pin → `cron.model` → the global default, snapshotted when
  the job was created.

So: the repetition is native, the continuity is not. That is still one degradation fewer than the
opencode, Gemini and Codex adapters, which need OS cron for the same loop.

### TaskCreate / TaskStop
Claude Code's task UI does not exist here. Step tracking is done through the workflow's markdown
artifacts (`05-implementation.md`, `04-fix.md`) and reports to the user at the end of each step.

---

## `models` in the effective FLOW config

The `models` section has two keys: `agents` for every improvised subagent and `workers` for the
parallel fan-out rounds (`workers` falls back to `agents`). Both are optional; empty means inherit
the model the session was launched with. Values are free text handed to the harness: flow neither
validates nor ranks model names.

Put Hermes-specific values in `FLOW.hermes.md`. Hermes reads it after `FLOW.md`, key by key; an
explicitly empty overlay key masks the base, and an absent key inherits it. A repo with only
`FLOW.md` behaves exactly as before.

How it lands here:

- **Subagent steps** — `delegate_task` has **no per-task model parameter**: every child runs on
  `delegation.model` from `config.yaml` (falling back to the session's model). So `models.agents` and
  `models.workers` are honoured by setting that key, and a round cannot mix two models. If the two
  FLOW keys differ, the one you put in `delegation.model` is the one that runs; the other is reported
  at the phase handoff and not enforced.
- **What the conductor does itself** — reading the ticket, designing, and writing the code in
  `build`/`fix` (single-thread on XS/S/M): neither key applies, because a session cannot switch its
  own model mid-run. It continues with the model it was launched with.

Full reference: `docs/CONFIGURATION.md` §`models` in the repo.
