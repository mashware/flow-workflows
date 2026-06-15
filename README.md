# flow-workflows

Guided development workflows for terminal coding agents: `feat` (idea → design → build → review →
ship) and `bug` (diagnose → root cause → fix → validate → ship → postmortem), plus post-deploy
monitoring and multi-agent code review. **Stack-agnostic**: each repo is configured with a
`FLOW.md` at its root.

Ships a plugin for **Claude Code** and adapters for **opencode**, **Gemini CLI** and **Codex CLI**.

## Claude Code

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Namespaced commands: `/flow:feat:start`, `/flow:bug:diagnose`, `/flow:work:watch`, … To configure
the repo, run **`/flow:init`** (autodetects git host, test commands, etc. and writes `FLOW.md` for
you) — or copy `plugins/flow/examples/FLOW.template.md` by hand.

Try without installing: `claude --plugin-dir <path>/flow-workflows/plugins/flow`.

## Other harnesses (opencode, Gemini CLI, Codex CLI)

```bash
adapters/install.sh opencode      # or: gemini | codex
```
Copies the commands into each tool's location and tells you which config snippet (MCP,
subagents) to merge. See `adapters/README.md`. Same content and logic; only the wrapper format
changes, and where a tool lacks a primitive it degrades gracefully (see each adapter's
`PRIMITIVES.md`).

## Configuration: `FLOW.md`

A file at the repo root describes your conventions: issue tracker, git host and CLI, quality
commands (test/lint/static-analysis/DB), role→agent map, code-review panel, whether you use the
[`domain-memory`](https://github.com/mashware/domain-memory) MCP, and the observability profile
for post-deploy monitoring. **Anything left empty is autodetected or asked for** — a repo with no
`FLOW.md` still works, just with more questions. Template at
`plugins/flow/examples/FLOW.template.md`.

## Structure

```
flow-workflows/
├── .claude-plugin/marketplace.json     # catalog (Claude Code)
├── plugins/flow/                       # Claude Code plugin
│   ├── commands/  (feat/ bug/ work/ + init + save-knowledge)
│   ├── hooks/     (guard against pushing to the main branch)
│   └── examples/FLOW.template.md
└── adapters/
    ├── install.sh
    ├── opencode/  ·  gemini/  ·  codex/
```

## What it does not ship (on purpose)

To stay agnostic, `flow` **does not bundle concrete agents or a review skill** (those are
language/project specific): you name them in your `FLOW.md` and they must exist on your machine.
It does ship the anti-push-to-`master`/`main` hook, which is generic git. Optional dependencies
that improve the flow when present: the `domain-memory` MCP, your git host CLI, and an issue
tracker CLI. Without them, those specific steps degrade; the rest works.

## Note

The opencode/Gemini/Codex adapters are generated faithfully to each tool's documented format
**but not yet tested inside the tool**. They are a solid first cut; validate them as you use them
and adjust paths if your harness version differs (especially Codex, where the prompts location
changes between versions — see `adapters/codex/README.md`).

## License

MIT.
