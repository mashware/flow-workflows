# adapters — `flow` workflows for other harnesses

The `flow` plugin (in `../plugins/flow`) is for **Claude Code**. These adapters bring the same
`feat`/`bug`/`work` workflows to other terminal agents, rewriting only the **wrapper**
(command format, subagents, MCP) — the **logic and prose are the same**.

| Harness | Commands | Subagents | MCP | Autopilot watch |
|---|---|---|---|---|
| **opencode** | `commands/*.md` (`/flow-feat-start`) | `agents/*.md` `mode:subagent`, `@name` | `opencode.json` | cron + `opencode run -p` |
| **Gemini CLI** | `commands/**/*.toml` (`/flow:feat:start`) | `.gemini/agents/*.md`, `@name` | `settings.json` `mcpServers` | cron + `gemini -p` |
| **Codex CLI** | `prompts/*.md` (`/flow-feat-start`) | `[agents.*]` in `config.toml` | `[mcp_servers.*]` | cron + `codex exec` |

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
  - **`models` per subagent**: all three declare a subagent's model in the subagent's own definition,
    not at the call site → a `models` key is honoured by invoking a subagent declared with that model
    (each `PRIMITIVES.md` says where). And no harness lets a session switch its own model, so for the
    steps the conductor performs itself (`study`, and the code in `build`/`fix`) the configured value is
    reported at the phase handoff and the flow continues — same as on Claude Code.
  - **Autopilot for `/flow:work:watch`**: no in-session re-wakeup → replaced by **OS cron +
    headless execution**. The command runs ONE cycle and exits; state lives in `monitor.md`,
    which each cycle re-reads. It works, but the trigger is external, not the session itself.

## What is checked, and what is still on you

Every preflight runs [`../script/adapter-smoke.py`](../script/adapter-smoke.py) over these files:

- each mirror **parses in the shape its harness reads** — opencode a `description:` frontmatter,
  Codex no frontmatter at all, Gemini a TOML `description` + `prompt`
- every `/flow…` invocation in the body uses **this harness's prefix** (`/flow-feat-build` for
  opencode and Codex, `/flow:feat:build` for Gemini) — the mistake hand-condensing produces most, and
  the one that hands you a command your harness does not have
- every command and repo path it cites **exists**
- `install.sh` is executed against a **throwaway `HOME`** and the files are checked to land where that
  harness looks for them, in the expected number, changelog included

⚠️ **What none of that proves**: that the harness *runs* a workflow the way Claude Code does. These
have never been executed inside opencode, Gemini CLI or Codex end to end. Validate as you use them,
and adjust paths if your version differs — especially Codex, where the prompts location changes
between versions (see `codex/README.md`).

> Single source of truth for the logic: `../plugins/flow/commands/`. If you change a workflow there,
> update the affected mirrors — the preflight reads git and fails on a mirror older than its command.
> For a **new** command, `../script/adapter-new.py <command>` writes all three wrappers with the body
> marked for you to condense (`--from <file>` wraps a body you already condensed once).
