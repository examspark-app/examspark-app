# ExamSpark — Payment Architecture

> **Status:** Architecture only — NO live payment integration.
> **Rule:** No fake success, no hardcoded payment completion, API keys empty.

---

## Platforms

| Platform | Gateway | Subscriptions | Credit packs |
|----------|---------|---------------|--------------|
| **Web** | Razorpay (primary), PhonePe (optional future) | Yes | Yes (future) |
| **Android** | Google Play Billing only | Yes | Per Play policy |

**Android:** Do NOT use Razorpay for subscriptions (Google Play policy).

---

## Payment Flow

```text
User
  ↓
Choose Plan (Free / Entry / Mid / Premium / Teacher / Credit Pack)
  ↓
Create Order          POST /api/v1/payments/orders
  ↓
Pending Payment       Gateway checkout (TODO)
  ↓
Verify Payment        POST /api/v1/payments/verify
  ↓
Activate Subscription user_subscriptions / teacher_subscriptions
  ↓
Allocate Monthly Credits  credit_history + users.credits_balance
  ↓
Store Transaction     payments + payment_transactions
```

---

## Web Plans (catalog)

| Plan | ID | Monthly credits | INR |
|------|-----|-----------------|-----|
| Free | `free` | 75 | 0 |
| ₹199 | `plan_199` | 1,500 | 199 |
| ₹499 | `plan_499` | 3,500 | 499 |
| ₹999 | `plan_999` | 8,000 | 999 |
| Teacher | `teacher` | 16,000 | 1999 |

Optional re-entry: `plan_299` (same unlock tier as `plan_199` if reintroduced).

**Buy Extra Credits (a-la-carte, Jul 13, 2026):** 5 packs live in `credit_packs` table + `SubscriptionPlans.creditPacks` — 100/₹25, 500/₹110, 1,000/₹200, 5,000/₹850, 10,000/₹1,500. No teacher commission on these. Live checkout still Phase 5 (Razorpay webhooks).

---

## Backend (FastAPI)

```
examspark_backend/
  app/
    config.py                 # Empty keys, TODO markers
    models/payment.py         # Pydantic models
    services/
      payment_orchestrator.py # Main flow
      credit_allocator.py
      security.py             # Webhook sig, idempotency, replay
      webhook_service.py
      gateways/
        razorpay_gateway.py   # TODO: Razorpay Integration
        phonepe_gateway.py    # TODO: PhonePe Integration
        google_play_gateway.py # TODO: Google Play Billing
    routers/
      payments.py             # /api/v1/payments/*
      admin_payments.py       # /api/v1/admin/* (pending)
  schema.sql                  # Payment tables section
```

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/payments/orders` | Create order → pending |
| POST | `/api/v1/payments/verify` | Verify → activate → credits |
| GET | `/api/v1/payments/status/{order_id}` | Order status |
| POST | `/api/v1/payments/webhooks/razorpay` | Razorpay webhook |
| POST | `/api/v1/payments/webhooks/phonepe` | PhonePe webhook |
| POST | `/api/v1/payments/webhooks/google-play` | Play RTDN |

---

## Flutter

```
lib/core/payments/
  payment_service.dart          # Orchestrator (no fake success)
  payment_repository.dart       # FastAPI client (TODO HTTP)
  subscription_plans.dart       # Plan catalog
  models/                       # PaymentOrder, PaymentResult
  interfaces/payment_gateway.dart
  gateways/
    razorpay_gateway.dart       # TODO: Razorpay Integration
    phonepe_gateway.dart        # TODO: PhonePe Integration
    google_play_billing_gateway.dart # TODO: Google Play Billing

lib/presentation/screens/admin/
  admin_payment_hub_screen.dart
  admin_payment_screens.dart    # All pages pending
```

Routes: `/admin/payments`, `/admin/subscriptions`, etc.

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `subscription_plans` | Plan catalog |
| `credit_packs` | One-time packs (future) |
| `user_subscriptions` | Active subscriptions |
| `teacher_subscriptions` | Teacher plan metadata |
| `payments` | Orders / payment attempts |
| `payment_transactions` | Immutable financial log |
| `credit_history` | Credit grants and usage audit |
| `payment_logs` | Operational audit |
| `payment_webhooks` | Webhook events + replay protection |
| `payment_idempotency` | Idempotency keys |

---

## Security (prepared)

- Webhook signature verification (per gateway)
- Replay protection (`payment_webhooks.event_id` unique)
- Duplicate payment prevention (`payments.status = verified`)
- Idempotency keys on order + verify

---

## Integration Checklist (later)

- [ ] TODO: Razorpay Integration — keys, checkout, webhook
- [ ] TODO: PhonePe Integration
- [ ] TODO: Google Play Billing — BillingClient + server verify
- [ ] Wire `PaymentRepository` HTTP to FastAPI
- [ ] Run `schema.sql` payment section on Supabase
- [ ] Admin auth guard on `/api/v1/admin/*`

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Initial payment architecture (no live integration) |
