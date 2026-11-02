---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^next:.*Mapeo de columnas'
flags: "im"
---

The next deliverable is the first pending row whose dependencies are met. "Mapeo de columnas"
depends only on "Lector CSV", which is done.
