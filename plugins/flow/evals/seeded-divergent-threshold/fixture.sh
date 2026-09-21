#!/usr/bin/env bash
# Seeded defect: a threshold that is code in one module and a repeated literal in
# another, and the two no longer agree. The shape is "The budget is code and the tier is
# still prose, and only one of the two can be checked".
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-105 "Label a round by its size" S \
  "Added \`src/tier.py\` with the size thresholds, and a \`label_round()\` in \`src/pipeline.py\` that reports the label."

cat > src/tier.py <<'PY'
"""The one place the size thresholds are written down."""

SMALL_MAX = 150
MEDIUM_MAX = 600
LARGE_MIN = 1500


def size_of(changed_lines):
    if changed_lines <= SMALL_MAX:
        return "XS"
    if changed_lines <= MEDIUM_MAX:
        return "S"
    if changed_lines < LARGE_MIN:
        return "M"
    return "L"
PY

cat >> src/pipeline.py <<'PY'


def label_round(changed_lines):
    """The label shown on the round's report.

    The thresholds live in `src/tier.py`; this only formats what that module resolves.
    """
    if changed_lines > 1000:
        return "L — a large round"
    if changed_lines > 600:
        return "M — a medium round"
    return "S — a small round"
PY

fx_commit "DEMO-105 label a round by its size"
