---
type: regex
target:
  source: file
  path: verdict.md
pattern: 'src/pipeline\.py:(1[7-9]|2[0-5])'
---

The seeded defect, at the line it was seeded at (the window is the function it lives in, so a
review that names the call rather than the statement still counts). This is the bench's recall:
the one grader whose verdict says the review found what was put there for it to find.
