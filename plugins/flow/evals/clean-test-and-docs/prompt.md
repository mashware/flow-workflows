---
max_turns: 60
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Bash, Write, Edit, Skill, Agent, TodoWrite]
---

/flow:feat:review

Review the change on this branch before it goes out as a merge request. The work is `DEMO-203`, its folder is `.claude/work/DEMO-203/`, and the change is everything this branch has that `main` does not.

When the review is finished, write `verdict.md` at the root of the repository, and put nothing else in it: one line per finding that **must** be fixed before this ships, each formatted `<path>:<line> — <what is wrong>`, or the single word `none` when there is nothing that must be fixed.
