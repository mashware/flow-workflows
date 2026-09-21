---
type: regex
target:
  source: file
  path: verdict.md
pattern: '\S+\.py:\d+'
match: not_contains
---

There is no defect in this diff, so any `file:line` written into the verdict is a false positive.
Without this half of the bench the score rewards the noisiest review, and a review nobody reads
costs more than one that misses a finding.
