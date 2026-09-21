---
type: regex
arm: with-only
target: trace
pattern: '(observability|log level|logging)'
flags: "i"
---

§2.0 asks the round to say, in one line, whether a diff on a `sensitive_paths` surface changed
control flow or moved observability alone — and this diff moves a log level and nothing else. An
indicator, not part of the score: the judgement is the one thing §2.0 says the CLI cannot make, so
what is checked here is that the round made it out loud.
