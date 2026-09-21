---
type: regex
arm: with-only
target: trace
pattern: 'Review tier:[\s\S]{0,800}?Effective size:[\s\S]{0,800}?Review path:'
---

The three computed lines of `06-review.md` §8 — the tier, the effective size and the path the round
took. Read from the transcript rather than from the file, because an eval run is refused every write
under `.claude/`, so the artifact the phase composes never reaches disk. The transcript carries what
it wrote either way.

It is an indicator and never part of the score: a grader the baseline arm cannot pass would push
that arm to zero and inflate the delta the bench exists to read.
