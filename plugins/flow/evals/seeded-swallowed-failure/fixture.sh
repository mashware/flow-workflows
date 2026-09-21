#!/usr/bin/env bash
# Seeded defect: a helper turns a failing external call into an empty result, and the
# caller reads empty as "clean". The shape is the one the CHANGELOG describes as "a full
# panel reporting a clean diff" — silence and success told apart nowhere.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-102 "Run the configured checker over a round" XS \
  "Added \`run_checks()\` to \`src/pipeline.py\` and wired \`report_round()\` to it."

cat >> src/pipeline.py <<'PY'


class CheckerError(RuntimeError):
    """The configured checker could not be run, or exited non-zero."""


def run_checks(command, runner):
    """Return the checker's findings, one per line.

    A checker that could not run has found nothing and proved nothing: the round
    must be able to tell that apart from a clean result.
    """
    try:
        return runner(command)
    except CheckerError:
        return []


def report_round(command, runner):
    findings = run_checks(command, runner)
    if not findings:
        return "checks clean"
    return f"{len(findings)} finding(s)"
PY

fx_commit "DEMO-102 run the configured checker over a round"
