---
max_turns: 80
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Bash, Write, Edit, Skill, Agent, TodoWrite]
---

/flow:feat:design

Design the technical solution for the work on this branch before any code is written. The work is `DEMO-201`, its folder is `.claude/work/DEMO-201/`, and the ticket is in its `01-context.md`. Stop when the design is done: do not plan, build or run any later phase.

When the design is finished, write `verdict.md` at the root of the repository with exactly these four lines and nothing else:

chosen: <the approach the design settled on, in one sentence>
new_files: <comma-separated paths the implementation will create, or the word none>
reuses: <comma-separated existing `path` or `path:symbol` the implementation builds on, or the word none>
risks: <the production risks the design handles, separated by `;`, or the word none>
