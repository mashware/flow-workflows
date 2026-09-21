#!/usr/bin/env bash
# Shared fixture for every eval case: one small repository, one flow work parked at
# `build`, and the flow CLI installed locally so the review takes the CLI path rather
# than its prose fallback.
#
# A case sources this file, calls `fx_repo`, writes its own diff on the branch, and
# calls `fx_commit`. Nothing here is specific to a case, and nothing here names an
# ecosystem's tools: the fixture is a repository, and what a repository is built with
# is `FLOW.md`'s business, not the plugin's.
set -euo pipefail

FX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FX_REPO_ROOT="$(cd "$FX_LIB_DIR/../../../.." && pwd)"   # evals/_lib → evals → flow → plugins → root

# The CLI the review calls as `npx flow-workflows@<version>`. Installed from this
# checkout, at this checkout's version, so the call resolves offline inside the run's
# sandbox and `tier`/`bundle` answer for the code under test — not for whatever the
# registry calls newest.
fx_install_cli() {
  npm install --silent --no-audit --no-fund --no-package-lock "$FX_REPO_ROOT" >/dev/null 2>&1 \
    || echo "fixture: CLI not installed — the review will take its documented fallback" >&2
}

fx_git_init() {
  git init -q -b main .
  git config user.email "eval@example.invalid"
  git config user.name "flow eval"
  git config commit.gpgsign false
}

# The base tree every case starts from: a small order pipeline, a billing module that
# `sensitive_paths` points at, and a store. Small on purpose — the bench measures which
# findings a review reaches, and a large fixture measures how far it got instead.
fx_base_app() {
  mkdir -p src/billing tests
  cat > src/store.py <<'PY'
"""In-memory store for a run's steps and their recorded state."""


class Store:
    def __init__(self):
        self._steps = {}
        self._state = {}

    def add_step(self, step_id, payload):
        self._steps[step_id] = payload

    def steps(self):
        return list(self._steps.items())

    def head(self):
        """The id of the last step added, or '' when there is none."""
        if not self._steps:
            return ""
        return list(self._steps)[-1]

    def record(self, key, value):
        self._state[key] = value

    def recorded(self, key):
        return self._state.get(key, "")
PY
  cat > src/pipeline.py <<'PY'
"""Runs a list of steps and reports what each one produced."""

from src.store import Store


def run_steps(steps, store=None):
    store = store or Store()
    for step_id, payload in steps:
        store.add_step(step_id, payload)
    return store


def summarise(store):
    return [f"{step_id}: {payload}" for step_id, payload in store.steps()]
PY
  cat > src/billing/charge.py <<'PY'
"""Charges an order. Every path through here touches money."""

import logging

log = logging.getLogger(__name__)

MINIMUM_CENTS = 50


def charge(order, gateway):
    if order["amount_cents"] < MINIMUM_CENTS:
        raise ValueError("amount below the minimum")
    log.debug("charging order %s", order["id"])
    return gateway.charge(order["id"], order["amount_cents"])
PY
  cat > tests/test_pipeline.py <<'PY'
import unittest

from src.pipeline import run_steps, summarise


class PipelineTest(unittest.TestCase):
    def test_summarises_every_step(self):
        store = run_steps([("a", 1), ("b", 2)])
        self.assertEqual(summarise(store), ["a: 1", "b: 2"])


if __name__ == "__main__":
    unittest.main()
PY
  cat > Makefile <<'MK'
test:
	python3 -m unittest discover -s tests -t .
MK
}

# `FLOW.md` for the fixture. Quality commands are left empty on purpose: this bench
# scores which findings a review reaches, and a gate that shells out adds a failure mode
# that is not the review's. `sensitive_paths` points at the billing module, which is
# what the observability case needs to be about something.
fx_flow_config() {
  cat > FLOW.md <<'MD'
# FLOW configuration

## tracker
- prefix: DEMO-
- tool: none

## git
- host: github
- default_base: main
- squash: true

## autonomy
- mode: manual

## quality
- test:
- static_analysis:
- style_fix:
- review_depth: proportional
- sensitive_paths:
  - src/billing/**
- review_skill:
- reviewers:

## agents
- fanout_max: 2
- budget_max: 6

## models
- agents:
- workers:
MD
}

# The work folder a review reads in its pre-flight: parked at `build`, with `build` in
# `phases_done`, the design's contracts and the implementation log the phase opens in full.
# $1 ticket · $2 title · $3 size · $4 what the implementation says it did
fx_work() {
  local ticket="$1" title="$2" size="$3" implemented="$4"
  mkdir -p ".claude/work/$ticket"
  cat > ".claude/work/$ticket/meta.json" <<JSON
{
  "ticket": "$ticket",
  "type": "feat",
  "title": "$title",
  "branch": "$ticket-change",
  "size": "$size",
  "phase": "build",
  "phases_done": ["context", "design", "plan", "build"],
  "candidate_sha": "",
  "reviewed_sha": "",
  "fixed_sha": "",
  "validated_sha": "",
  "respond_rounds": 0,
  "review_findings": [],
  "mrs": [],
  "related_repos": [],
  "followups": [],
  "defaults_used": [],
  "conventions_candidates": [],
  "started_at": "2026-01-05T09:00:00Z",
  "updated_at": "2026-01-05T11:00:00Z",
  "notes": ""
}
JSON
  cat > ".claude/work/$ticket/00-summary.md" <<MD
# $ticket — $title

- What: $title.
- Size: $size · single MR.
- Decision: the change stays inside \`src/\`; no schema and no new dependency.
- Contracts: none declared, none received.
- Pending: review.
- Next phase opens in full: \`03-design.md\` contracts, \`05-implementation.md\`.
MD
  cat > ".claude/work/$ticket/03-design.md" <<MD
# Design $ticket

## Approach
$title.

## External contracts
None. Nothing outside this repository calls the code this work touches.

## Risks
The change is small and local; the risk is that it is wrong in a way the tests do not cover.
MD
  cat > ".claude/work/$ticket/05-implementation.md" <<MD
# Implementation $ticket

## What was built
$implemented

## Steps
- 1 — $implemented — (uncommitted)

## Premises the change depends on
| Premise | Verdict |
|---|---|
| The store keeps steps in insertion order | settled — \`src/store.py\` |
MD
}

fx_commit() {
  git add -A
  git commit -q -m "$1"
}

# Everything a case shares, in the order a case needs it.
# $1 ticket · $2 title · $3 size · $4 what the implementation log says
fx_repo() {
  fx_git_init
  fx_base_app
  fx_flow_config
  fx_commit "base"
  git checkout -q -b "$1-change"
  fx_work "$1" "$2" "$3" "$4"
  fx_install_cli
}
