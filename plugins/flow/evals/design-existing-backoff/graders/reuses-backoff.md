---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^reuses:.*(src/net/backoff\.py|call_with_backoff)'
flags: "im"
---

The design builds on the retry helper the repository already has, one module over from billing.
This is what the prior inventory and the `reuse` lens exist to reach.
