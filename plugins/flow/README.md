# flow — guided development workflows (stack-agnostic)

`feat`/`bug`/`work` flows with a shared skeleton (`start → … → ship`,
`diagnose → … → postmortem`, post-deploy monitoring) and consistent patterns (loop-until-done in
review, quarantine of untrusted input, adversarial verification, human gate before MR/PR),
**with nothing tied to a specific repo**. Each repository is configured with a `FLOW.md`.

## Configuration: `FLOW.md`

The easiest path: run **`/flow:init`**, which auto-detects what it can from the repo (git host,
base branch, test commands, whether migrations exist, which knowledge MCPs are exposed) and
writes `FLOW.md` asking you only for what cannot be inferred. Manual path: copy
`examples/FLOW.template.md` to the repo root. Commands read it in their step 0. It covers:

- **tracker**: ticket prefix, how to read a ticket (description **and** comment thread), and the optional start/done/abandon transitions.
- **git**: host and CLI (`github` or `gitlab`), term (MR/PR), default base, branch pattern, assignee, squash, description sections, pre-deploy gate, train chaining (multi-PR stacked branches), worktrees.
- **autonomy**: `manual` | `guided` | `auto` — how much the flow advances on its own. The hard gates (push/MR-PR, ambiguous branch base, DB schema changes, high-severity review findings, the business brief before code) stop in **every** mode.
- **quality**: test/analysis/style/DB commands for the repo (empty = auto-discover), plus `review_depth` (`proportional` · `full` · `light`), `review_skill` and `reviewers` — how much of the review panel runs and who is on it.
- **agents**: role→agent map for the steps that delegate to a specialist, plus the parallel fan-out ceiling (`fanout_max`) and its optional orchestrator (`fanout_tool`).
- **models**: which model each kind of step runs with (`study`, `code`, `test`, `review`, `workers`). Free text, passed straight to your harness; empty = the step runs with the model you launched the command with.
- **data**: how to get a query's execution plan and a table's real schema, plus the volumes of the hot tables — what the query duel needs to judge a query on its plan instead of on an argument. Empty = the duel runs on the schema alone and says what it could not prove.
- **conventions**: code conventions the commands must respect (free text).
- **notes**: per-command extra guidance, followed as mandatory additional instructions for that step.
- **knowledge**: the knowledge sources by role — `search`, `stage`, `read_staging`, `save` — any MCP ([`domain-memory`](https://github.com/mashware/domain-memory), `codegraph`…), CLI or skill; empty roles degrade silently. `domain_memory.enabled` is the legacy alias.
- **observability**: profile for `work:watch` (services, platform, deploy detection, queues). Empty = auto-discover.

`FLOW.md` is **personal config, not team config** — it mixes repo facts with your own preferences
and may point at agents another machine does not have — so `/flow:init` offers to git-ignore it.
Full reference: [`docs/CONFIGURATION.md`](https://github.com/mashware/flow-workflows/blob/main/docs/CONFIGURATION.md);
every key is also documented inline in `examples/FLOW.template.md`, which ships with the plugin.

**Empty or absent keys degrade gracefully**: each command states what it does when a value is
missing (auto-discover, use default, or ask you). A repo without `FLOW.md` still works, just
with more questions and auto-discovery.

## What ships

- `commands/` — one file per `/flow:*` command, each reduced to its contract. Start with `/flow:next`.
- `skills/flow-core/SKILL.md` — the rules every command shares (step 0 `FLOW.md`, models, autonomy and hard gates, how a stop reads, `panel.json`, `00-summary.md`), loaded once per session.
- `hooks/` — the push guard and the update notice.
- `examples/FLOW.template.md` — every key with its default; `/flow:init` writes only the keys you set.

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
(`quality.review_skill`, `quality.reviewers`, `agents.*`), or the built-in `code-review` if you
define none. Reinforcement agents (performance, queues, frontend…) are used only if your project
has them; commands reference them by role, not by name. It never picks a model for you either —
`models` is yours to fill or leave empty.

It does ship two hooks (`hooks/`), both generic: a guard that refuses a `git push` aimed at
`master`/`main`, and a session-start notice when the plugin has been updated since you last
looked (what `/flow:news` then explains).

## Other harnesses

For opencode, Gemini CLI, or Codex CLI, see `../../adapters/`.
