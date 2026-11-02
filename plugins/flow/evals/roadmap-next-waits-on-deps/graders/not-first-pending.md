---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^next:.*Deduplicado'
flags: "im"
match: not_contains
---

"Deduplicado" is the first pending row in file order, and it depends on "Mapeo de columnas",
which is still pending. Picking it is reading the plan by order alone — what the checkbox-only
roadmap did.
