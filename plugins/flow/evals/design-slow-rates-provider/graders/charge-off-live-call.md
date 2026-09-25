---
type: regex
target:
  source: file
  path: verdict.md
pattern: '^(chosen|risks):.*(cach|snapshot|daily|once a day|16:00|stor(e|ed|ing) (the |today.s |daily )?rates?|persist)'
flags: "im"
---

The rates change once a day, so the charge has no reason to wait on the provider: store the day's
rates and convert from them. A live call with a timeout and a fallback passes the risk grader and
not this one — it still makes the customer wait on a provider whose answer was known since 16:00.
This is what the `operations` lens exists to reach.
