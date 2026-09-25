---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^new_files:.*src/'
flags: "im"
match: not_contains
---

The counter and the stop are already there; the change is one number in `config/settings.py`.
A new file under `src/` is the second counter the ticket's premise asked for — a new test is not
counted against it. This is what the `reframe` lens exists to catch: challenge what was asked
before building it.
