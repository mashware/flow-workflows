---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^risks:.*(idempot|double.?charg|charged? twice|duplicate charge)'
flags: "im"
---

A timed-out charge may have gone through, so a blind retry can charge twice. The gateway's
`idempotency_key` is there for that, and a design that retries money has to name it. This is the
production risk the `operations` lens and the challenger exist to surface.
