---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^risks:.*(timeout|outage|unavailab|latenc|slow|down)'
flags: "im"
---

The provider's latency and outages are the production risk this change introduces: they are in
`docs/providers.md` in numbers, and the client that calls it has no timeout. A design that does
not name them puts every checkout behind the provider's worst hour without saying so.
