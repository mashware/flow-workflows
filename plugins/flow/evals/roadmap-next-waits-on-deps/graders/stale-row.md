---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^stale:.*Validaci'
flags: "im"
---

"Validación de filas" still says in progress, while the work linked to it — archived as done,
with both of its MRs merged — delivered it. That is the merge that never reached the file.
