#!/usr/bin/env bash
# Design trap: operations. The ticket reads as "call the rates client before charging",
# and the client is right there. But the provider publishes once a day, answers in 9 s at
# p99 and went down three times last quarter, and the client has no timeout — so the
# obvious design puts every charge behind the provider's worst hour. The evidence is in
# `docs/providers.md`, so a design that handles it is not defending against a hypothesis.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_design_repo
mkdir -p src/reports docs
cat > src/billing/rates_client.py <<'PY'
"""Reads exchange rates from the rates provider. Base currency: EUR."""

import json
import urllib.request

RATES_URL = "https://rates.example.invalid/v1/latest?base=EUR"


def fetch_rates():
    """Return {currency: rate} for one EUR, as the provider publishes them today."""
    with urllib.request.urlopen(RATES_URL) as resp:
        return json.load(resp)["rates"]
PY
cat > src/reports/revenue.py <<'PY'
"""Nightly revenue report. Everything is reported in EUR."""

from src.billing.rates_client import fetch_rates


def revenue_eur(payments):
    """Sum payments made in any currency, converted back to EUR cents."""
    rates = fetch_rates()
    total = 0
    for payment in payments:
        rate = 1.0 if payment["currency"] == "EUR" else rates[payment["currency"]]
        total += round(payment["amount_cents"] / rate)
    return total
PY
cat > docs/providers.md <<'MD'
# External providers

## Rates provider (`src/billing/rates_client.py`)

- Publishes one set of rates per day, at 16:00 CET. Rates do not change between publications.
- Latency, last 90 days: p50 120 ms, p99 9 s.
- Three outages last quarter, the longest 47 minutes (see the provider's status page).
- Today only the nightly revenue report calls it, once per night.

## Payment gateway (`src/billing/charge.py`)

- Every order is charged synchronously at checkout, while the customer waits.
MD

fx_design_work DEMO-203 "Charge customers in their own currency" L <<'MD'
**DEMO-203 — Charge customers in their own currency**

Orders carry a `currency` (ISO 4217 code) and an `amount_cents` in EUR. Today `charge()` in
`src/billing/charge.py` sends the EUR amount to the gateway whatever the customer's currency is.

Before charging, convert the EUR amount into the order's currency using the rates provider, and
send the converted amount and the currency to the gateway. The receipt shows the converted amount
and the rate used. The nightly revenue report keeps reporting in EUR.

Acceptance criteria:
- An order of 1000 EUR cents in USD, with a rate of 1.10, is charged 1100 USD cents.
- An order in EUR is charged unchanged.
- The receipt shows the amount charged, its currency and the rate applied.
MD
