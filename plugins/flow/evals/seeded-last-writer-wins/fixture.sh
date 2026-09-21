#!/usr/bin/env bash
# Seeded defect: several workers write one shared key, so every result but the last is
# lost. The shape is v0.66.0's "a round that contains a writer is not one round".
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-104 "Collect what a round of workers produced" XS \
  "Added \`collect_results()\` to \`src/pipeline.py\`: it runs each worker and keeps what each one returned."

cat >> src/pipeline.py <<'PY'


def collect_results(workers, store):
    """Run every worker and keep what each one produced.

    Each worker's result is kept under its own name, so the caller can read back
    every one of them after the round.
    """
    for worker in workers:
        store.record("result", worker())
    return store.recorded("result")
PY

fx_commit "DEMO-104 collect what a round of workers produced"
