# ExamSpark — Refund Policy & Process (compliance)

> **Founder-locked draft Jul 15, 2026.** Money refunds happen only in **Razorpay** or **Google Play** dashboards. Flutter never invents a successful refund. Server must remove paid access after a store refund.

Related: [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](examspark_backend/FOUNDER_PAYMENT_KEYS_WHEN_READY.md) · [`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md) · [`FOUNDER_GOOGLE_PLAY_BILLING.md`](examspark_backend/FOUNDER_GOOGLE_PLAY_BILLING.md) · [`PAYMENT_ARCHITECTURE.md`](PAYMENT_ARCHITECTURE.md)

---

## 1. Policy (user-facing rules)

| Case | Rule |
|------|------|
| **Subscription (₹199 / ₹499 / ₹999 / Teacher)** | Store rules first (Razorpay / Google Play). After a **full refund**, paid plan access ends; user returns to Free (50 credits signup pool — not a new Free stack on top of old paid balance beyond clawback). |
| **Credit packs (a-la-carte)** | Eligible for review within **7 days** of purchase **if** credits remaining ≈ pack size (almost unused). Heavy AI use of those credits → refund of **money** may still happen via store policy, but ExamSpark claws back **remaining** credits only (cannot reclaim already spent AI). |
| **Already consumed AI features** | No guarantee of balance restoration to pre-purchase levels after refund — clawback is **best-effort** up to current balance. |
| **Failed / cancelled checkout** | No charge, no access change. |
| **Chargeback / dispute** | Treat like refund: end paid access + audit log. |

**Platform note:** Google Play and Razorpay may force refunds under their consumer policies. ExamSpark **must** honour voided / refunded payments (no paid features after money returned).

---

## 2. Who refunds the money

| Channel | Who clicks Refund | ExamSpark Flutter |
|---------|-------------------|-------------------|
| Web (Razorpay) | Founder / support: Razorpay Dashboard → Payments → Refund | Never |
| Android (Play) | Founder / support: Play Console → Order management → Refund | Never |
| PhonePe | Not live yet | — |

---

## 3. What ExamSpark does after money is refunded

Automated by FastAPI `refund_service` when webhook reports refund (or ops/admin later):

1. Find `payments` row by `gateway_payment_id` / order  
2. If already `refunded` → **idempotent** no-op  
3. Set `payments.status = refunded`  
4. Insert `payment_transactions` with `type = refund`  
5. Cancel active `user_subscriptions` for that user (status `cancelled`) when this payment was a plan purchase  
6. Best-effort clawback: deduct up to `metadata.credits_allocated` via `fn_deduct_credits` (or less if balance lower)  
7. **Trim group memberships** via `fn_trim_group_memberships` after a plan refund/cancel — Free (`max_groups=0`) leaves **all** student joins; downgrade keeps newest `joined_at` up to the new max  
8. Insert `credit_history` with `source = refund`  
9. `payment_logs` event `payment_refunded` (includes `groups_left`)

Result: user should not keep mid/premium audio unlock **or extra group joins** from a refunded paid sub.

---

## 4. Founder manual steps — Razorpay (Web)

1. Open [Razorpay Dashboard](https://dashboard.razorpay.com) → **Payments**  
2. Open the payment → **Refund** (full or partial as policy)  
3. Confirm refund status = processed  
4. Ensure webhook includes `refund.processed` / `payment.refunded` to  
   `POST /api/v1/payments/webhooks/razorpay`  
5. **Verify:** Supabase `payments.status` = `refunded`; user’s plan via `fn_user_plan_tier` back toward `free` if that was their only active paid sub; `class_memberships` for that user trimmed (0 rows if Free)  

If webhook missed: re-send from Razorpay or ask eng to run refund handler for that `gateway_payment_id`.

---

## 5. Founder manual steps — Google Play (Android)

1. Play Console → **Order management** → find order  
2. **Refund** per Console UI  
3. Prefer RTDN to `POST /api/v1/payments/webhooks/google-play` (voided / refund notification)  
4. **Verify:** same as Razorpay — `payments` refunded, subscription cancelled  

Google may also issue refunds from user request — same app reaction required.

---

## 6. Support reply template (short)

> Refunds for subscriptions follow Razorpay / Google Play rules. After a refund is completed in the payment system, your paid plan access is removed. Credits already used for AI features cannot always be restored; unused pack credits may be adjusted. Contact support with your payment ID / Play order number.

---

## 7. Compliance checklist

- [ ] Money refund only via official gateway dashboard  
- [ ] Webhook (or equivalent) ends paid access after refund  
- [ ] Audit rows in `payment_transactions` + `credit_history` / logs  
- [ ] No Flutter “refund success” without server  
- [ ] This policy linked from Profiles / Help when UI is ready (future)

---

## Changelog

| Date | Change |
|------|--------|
| Jul 15, 2026 | Initial policy + process; server refund handler wired |
| Jul 15, 2026 | Plan refund also calls `fn_trim_group_memberships` (auto-leave overflow / all on Free) |
