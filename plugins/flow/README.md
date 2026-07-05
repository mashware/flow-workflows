# flow — guided development workflows (stack-agnostic)

`feat`/`bug`/`work` flows with a shared skeleton (`start → … → ship`,
`diagnose → … → postmortem`, post-deploy monitoring) and consistent patterns (loop-until-done in
review, quarantine of untrusted input, adversarial verification, human gate before MR/PR),
**with nothing tied to a specific repo**. Each repository is configured with a `FLOW.md`.

## Configuration: `FLOW.md`

The easiest path: run **`/flow:init`**, which auto-detects what it can from the repo (git host,
base branch, test commands, whether migrations exist, whether `domain-memory` is active) and
writes `FLOW.md` asking you only for what cannot be inferred. Manual path: copy
`examples/FLOW.template.md` to the repo root. Commands read it in their step 0. It covers:

- **tracker**: ticket prefix and how to read a ticket.
- **git**: host and CLI (GitHub, GitLab, Bitbucket, Azure, Gitea, self-hosted…), term (MR/PR), default base, branch pattern, assignee, squash, description sections, pre-deploy gate, train chaining (multi-PR stacked branches).
- **quality**: test/analysis/style/DB commands for the repo (empty = auto-discover).
- **agents** / **review**: role→agent map and code-review panel.
- **conventions**: code conventions the commands must respect (free text).
- **domain_memory**: whether the [`domain-memory`](https://github.com/mashware/domain-memory) MCP is active.
- **observability**: profile for `work:watch` (services, platform, deploy detection, queues). Empty = auto-discover.

**Empty or absent keys degrade gracefully**: each command states what it does when a value is
missing (auto-discover, use default, or ask you). A repo without `FLOW.md` still works, just
with more questions and auto-discovery.

## Install

```
/plugin marketplace add mashware/flow-workflows
/plugin install flow@flow-plugins
```
Namespaced commands: `/flow:init`, `/flow:feat:start`, `/flow:bug:diagnose`, `/flow:work:watch`, etc.
They coexist with any other plugin or local command.

Try without installing: `claude --plugin-dir <path>/flow-workflows/plugins/flow`.

## What it intentionally does NOT include

To stay stack-agnostic, `flow` **does not bundle agents or the review skill** (those are
language/project-specific). Review invokes the skill/agents you declare in `FLOW.md`
(`review.*`, `agents.*`), or the built-in `code-review` if you define none. Reinforcement
agents (performance, queues, frontend…) are used only if your project has them; commands
reference them by role, not by name.

It does include the anti-push-to-`master`/`main` hook (`hooks/`) — that's generic git.

## Other harnesses

For opencode, Gemini CLI, or Codex CLI, see `../../adapters/`.
