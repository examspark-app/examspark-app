# Founder — Next after Groups mock pass

> **Jul 16, 2026** · Groups mock = pass · YouTube smoke = pass.  
> **Canonical next list:** [`FOUNDER_NEXT_SESSION.md`](FOUNDER_NEXT_SESSION.md) (do not re-nag passed SQL/smoke).

```text
Part A (15 min) → Realtime + trim SQL
Part B          → Session 6 Razorpay (⏸ keys)
Part C coding   → Flashcards/Quiz FastAPI (jab founder bole)
```

---

## Part A — Close Groups checklist

### A1 — Realtime ON (ek baar)

Supabase → **Database** → **Publications** / table **Realtime** toggle:

| Table | Must be ON |
|-------|------------|
| `users` | Credits live |
| `user_subscriptions` | Plan live |
| `class_memberships` | Join/leave live |

**Verify** (SQL Editor):

```sql
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('users', 'user_subscriptions', 'class_memberships');
```

Expect **3 rows**. If fewer, run:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.class_memberships;
```

("already member" = already ON — OK.)

Full guide: [`FOUNDER_SESSION_LIVE_SYNC.md`](FOUNDER_SESSION_LIVE_SYNC.md)

### A2 — Sub change → auto leave (ek baar)

If not run yet → SQL Editor → paste all of:

[`subscription_change_trim_groups_migration.sql`](subscription_change_trim_groups_migration.sql)

**Verify:** green Success.

### A3 — Chat

Likho: `groups + realtime checklist done`

---

## Part B — Session 6 Razorpay (NEXT product)

Full steps: [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md)  
Keys map: [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](FOUNDER_PAYMENT_KEYS_WHEN_READY.md)

| # | Action | Verify |
|---|--------|--------|
| 1 | Run [`session6_fn_grant_credits_migration.sql`](session6_fn_grant_credits_migration.sql) if not done | Success |
| 2 | Razorpay Dashboard → **Test Mode** → API Keys | `rzp_test_…` |
| 3 | Paste into `examspark_backend/.env` → restart uvicorn | `http://localhost:8000/` payments ready |
| 4 | Optional: same Key ID in `examspark_frontend/.env` | — |
| 5 | Flutter Web → Profile → Plans → **₹199** test pay | Checkout opens |
| 6 | Pay success | Plan + credits update; `payments.status` verified |

Pass line: `Session 6 Razorpay smoke pass`

---

## Do not start yet

PhonePe · random UI polish · Flashcards/MCQ (until you say so after Session 6)

---

## After Session 6 pass

1. Google Play Internal — [`FOUNDER_GOOGLE_PLAY_BILLING.md`](FOUNDER_GOOGLE_PLAY_BILLING.md)  
2. Refund webhook check — [`REFUND_POLICY_AND_PROCESS.md`](../REFUND_POLICY_AND_PROCESS.md)  
3. Flashcards / MCQ — founder OK separately

---

## .env (Session 6)

| Variable | Where | From |
|----------|--------|------|
| `RAZORPAY_KEY_ID` | backend `.env` (+ optional frontend) | Razorpay Test API Keys |
| `RAZORPAY_KEY_SECRET` | backend `.env` only | Razorpay Test (never Flutter) |
| `RAZORPAY_WEBHOOK_SECRET` | backend `.env` | After webhook setup in guide |
