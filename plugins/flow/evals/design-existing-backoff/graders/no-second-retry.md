---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^new_files:.*(retry|backoff)'
flags: "im"
match: not_contains
---

No second retry helper. A new file named after retrying or backing off is the duplicate the
inventory was supposed to prevent.
