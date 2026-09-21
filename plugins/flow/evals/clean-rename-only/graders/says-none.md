---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^\s*none\b'
flags: "im"
---

The verdict says so in the word the prompt asked for. A review that finds nothing and reports
nothing at all is indistinguishable from one that never ran.
