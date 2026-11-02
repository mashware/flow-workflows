---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Write, Edit, Skill, Agent, TodoWrite]
---

/flow:next

Say where this project's plan stands: which deliverable should be started next, and whether any row of the plan is out of date with the work already merged. Do not start, edit or ship anything; stop once you have said it.

Then write `verdict.md` at the root of the repository with exactly these two lines and nothing else. This run may refuse writes under `.claude/`; that does not reach `verdict.md`, which is the deliverable — write it even if every other write was refused.

next: <the deliverable to start next, as the plan names it, or the word none>
stale: <the deliverables whose state in the plan is out of date, separated by `;`, or the word none>
