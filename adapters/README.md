# adapters — `flow` workflows for other harnesses

The `flow` plugin (in `../plugins/flow`) is for **Claude Code**. These adapters bring the same
`feat`/`bug`/`work` workflows to other terminal agents, rewriting only the **wrapper**
(command format, subagents, MCP) — the **logic and prose are the same**.

| Harness | Commands | Subagents | MCP | Autopilot watch |
|---|---|---|---|---|
| **opencode** | `commands/*.md` (`/feat-start`) | `agents/*.md` `mode:subagent`, `@name` | `opencode.json` | cron + `opencode run -p` |
| **Gemini CLI** | `commands/**/*.toml` (`/feat:start`) | `.gemini/agents/*.md`, `@name` | `settings.json` `mcpServers` | cron + `gemini -p` |
| **Codex CLI** | `prompts/*.md` (`/feat-start`) | `[agents.*]` in `config.toml` | `[mcp_servers.*]` | cron + `codex exec` |

## Install

```bash
./install.sh opencode      # or: gemini | codex
./install.sh opencode project   # project-scoped variant (where applicable)
```
The script **copies the commands** (additive, safe) and tells you which **config fragment**
(MCP/subagents) to merge manually into your `opencode.json` / `settings.json` / `config.toml` —
it does not touch your configs automatically so it doesn't overwrite what you already have.

After that: place a **`FLOW.md`** at the root of your repo (template at
`../plugins/flow/examples/FLOW.template.md`). It configures the tracker, git, test commands,
observability, and the subagent map for YOUR project.

## What ports and what doesn't (honest)

- **Ports unchanged**: phases (start→ship, diagnose→postmortem), rules, gates, `FLOW.md`, MCP
  (`domain-memory`), Pre-deploy + blocking thread, and **subagents** (review/investigate) —
  all three harnesses support them; only the declaration format changes.
- **Trimmed** (see each adapter's `PRIMITIVES.md`):
  - **`AskUserQuestion`**: none of them have a structured menu UI → becomes a plain text question.
  - **Autopilot for `/work:watch`**: no in-session re-wakeup → replaced by **OS cron +
    headless execution**. The command runs ONE cycle and exits; state lives in `monitor.md`,
    which each cycle re-reads. It works, but the trigger is external, not the session itself.

## Warning

These adapters were generated **faithfully following each tool's documented format, but without
being run inside it** (they can't be executed from here). They are a solid first version;
validate them when you use them and adjust paths if your harness version differs — especially
in Codex, where the prompts location changes between versions (see `codex/README.md`).

> Single source of truth for the logic: `../plugins/flow/commands/`. If you change a workflow
> there, regenerate the affected adapter to keep them in sync.
