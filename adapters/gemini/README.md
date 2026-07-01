# flow adapter for Gemini CLI

This adapter brings the 24 commands of the `flow` plugin (`/feat:*`, `/bug:*`, `/work:*`, `/flow:*`, `/save-knowledge`) to the **Gemini CLI** format.

The commands are a format adapter, not a reimplementation: the logic and prose are identical to the original plugin. What changes is the target file format and the translation of Claude Code-specific primitives. See `PRIMITIVES.md` for full details.

---

## Prerequisites

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed and authenticated.
- Node.js 18+ (for the `domain-memory` MCP server, if you use it).
- A `FLOW.md` file at the root of the repo you want to work on. Start from the template at:
  `../../plugins/flow/examples/FLOW.template.md`

---

## Installation

### 1. Copy the commands

**Global installation** (available in any repo):
```bash
cp -r commands/* ~/.gemini/commands/
```

**Local installation** (current repo only):
```bash
mkdir -p .gemini/commands
cp -r commands/* .gemini/commands/
```

Gemini CLI loads commands from both locations. Local commands take precedence over global ones.

After copying, the structure looks like this:
```
~/.gemini/commands/          (or .gemini/commands/ in the repo)
├── feat/
│   ├── start.toml          → /feat:start
│   ├── brainstorm.toml     → /feat:brainstorm
│   ├── design.toml         → /feat:design
│   ├── plan.toml           → /feat:plan
│   ├── build.toml          → /feat:build
│   ├── review.toml         → /feat:review
│   ├── validate.toml       → /feat:validate
│   └── ship.toml           → /feat:ship
├── bug/
│   ├── start.toml          → /bug:start
│   ├── diagnose.toml       → /bug:diagnose
│   ├── investigate.toml    → /bug:investigate
│   ├── fix.toml            → /bug:fix
│   ├── review.toml         → /bug:review
│   ├── validate.toml       → /bug:validate
│   ├── ship.toml           → /bug:ship
│   └── postmortem.toml     → /bug:postmortem
├── work/
│   ├── README.toml         → /work:README
│   ├── resume.toml         → /work:resume
│   ├── status.toml         → /work:status
│   ├── abandon.toml        → /work:abandon
│   ├── watch.toml          → /work:watch
│   └── try.toml            → /work:try
├── flow/
│   ├── init.toml           → /flow:init
│   └── config.toml         → /flow:config
└── save-knowledge.toml     → /save-knowledge
```

### 2. Configure the domain-memory MCP server

Merge the block from `settings.snippet.json` into your `~/.gemini/settings.json`:

```bash
# If settings.json does not exist yet:
cp settings.snippet.json ~/.gemini/settings.json

# If it already exists, manually merge the "mcpServers" block:
# Open ~/.gemini/settings.json and add inside "mcpServers":
#   "domain-memory": {
#     "command": "npx",
#     "args": ["-y", "@mashware/domain-memory@latest"],
#     "env": { "DOMAIN_MEMORY_DIR": ".domain-memory" }
#   }
```

If you do not want to use `domain-memory`, you can skip this step. The commands check `domain_memory.enabled` in `FLOW.md` and degrade silently if the MCP is not available.

### 3. Create FLOW.md in the repo

All commands read `FLOW.md` at the repo root in their step 0. Without it, each command uses default behavior or auto-discovers what it can.

Copy and fill in the template:
```bash
cp ../../plugins/flow/examples/FLOW.template.md ./FLOW.md
```

Key fields to fill in: `tracker`, `git.default_base`, `git.branch_pattern`, `git.request_term`, `git.cli`, `quality.*`, `conventions`, `agents.*`, `domain_memory.enabled`.

---

## Sub-agents (optional but recommended for M/L)

The commands delegate work to sub-agents using `@name`, where `name` comes from the `agents.<role>` map in FLOW.md. For parallel fan-out to work in `/feat:brainstorm`, `/bug:investigate`, and adversarial checks in reviews, declare the sub-agents in `.gemini/agents/`:

```
.gemini/agents/
├── architecture.md    # architecture design agent
├── persistence.md     # Doctrine / ORM / DB agent
├── api.md             # HTTP endpoint agent
├── testing.md         # testing agent
├── security.md        # security agent
├── performance.md     # performance / N+1 agent
└── review.md          # project code review agent
```

See `PRIMITIVES.md` for the exact frontmatter format for each file.

Without declared sub-agents, the commands run tasks sequentially in the same context. The result is functionally equivalent for small features (XS/S).

---

## Post-deploy monitoring (`/work:watch`)

`/work:watch` does not self-pilot in Gemini CLI (there is no `ScheduleWakeup` in session). The command runs one monitoring cycle and exits. To repeat it automatically:

```bash
# Example: watch TICKET every 5 minutes for 30 minutes
*/5 * * * * gemini -p "/work:watch TICKET 30m" >> ~/.gemini/watch-TICKET.log 2>&1
```

State between cycles (monitored surface, baseline, approved plan) is persisted in `.claude/work/TICKET/monitor.md`. Each cycle reads that file to avoid repeating the initial discovery.

---

## Quick start

```
# Start a feature
/feat:start PROJ-12345

# Full flow for an M feature
/feat:start PROJ-12345
/feat:brainstorm
/feat:design
/feat:plan
/feat:build
/feat:review
/feat:validate
/feat:ship

# S incident flow
/bug:start PROJ-99999
/bug:diagnose
/bug:fix
/bug:validate
/bug:review
/bug:ship

# Status of all open work
/work:status

# Resume work after a break
/work:resume
```

---

## More information

- `PRIMITIVES.md` — full translation table and what was trimmed.
- `../../plugins/flow/examples/FLOW.template.md` — FLOW.md template.
- `../../plugins/flow/commands/work/README.md` — complete guide to the flow system.
