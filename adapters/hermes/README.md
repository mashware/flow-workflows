# `flow` workflow adapter for Hermes Agent

Brings the `feat`, `bug` and `work` workflows from the `flow` plugin to **Hermes Agent**
(Nous Research) format: one **skill** per command, invoked as `/flow-feat-start`, `/flow-bug-fix`,
`/flow-work-status`.

## Adapter contents

```
adapters/hermes/
├── skills/               — one skill folder per plugin command, generated (see ../README.md)
├── CORE.md               — the shared flow-core rules every skill reads once per session (generated)
├── config.snippet.yaml   — keys to merge into ~/.hermes/config.yaml (MCP, delegation, cron)
├── PRIMITIVES.md         — primitive translation table, the long form of each skill's legend
└── README.md             — this file
```

`skills/*/SKILL.md` and `CORE.md` are written by `script/adapter-build.py` from the plugin — do not
edit them by hand. Skill names follow the plugin's paths with `:` flattened to `-`
(`feat/start.md` → `/flow-feat-start`); `ls skills/` is the current list.

Hermes reads the [agentskills.io](https://agentskills.io) layout — a folder with a `SKILL.md` keyed
by `name:` — which is the same shape the Codex adapter emits. What differs is where they are read
from (`~/.hermes/skills/`) and how they are invoked: a slash, not a `$`.

## Installation

The shared script does the skills and the `~/.claude/flow/` copies (`CORE.hermes.md`, the changelog,
the manifest) in one go:

```bash
../install.sh hermes            # ~/.hermes/skills — every repo
../install.sh hermes project    # .hermes/skills — this repo only
```

By hand:

### 1. Skills

```bash
cp -r skills/. ~/.hermes/skills/
mkdir -p ~/.claude/flow && cp CORE.md ~/.claude/flow/CORE.hermes.md
```

`~/.hermes/skills/` is one flat namespace shared with every bundled and hub skill, which is why
these keep their `flow-` prefix. A project-scoped install (`<repo>/.hermes/skills/` or
`<repo>/.agents/skills/`) is trusted per repo — the first session in that repo shows a banner and
`hermes skills trust` enables them.

There is a third way, if you would rather not copy anything: point Hermes at this checkout with
`skills.external_dirs` in `config.yaml` (commented example in `config.snippet.yaml`), and `git pull`
becomes the whole upgrade.

### 2. MCP, delegation and cron

Merge what you need from `config.snippet.yaml` into `~/.hermes/config.yaml`:

```bash
cat config.snippet.yaml
```

- **MCP** — only if the `knowledge` section of FLOW.md names MCP tools. `hermes mcp install` is the
  safer route than editing the block by hand; Hermes reloads `mcp_servers` without a restart.
- **Delegation** — `delegation.max_concurrent_children` is the real ceiling over the fan-out;
  `delegation.model` is the one model every subagent of a round runs on.
- **Cron** — what `/flow-work-watch` repeats with. See `PRIMITIVES.md`.

Nothing to declare per subagent: `delegate_task` builds each child from the prompt, so the roles in
the `agents` map of FLOW.md are described in the delegation, not installed anywhere.

### 3. FLOW configuration in the repo

Use `FLOW.md` for shared repo configuration and an optional `FLOW.hermes.md` for model, agent,
skill, orchestration, or MCP names that differ from the other harnesses. Hermes reads the base and
then its overlay; an explicitly empty overlay value masks the base. Existing base-only repos are
unchanged. Without either file, workflows run with default values and auto-discovery.

```bash
cp ../../plugins/flow/examples/FLOW.template.md FLOW.md
# Edit FLOW.md with your project's conventions
```

### 4. AGENTS.md in the repo (optional)

Hermes reads a project context file at session start, `AGENTS.md` among them (after `HERMES.md` /
`.hermes.md` and `AGENTS.override.md`, before `CLAUDE.md`). `../codex/AGENTS.md` is one you can copy
to your repo root:

```bash
cp ../codex/AGENTS.md /root/of/your/repo/AGENTS.md
```

## Quick start

```
# Start a feature
/flow-feat-start PROJ-12345

# Resume where you left off
/flow-work-resume

# Morning standup across all your work (local + forge + tracker)
/flow-work-daily

# See all open work
/flow-work-status

# Start a bug
/flow-bug-start PROJ-99999

# Watch after a deployment (one cycle; /cron repeats it)
/flow-work-watch PROJ-12345 30m
```

A running session picks up a newly installed skill only after `hermes skills` re-scans it — start a
new session if `/flow-…` does not autocomplete.

## Dependencies

- **Hermes Agent** installed and configured with a provider. Project: https://github.com/NousResearch/hermes-agent
- **domain-memory MCP** installed if you name its tools in the `knowledge` section of FLOW.md. Project: https://github.com/mashware/domain-memory
- **git CLI** configured (`glab`, `gh`, or other per `git.cli` in FLOW.md) to create MRs/PRs from the terminal.

## Differences from the original plugin (Claude Code)

Each skill opens with a legend mapping the Claude Code primitives to Hermes; `PRIMITIVES.md` has the
full table. The most important points:

- **AskUserQuestion**: no structured UI → questions become plain text.
- **ScheduleWakeup** (watch autopilot): Hermes schedules itself (`/cron add "every 30m" "…"`), so the
  repetition is native — but each firing is a **fresh session with no history**, which is why every
  cycle re-reads `monitor.md`. Retiring the job from inside a firing needs
  `cron.allow_agent_scheduling: true`.
- **Subagents**: `delegate_task` creates each child from the prompt — there is no agent to declare, and
  no per-task model (`delegation.model` covers the whole round).
- **Parallel fan-out**: ports directly, under the lower of `agents.fanout_max` (empty → 4) and
  `delegation.max_concurrent_children` (default 10).
- **Skill descriptions**: Hermes suggests keeping a skill's `description` short (~60 characters). These
  carry the plugin's own descriptions verbatim, and most are longer — they are what tells the agent
  when a command applies, and shortening them in the mirror would make the mirror lie about the plugin.

⚠️ Like the other three adapters, this one has **never been run end to end inside its harness**. The
generated files are checked for shape, prefix and paths by `script/adapter-smoke.py`, and the
installer is checked against a throwaway `HOME` — none of which proves Hermes runs a workflow the way
Claude Code does. Validate as you use it, and adjust paths if your version differs.
