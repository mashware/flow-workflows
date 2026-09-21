#!/usr/bin/env bash
# Seeded defect: the round records the state it ended on, not the state it read.
# The shape is the one v0.66.0 fixed in `review` itself — `reviewed_sha` was taken after
# the round applied its own fixes, so it named code no reviewer had seen.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-101 "Close a round and record what it reviewed" XS \
  "Added \`close_round()\` to \`src/pipeline.py\`: it applies the round's fixes and records the step the reviewers read."

cat >> src/pipeline.py <<'PY'


def close_round(store, fixes):
    """Apply this round's fixes and record what the round reviewed.

    `recorded("reviewed")` must name the head as it stood **before** this round
    changed anything: the step the reviewers actually read. The fixes are a delta
    on top of it, recorded separately by the caller.
    """
    for step_id, payload in fixes:
        store.add_step(step_id, payload)
    store.record("reviewed", store.head())
    return store
PY

fx_commit "DEMO-101 record what a round reviewed"
