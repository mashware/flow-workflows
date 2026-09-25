#!/usr/bin/env bash
# Design trap: the retry the ticket asks for already exists, one module over.
# The obvious design writes a retry loop inside billing; the right one calls the helper
# the webhook sender already relies on. And a timed-out charge is not a failed charge —
# the gateway accepts an idempotency key for exactly that reason.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_design_repo
mkdir -p src/net src/notify
cat > src/net/backoff.py <<'PY'
"""Retries a call that fails for a transient reason, waiting longer each time."""

import time


def call_with_backoff(fn, attempts=3, base_delay=0.2, retry_on=(TimeoutError,), sleep=time.sleep):
    """Call `fn()` until it succeeds or `attempts` run out.

    Only the exceptions in `retry_on` are retried; anything else propagates at once.
    The wait doubles after every failure: base_delay, 2x, 4x... The last failure is
    re-raised unchanged.
    """
    for attempt in range(attempts):
        try:
            return fn()
        except retry_on:
            if attempt == attempts - 1:
                raise
            sleep(base_delay * (2 ** attempt))
PY
cat > src/notify/webhook.py <<'PY'
"""Delivers an event to a customer's webhook endpoint."""

from src.net.backoff import call_with_backoff


def deliver(event, client):
    return call_with_backoff(lambda: client.post(event["url"], event["body"]), attempts=5)
PY
cat > src/billing/gateway.py <<'PY'
"""The payment gateway's client, as the rest of the code sees it."""


class GatewayTimeout(TimeoutError):
    """The gateway did not answer in time. The charge may or may not have been made."""


class Gateway:
    def __init__(self, http):
        self._http = http

    def charge(self, order_id, amount_cents, idempotency_key=None):
        """Charge an order.

        Two calls carrying the same `idempotency_key` charge at most once: the second
        returns the first call's result. Without a key every call is a new charge.
        """
        headers = {"Idempotency-Key": idempotency_key} if idempotency_key else {}
        return self._http.post("/charges", {"order": order_id, "amount": amount_cents}, headers)
PY
cat > tests/test_backoff.py <<'PY'
import unittest

from src.net.backoff import call_with_backoff


class BackoffTest(unittest.TestCase):
    def test_retries_a_timeout_then_succeeds(self):
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) == 1:
                raise TimeoutError()
            return "ok"

        self.assertEqual(call_with_backoff(flaky, sleep=lambda _: None), "ok")
        self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
PY

fx_design_work DEMO-201 "Retry the charge when the payment gateway times out" M <<'MD'
**DEMO-201 — Retry the charge when the payment gateway times out**

When the payment gateway does not answer in time, `charge()` in `src/billing/charge.py` raises
and the order is left unpaid; support re-runs those by hand every morning. Retry the charge a
few times before giving up.

Acceptance criteria:
- A gateway timeout on the first attempt and a success on the second leaves the order paid.
- A gateway that keeps timing out still fails the charge, after the retries.
MD
