# AGENTS.md — repo guide for Codex

Codex reads this file as a project guide. It points to the key resources for understanding the conventions and workflows.

## Workflow guide

Read `FLOW.md` at the repo root before doing anything. It contains:

- **tracker**: how to read tickets (tool, command, prefix).
- **git**: branch conventions, MR/PR, squash, assignee, base branch.
- **quality**: style commands, static analysis, tests, DB schema update.
- **conventions**: code skills or coding standards that apply to this project.
- **agents**: subagent role map (architecture, persistence, api, testing, security, performance, queues, frontend, frontend_test).
- **review**: the project's code review skill.
- **domain_memory**: if enabled, use the `domain-memory` MCP at the steps indicated.
- **observability**: service profile, queries, and thresholds for post-deployment monitoring.

If `FLOW.md` doesn't exist, each workflow command auto-discovers values or uses default behavior.

## Available workflows

Workflows are invoked as custom prompts with the `/` prefix:

| Command | Description |
|---------|-------------|
| `/flow-feat-start {TICKET}` | Start a new feature |
| `/flow-feat-brainstorm` | Generate options and risks before designing |
| `/flow-feat-design` | Technical design (no code) |
| `/flow-feat-plan` | Split work into independent MRs/PRs (M/L) |
| `/flow-feat-build` | Implement the feature |
| `/flow-feat-review` | Mandatory multi-agent code review |
| `/flow-feat-validate` | Validate tests, edge cases, and integrity |
| `/flow-feat-ship` | Commit, push, MR/PR, and offer to save knowledge |
| `/flow-bug-start {TICKET}` | Start a bug |
| `/flow-bug-diagnose` | Reproduce the failure and delimit what is broken |
| `/flow-bug-investigate` | Find the root cause |
| `/flow-bug-fix` | Apply the minimal fix |
| `/flow-bug-validate` | Regression test and verification |
| `/flow-bug-review` | Code review of the fix |
| `/flow-bug-postmortem` | Lessons learned (M/L) |
| `/flow-bug-ship` | Commit, push, MR/PR of the fix |
| `/flow-work-status` | Overview of all open work |
| `/flow-work-resume` | Resume work on the current branch |
| `/flow-work-try {BRANCH}` | Point the main checkout at a branch to test it (`--back` to return), re-syncing per FLOW.md |
| `/flow-work-watch {TICKET} [duration]` | Post-deployment monitoring (one cycle) |
| `/flow-work-abandon` | Close a work without shipping |
| `/flow-init` | Generate this repo's FLOW.md (auto-detects, asks the minimum) |
| `/flow-config` | Show this repo's effective FLOW.md config and validate it (read-only) |
| `/flow-save-knowledge` | Consolidate findings to the domain-memory store |

## Artifact structure

Each work item lives in `.claude/work/{TICKET}/`:

```
meta.json              — work state (phase, size, branch)
01-context.md          — ticket context
02-brainstorm.md       — options considered (feat)
02-diagnose.md         — failure diagnosis (bug)
03-design.md           — technical design
03-investigation.md    — root cause investigation (bug)
04-mr-plan.md          — delivery plan (M/L)
04-fix.md              — fix (bug)
05-implementation.md   — implementation log
05-validation.md       — fix validation (bug)
06-review.md           — code review results
07-validation.md       — feature validation
99-postmortem.md       — postmortem (bug M/L)
99-abandoned.md        — reason for abandonment
monitor.md             — post-deployment monitoring state
```

## Subagent configuration

The subagents used by the workflows are configured in `~/.codex/config.toml` under `[agents.<name>]`. The agent names are defined by the user in the `agents` map of `FLOW.md`. See `config.snippet.toml` in this directory for the format and commented examples.
