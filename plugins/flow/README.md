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
- **agents**: role→agent map for the steps that delegate to a specialist, plus the two cost ceilings — `fanout_max` per parallel round (empty → 4) and `budget_max` per command run (empty → 12) — and the fan-out's optional orchestrator (`fanout_tool`).
- **models**: which model the subagents run with — `agents` (every one a command improvises) and `workers` (the fan-out rounds). Free text, passed straight to your harness; empty = everything runs with the model you launched the command with. There is no key for what the main agent does itself: it cannot switch its own model.
- **data**: how to get a query's execution plan and a table's real schema, plus the volumes of the hot tables — what the query duel needs to judge a query on its plan instead of on an argument. Empty = the duel runs on the schema alone and says what it could not prove.
- **conventions**: code conventions the commands must respect (free text).
- **notes**: per-command extra guidance, followed as mandatory additional instructions for that step.
- **knowledge**: the knowledge sources by role — `search`, `stage`, `read_staging`, `save` — any MCP ([`domain-memory`](https://github.com/mashware/domain-memory), `codegraph`…), CLI or skill; empty roles degrade silently.
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
- `hooks/` — the push guard, the update notice, and the work notice that says where you left off.
- `examples/FLOW.template.md` — every key with its default; `/flow:init` writes only the keys you set.
- `examples/symfony/` — one worked stack: a filled-in `FLOW.md` and the four review agents a Symfony + Doctrine repo wants. An example, never loaded; copy and edit.

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
`models` is yours to fill or leave empty. What it does ship is one **example** of both, under
`examples/symfony/`, which nothing loads and which exists so a fresh install has something concrete
to copy.

It does ship three hooks (`hooks/`), all generic: a guard that refuses a `git push` aimed at
`master`/`main`; a session-start notice when the plugin has been updated since you last looked
(what `/flow:news` then explains); and a second session-start hook that, when the branch you
opened on has a work behind it, prints its phase and what the last session was doing. All three
are silent when they have nothing to say — including in a repo that does not use flow.

## Other harnesses

For opencode, Gemini CLI, or Codex CLI, see `../../adapters/`.
