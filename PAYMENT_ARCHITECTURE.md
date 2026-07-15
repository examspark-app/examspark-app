# ExamSpark — Payment Architecture

> **Status:** Razorpay **Web** path coded (test keys pending). Google Play Billing **Android code ready** (Console Internal testing + service account pending). PhonePe = stub.
> **Rule:** No fake success. Server never trusts Flutter “payment success” without signature / Play token verify.
> **Guides:** [`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md) · [`FOUNDER_GOOGLE_PLAY_BILLING.md`](examspark_backend/FOUNDER_GOOGLE_PLAY_BILLING.md) · [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](examspark_backend/FOUNDER_PAYMENT_KEYS_WHEN_READY.md) · [`REFUND_POLICY_AND_PROCESS.md`](REFUND_POLICY_AND_PROCESS.md)

---

## Platforms

| Platform | Gateway | Subscriptions | Credit packs |
|----------|---------|---------------|--------------|
| **Web** | Razorpay (primary), PhonePe (optional future) | Yes (test mode code ready) | Yes (test mode code ready) |
| **Android** | Google Play Billing only | Code ready — Console test pending | Code ready — Console test pending |

**Android:** Do NOT use Razorpay for subscriptions (Google Play policy). **Live Store listing not required** for Internal testing purchases.

---

## Payment Flow

```text
User
  ↓
Choose Plan / Credit Pack
  ↓
Create Order          POST /api/v1/payments/orders  (Bearer auth)
                      amount / Play product_id from server catalog
  ↓
Pending Payment       Web → Razorpay Checkout.js
                      Android → Play Billing (in_app_purchase)
  ↓
Verify Payment        POST /api/v1/payments/verify
                      Web: Razorpay HMAC (+ webhook)
                      Android: Play Developer API purchaseToken
  ↓
Activate Subscription user_subscriptions (plans only)
  ↓
Allocate Credits      fn_grant_credits + credit_history
                      plan package OR pack only — no Free 50 stacked on paid
  ↓
Store Transaction     payments + payment_transactions
```
---

## Web Plans (catalog)

| Plan | ID | Monthly credits | INR |
|------|-----|-----------------|-----|
| Free | `free` | 50 (signup grant) | 0 |
| ₹199 | `plan_199` | 1,500 | 199 |
| ₹499 | `plan_499` | 3,500 | 499 |
| ₹999 | `plan_999` | 8,000 | 999 |
| Teacher | `teacher` | 16,000 | 1999 |

Optional re-entry: `plan_299` (same unlock tier as `plan_199` if reintroduced).

**Buy Extra Credits (a-la-carte):** `pack_100`…`pack_10000` — see `credit_packs` / `SubscriptionPlans.creditPacks`. No teacher commission. Live Web checkout via Razorpay (Session 6).

---

## Backend (FastAPI)

```
examspark_backend/
  app/
    config.py                 # RAZORPAY_KEY_ID / SECRET / WEBHOOK_SECRET
    constants/payment_catalog.py
    models/payment.py
    services/
      payment_orchestrator.py
      credit_allocator.py     # fn_grant_credits + credit_history
      security.py             # payment + webhook HMAC
      webhook_service.py      # idempotent event_id
      gateways/razorpay_gateway.py
    routers/payments.py
  session6_fn_grant_credits_migration.sql
  FOUNDER_RAZORPAY_SESSION6.md
```

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/payments/orders` | Create order → pending (auth) |
| POST | `/api/v1/payments/verify` | Verify → activate → credits (auth) |
| GET | `/api/v1/payments/status/{order_id}` | Order status (auth) |
| POST | `/api/v1/payments/webhooks/razorpay` | Razorpay webhook (HMAC) |
| POST | `/api/v1/payments/webhooks/phonepe` | PhonePe stub |
| POST | `/api/v1/payments/webhooks/google-play` | Play RTDN stub |

---

## Flutter

```
lib/core/payments/
  payment_service.dart          # Web full flow; Android → Play stub
  payment_repository.dart       # FastAPI HTTP client
  razorpay_checkout.dart        # conditional web/stub
  subscription_plans.dart
  gateways/razorpay_gateway.dart
web/index.html                  # Checkout.js + openExamSparkRazorpay bridge
```

---

## Database

| Table / Function | Purpose |
|------------------|---------|
| `subscription_plans` / `credit_packs` | Catalog |
| `user_subscriptions` | Active plan |
| `payments` / `payment_transactions` | Orders + financial log |
| `credit_history` | Grant audit (idempotency_key) |
| `payment_webhooks` | Replay protection |
| `fn_grant_credits` | Add balance (bypass protect trigger) |

---

## Security

- Checkout signature: HMAC-SHA256(`order_id|payment_id`, KEY_SECRET)
- Webhook signature: HMAC-SHA256(raw body, WEBHOOK_SECRET)
- Duplicate activation blocked when `payments.status = verified`
- Idempotency keys on order + verify; webhook `event_id` unique

---

## Integration Checklist

- [x] Razorpay Web order create + checkout + verify + webhook handler
- [x] Wire Flutter Web `PaymentRepository` → FastAPI
- [x] Google Play Billing code (product map, Developer API verify, Android `in_app_purchase`)
- [x] Refund policy + process doc + server refund handler (Razorpay / Play webhooks)
- [ ] Founder: Razorpay test keys + `session6_fn_grant_credits_migration.sql` + Web smoke
- [ ] Founder: Play Internal testing AAB + products + service account + Android smoke
- [ ] PhonePe Integration
- [ ] Production Razorpay / Play Store Live after smokes
- [ ] VOIDED_PURCHASES poll job (if RTDN not used)

### Play product IDs (server + Flutter)

See [`payment_catalog.py`](examspark_backend/app/constants/payment_catalog.py) / [`play_products.dart`](examspark_frontend/lib/core/payments/play_products.dart) — e.g. `examspark_plan_199`, `examspark_pack_100`.

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Initial payment architecture (no live integration) |
| Jul 15, 2026 | Session 6 — Razorpay Web test-mode path; Free catalog 50; credit packs checkout |
| Jul 15, 2026 | Google Play Billing Android code ready; founder guide; Console test pending |
| Jul 15, 2026 | Refund policy + process; webhook-driven refund handler |
