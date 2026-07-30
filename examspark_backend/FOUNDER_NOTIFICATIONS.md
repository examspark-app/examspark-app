# Founder — Notifications

Canonical map: [`NOTIFICATIONS.md`](../NOTIFICATIONS.md)

## Live now

| Event | In-app | FCM |
|-------|--------|-----|
| Teacher share / announce | ✅ | ✅ |
| Join Pending / Accept / Reject | ✅ | ✅ |
| Plan expires 7 / 3 / 1 day + expired | ✅ | ✅ |
| **Payment success / fail** | ✅ | ✅ |

FCM: [`FOUNDER_FCM_SETUP.md`](FOUNDER_FCM_SETUP.md)

---

## A1 — Join (SQL once)

[`notifications_join_events_migration.sql`](notifications_join_events_migration.sql) → `event_type` column

## A2 — Expiry (SQL once)

[`notifications_subscription_expiry_migration.sql`](notifications_subscription_expiry_migration.sql) → `subscription_expiry_alerts`

## A3 — Payment (no new SQL)

Hooks inside payment verify / fulfill.  
Copy shows **plan name / success-fail only** — no credit amounts / paise.

### Manual setup A3

1. **FastAPI restart** (payment orchestrator change)  
2. Flutter **R**  
3. Naya `.env` / SQL **nahi** (A1+A2 SQL pehle se)

### Smoke A3

1. Test-mode Razorpay / Play: complete a plan or pack purchase → Home bell: **Payment successful**  
2. Tap → Subscription screen  
3. Fake/bad verify (wrong signature) once → **Payment failed** (once per order)  
4. Same success again → no duplicate (metadata `notify_success`)

**Note:** Real money smoke only when Razorpay/Play keys ready. Until then code is live; test when you do payment smoke.

---

## Next (optional)

| Command | What |
|---------|------|
| `start notes-ready notifications` | Recording → notes ready |
| `start low-credits notifications` | Soft low-balance alert |

## A4 — Create Group disclaimer (no SQL)

First Create Group after setup gate → soft sheet once.  
Device remembers via SharedPreferences. Flutter **R** only.

Smoke: Teacher Dashboard → Create Group → see disclaimer → Continue → form. Second time → form direct.

## Channels

Home bell · Groups unread (posts) · FCM lock/tray
