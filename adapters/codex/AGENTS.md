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

Workflows are installed as Codex **skills** and invoked with the `$` prefix. Codex does not
read Claude Code's `commands/` — a skill is what it discovers, in `~/.codex/skills/` (global)
or `.agents/skills/` (this repo).

| Skill | Description |
|---|---|
| `$flow-feat-start [TICKET]` | Start a new feature (read the tracker, classify size, create branch and initial artifact) |
| `$flow-feat-design` | Design the technical solution (architecture, DB, APIs, risks) before touching code |
| `$flow-feat-plan` | Split the work into small, independently mergeable MRs/PRs before implementing |
| `$flow-feat-build` | Implement the feature following the approved design and keep a running log |
| `$flow-feat-review` | Mandatory multi-agent code review before shipping |
| `$flow-feat-validate` | Validate tests, edge cases, and integrity before shipping |
| `$flow-feat-ship` | Commit, push, MR/PR, and offer to save domain knowledge |
| `$flow-bug-start [TICKET]` | Start the bug flow (tracker, knowledge, size, branch, initial artifact) |
| `$flow-bug-investigate` | Find the root cause of the bug (not just the symptom) |
| `$flow-bug-fix` | Implement the minimal fix and keep a log |
| `$flow-bug-validate` | Regression test and verification that the bug does not return |
| `$flow-bug-review` | Multi-agent code review of the fix before submitting |
| `$flow-bug-postmortem` | Lessons learned, areas to watch, and offer to save to the knowledge store |
| `$flow-bug-ship` | Commit, push, MR/PR the fix |
| `$flow-next` | Entry point — routes to init, resume or status depending on where you are (no FLOW.md → init; a work on this branch → resume; otherwise status) |
| `$flow-init` | Assistant that generates the FLOW.md for this repo (auto-detects what it can, asks the minimum) |
| `$flow-doctor` | What this repo's FLOW.md actually says, and whether the environment it assumes exists — CLIs, auth, agents, hooks, MCP, repo state |
| `$flow-news [vX.Y.Z \| N \| all] [full]` | Show what changed in the flow plugin since the version you last saw |
| `$flow-work-daily [question]` | Your work assistant — a Scrum-style daily standup across all your work (local + forge + tracker) |
| `$flow-work-status` | Summary of all open works in .claude/work/ |
| `$flow-work-resume` | Resume the work associated with the current branch and suggest the next step |
| `$flow-work-respond [mr-iid-or-url]` | Respond to review threads on an open MR/PR — triage, debate, implement the agreed changes, reply (never resolve) |
| `$flow-work-green [mr-iid-or-url]` | Get an open MR/PR that cannot merge back to mergeable — red pipeline, conflicts or any other blocker: triage, fix at the root, push (never green-wash) |
| `$flow-work-query [file | pasted query | reviewer objection]` | Put a data-access query on trial — schema, indexes, execution plan and measured numbers decide it, never prose |
| `$flow-work-try <branch> \| --back` | Point the main checkout at a branch to test it (then return), re-syncing per FLOW.md |
| `$flow-work-clean [--dry-run]` | Sweep what finished work left behind — merged worktrees, dead branches, unarchived work folders |
| `$flow-work-watch [TICKET]` | Monitor the observability platform after a deploy and alert on errors or performance regressions (autopiloted) |
| `$flow-work-abandon` | Close a work without shipping (discarded feature, non-issue, etc.) |
| `$flow-work-README` | Guide to the /feat and /bug workflow system |

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
