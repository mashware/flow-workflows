#!/usr/bin/env bash
# Clean diff, on the surface `quality.sensitive_paths` points at. What the diff moves is
# a log level and a message — observability alone, which §2.0 says does not raise the
# effort and which nothing here makes a must-fix finding.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-202 "Log a charge at info, with the amount" XS \
  "Raised the charge log line from debug to info and added the amount to the message. No control flow and no value that reaches the gateway was touched."

cat > src/billing/charge.py <<'PY'
"""Charges an order. Every path through here touches money."""

import logging

log = logging.getLogger(__name__)

MINIMUM_CENTS = 50


def charge(order, gateway):
    if order["amount_cents"] < MINIMUM_CENTS:
        raise ValueError("amount below the minimum")
    log.info("charging order %s for %s cents", order["id"], order["amount_cents"])
    return gateway.charge(order["id"], order["amount_cents"])
PY

fx_commit "DEMO-202 log a charge at info, with the amount"
