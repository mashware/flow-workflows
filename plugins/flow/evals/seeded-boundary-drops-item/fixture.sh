#!/usr/bin/env bash
# Seeded defect: the filter drops exactly the item it exists to carry. The shape is
# "The pack dropped the change it exists to carry, and said so after it" — a boundary
# written as strictly-after where the contract says at-or-after.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-103 "Select the steps a round still has to read" XS \
  "Added \`steps_since()\` to \`src/pipeline.py\`, used by the round to build its worklist."

cat >> src/pipeline.py <<'PY'


def steps_since(store, base_position):
    """The steps a round still has to read.

    `base_position` is the position of the last step a previous round cleared, and
    the step at that position is the first one this round has not seen: the worklist
    starts **at** it, not after it.
    """
    selected = []
    for position, (step_id, payload) in enumerate(store.steps()):
        if position > base_position:
            selected.append((step_id, payload))
    return selected
PY

fx_commit "DEMO-103 select the steps a round still has to read"
