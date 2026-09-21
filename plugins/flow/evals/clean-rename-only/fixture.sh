#!/usr/bin/env bash
# Clean diff: a rename and its call sites. Nothing here must be reported as must-fix —
# a blocker on this case is a false positive, and false positives are what make a review
# stop being read.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-201 "Rename summarise() to summarise_steps()" XS \
  "Renamed \`summarise()\` to \`summarise_steps()\` in \`src/pipeline.py\` and updated its only call site in the tests. No behaviour change."

cat > src/pipeline.py <<'PY'
"""Runs a list of steps and reports what each one produced."""

from src.store import Store


def run_steps(steps, store=None):
    store = store or Store()
    for step_id, payload in steps:
        store.add_step(step_id, payload)
    return store


def summarise_steps(store):
    return [f"{step_id}: {payload}" for step_id, payload in store.steps()]
PY

cat > tests/test_pipeline.py <<'PY'
import unittest

from src.pipeline import run_steps, summarise_steps


class PipelineTest(unittest.TestCase):
    def test_summarises_every_step(self):
        store = run_steps([("a", 1), ("b", 2)])
        self.assertEqual(summarise_steps(store), ["a: 1", "b: 2"])


if __name__ == "__main__":
    unittest.main()
PY

fx_commit "DEMO-201 rename summarise() to summarise_steps()"
