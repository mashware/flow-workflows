#!/usr/bin/env bash
# Clean diff: a test for behaviour that already existed, and the docstring that says so.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_repo DEMO-203 "Cover the minimum-charge rule" XS \
  "Added a test for the minimum-charge rule and documented it on \`charge()\`. No production behaviour changed."

cat > src/billing/charge.py <<'PY'
"""Charges an order. Every path through here touches money."""

import logging

log = logging.getLogger(__name__)

MINIMUM_CENTS = 50


def charge(order, gateway):
    """Charge an order through the gateway.

    An order below `MINIMUM_CENTS` never reaches the gateway: it raises instead, so a
    charge too small to be worth its fee is refused here rather than downstream.
    """
    if order["amount_cents"] < MINIMUM_CENTS:
        raise ValueError("amount below the minimum")
    log.debug("charging order %s", order["id"])
    return gateway.charge(order["id"], order["amount_cents"])
PY

cat > tests/test_charge.py <<'PY'
import unittest

from src.billing.charge import MINIMUM_CENTS, charge


class Gateway:
    def __init__(self):
        self.calls = []

    def charge(self, order_id, amount_cents):
        self.calls.append((order_id, amount_cents))
        return "ok"


class ChargeTest(unittest.TestCase):
    def test_refuses_an_amount_below_the_minimum(self):
        gateway = Gateway()
        with self.assertRaises(ValueError):
            charge({"id": "o1", "amount_cents": MINIMUM_CENTS - 1}, gateway)
        self.assertEqual(gateway.calls, [])

    def test_charges_at_the_minimum(self):
        gateway = Gateway()
        self.assertEqual(charge({"id": "o2", "amount_cents": MINIMUM_CENTS}, gateway), "ok")


if __name__ == "__main__":
    unittest.main()
PY

fx_commit "DEMO-203 cover the minimum-charge rule"
