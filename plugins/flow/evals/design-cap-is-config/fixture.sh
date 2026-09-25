#!/usr/bin/env bash
# Design trap: the premise. The ticket asks for a per-invoice counter and a stop after
# the third reminder, and both already exist — the cap is a setting that says 5. The
# design that builds what was asked adds a second counter beside the first; the right
# one changes one number.
set -euo pipefail
. "$(dirname "$0")/../_lib/fixture.sh"

fx_design_repo
mkdir -p src/notify config
cat > config/settings.py <<'PY'
"""Operational settings. Read at import time; a change here ships with the next deploy."""

# Payment reminders sent for one unpaid invoice before the sender stops.
MAX_REMINDERS = 5

# Days between two reminders for the same invoice.
REMINDER_INTERVAL_DAYS = 3
PY
cat > src/notify/sent_log.py <<'PY'
"""What was sent to whom, so a sender can tell what it already did."""


class SentLog:
    def __init__(self):
        self._rows = []

    def add(self, invoice_id, kind):
        self._rows.append((invoice_id, kind))

    def count(self, invoice_id, kind):
        return sum(1 for row in self._rows if row == (invoice_id, kind))
PY
cat > src/notify/reminders.py <<'PY'
"""Sends the 'your payment is overdue' email for unpaid invoices."""

from config.settings import MAX_REMINDERS

KIND = "payment-reminder"


def send_due_reminders(invoices, mailer, sent_log):
    """Email every unpaid invoice's customer, at most MAX_REMINDERS times per invoice."""
    sent = 0
    for invoice in invoices:
        if invoice["paid"]:
            continue
        if sent_log.count(invoice["id"], KIND) >= MAX_REMINDERS:
            continue
        mailer.send(invoice["customer_email"], "Your payment is overdue", invoice["id"])
        sent_log.add(invoice["id"], KIND)
        sent += 1
    return sent
PY
cat > tests/test_reminders.py <<'PY'
import unittest

from config.settings import MAX_REMINDERS
from src.notify.reminders import send_due_reminders
from src.notify.sent_log import SentLog


class Mailer:
    def __init__(self):
        self.sent = []

    def send(self, to, subject, ref):
        self.sent.append(ref)


class RemindersTest(unittest.TestCase):
    def test_stops_at_the_cap(self):
        mailer, log = Mailer(), SentLog()
        invoice = {"id": "i1", "paid": False, "customer_email": "a@example.invalid"}
        for _ in range(MAX_REMINDERS + 2):
            send_due_reminders([invoice], mailer, log)
        self.assertEqual(len(mailer.sent), MAX_REMINDERS)


if __name__ == "__main__":
    unittest.main()
PY

fx_design_work DEMO-202 "Stop the overdue-payment reminders after the third one" M <<'MD'
**DEMO-202 — Stop the overdue-payment reminders after the third one**

Customers with an unpaid invoice get up to five "your payment is overdue" emails for it, and
support is fielding complaints about the fourth and fifth. Product wants no more than three per
invoice.

Add a counter per invoice that records how many reminders have gone out, and stop sending once
the third one has been sent.

Acceptance criteria:
- An unpaid invoice receives at most three overdue-payment reminders.
- A paid invoice receives none.
MD
