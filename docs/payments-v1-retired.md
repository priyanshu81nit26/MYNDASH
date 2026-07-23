# Payments v1 retired

Razorpay and MYNDASH PRO were intentionally disabled on 19 July 2026.

The current release:

- has no payment SDK dependency;
- loads no checkout JavaScript;
- exports no payment Cloud Functions;
- offers no paid subscription or simulated entitlement;
- keeps coins earnable through gameplay;
- presents the Store only as an upcoming preview; and
- makes AI Trainer available to every player.

Legacy `isPro`, `isUltra`, and `proUntil` fields remain in local state only for
backward-compatible save loading. They do not gate current features.

The inert Dart seam in `lib/services/payments.dart` is intentionally retained
so a future Stripe/UPI implementation has a clear integration boundary. Do not
reactivate the old endpoints. A future payment implementation must use new
server-created orders, provider-side verification/webhooks, idempotency, and
store-compliant mobile billing rules.
