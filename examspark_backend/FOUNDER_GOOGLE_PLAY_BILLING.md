# Google Play Billing — Founder setup (Internal testing OK, Live Store not required)

Code is ready. **Real Android purchases work only after** Console products + one Internal-testing AAB + service account. You do **not** need the app “Live” on the public Play Store for test buys.

---

## What code already does

- Android Plans / packs → FastAPI order → Play Billing UI → server verify token → activate plan / grant credits  
- Product IDs (must match Console exactly):

| ExamSpark id | Play product ID | Type |
|--------------|-----------------|------|
| plan_199 | `examspark_plan_199` | Subscription |
| plan_499 | `examspark_plan_499` | Subscription |
| plan_999 | `examspark_plan_999` | Subscription |
| teacher | `examspark_plan_teacher` | Subscription |
| pack_100 | `examspark_pack_100` | One-time (consumable) |
| pack_500 | `examspark_pack_500` | One-time |
| pack_1000 | `examspark_pack_1000` | One-time |
| pack_5000 | `examspark_pack_5000` | One-time |
| pack_10000 | `examspark_pack_10000` | One-time |

Package name in code today: `com.example.examspark_frontend`  
(Change later before production branding — then update Console + `.env` together.)

Web still uses **Razorpay** only. Android never uses Razorpay for subscriptions (Play policy).

---

## Step 1 — Play Console app (draft / Internal OK)

1. Go to [Google Play Console](https://play.google.com/console)
2. Create app (or open existing) — status can stay **Internal testing** (not Live)
3. Confirm package name = Flutter `applicationId`  
   File: `examspark_frontend/android/app/build.gradle.kts` → `applicationId`

**Verify:** App appears in Console with that package name.

---

## Step 2 — First AAB to Internal testing

Billing products usually need at least one upload:

1. Build AAB (when Android SDK is ready):

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter build appbundle
```

2. Play Console → **Testing** → **Internal testing** → create release → upload AAB  
3. Add yourself as a tester; accept the opt-in link on the phone

**Verify:** Internal testing release shows the app; you can install from the tester link.

---

## Step 3 — Create products (same IDs as table above)

1. **Monetize** → **Products** → **Subscriptions** — create each `examspark_plan_*`  
2. **In-app products** — create each `examspark_pack_*` (consumable / one-time)  
3. Activate products (draft alone may not be purchasable)

**Verify:** Each product ID matches the table **exactly** (spelling + underscores).

---

## Step 4 — Service account (server verify)

1. Google Cloud Console → same Google account as Play  
2. Create / use a project → enable **Google Play Android Developer API**  
3. Create **Service account** → download JSON key  
4. Play Console → **Users and permissions** → invite the service account email → grant access to view financial data / manage orders (needed for purchase API)  
5. On your PC, save the JSON file (e.g. `C:\secrets\examspark-play.json`) — **never commit** to Git

---

## Step 5 — Backend `.env`

File: `examspark_backend/.env`

```env
GOOGLE_PLAY_PACKAGE_NAME=com.example.examspark_frontend
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=C:\secrets\examspark-play.json
```

(You can paste the entire JSON as one line instead of a file path.)

Restart FastAPI:

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Also keep:

```env
FASTAPI_BASE_URL=http://YOUR_LAN_IP:8000
```

in `examspark_frontend/.env` (phone must reach FastAPI — not only `localhost` from the device).

**Verify:** Phone can open `http://YOUR_PC_IP:8000/` in Chrome.

---

## Step 6 — License testers (recommended)

Play Console → **Settings** → **License testing** → add Gmail accounts used on test phones.  
Those accounts get test / sandbox purchases.

---

## How to smoke-test (when Steps 1–5 done)

1. Install Internal testing build on Android  
2. Log in → Plans → Upgrade ₹199 (or Teacher)  
3. Complete Play purchase sheet  
4. Expect: plan active + credits granted (server verify)  
5. Audio unlock still only on **₹499+** (same credit economy rules)

If verify fails: check FastAPI logs — usually wrong product ID, missing Play API permission, or service account not linked.

### License-tester purchases

1. Play Console → **Settings** → **License testing** → add the Gmail used on the phone  
2. That account gets **test / sandbox** billing (not always real charge — follow Console copy)  
3. After buy: Play Console → **Order management** (or Monetize → orders) → find the order  

**Verify:** Order shows for your package + product ID.

### Where to see the order

- Play Console → **Order management** / **Financial reports** → filter by app  
- Match `examspark_plan_*` / `examspark_pack_*` product ID  

---

## Refund test (compliance)

Google’s refund rules are **Play platform policy** — ExamSpark must honour voided purchases (no paid access after refund).

### Issue / confirm refund in Console

1. Play Console → **Order management** → open the test order  
2. Use **Refund** (or request refund flow) as shown in Console  
3. Wait until order shows refunded / voided  

### What ExamSpark does after refund

Server (webhook / RTDN when configured):

1. Mark `payments.status = refunded`  
2. Cancel active `user_subscriptions` for that user (paid access ends)  
3. Audit `payment_transactions` + `credit_history` (best-effort clawback of remaining granted credits)  

**Money:** always via Play Console — app never invents a money refund.  
Full policy: [`REFUND_POLICY_AND_PROCESS.md`](../REFUND_POLICY_AND_PROCESS.md)

### RTDN / Pub/Sub (later)

When ready: connect Real-time developer notifications to  
`POST /api/v1/payments/webhooks/google-play`  
so voided purchases auto-run the refund handler. Until then: founder can trigger by ensuring webhook payload reaches FastAPI, or wait for next ops pass (VOIDED_PURCHASES poll).

---

## Without Console upload yet — what you can test today

| Test | Works? |
|------|--------|
| Plans & Credits UI (Web) | Yes |
| Android “Upgrade” without products | Shows clear error / not found product — **no fake success** |
| Real money / Play sandbox purchase | No — finish Steps 1–5 |

---

## Razorpay (Web) reminder

Still separate: [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md) + `session6_fn_grant_credits_migration.sql`.

Keys paste both gateways: [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](FOUNDER_PAYMENT_KEYS_WHEN_READY.md).

PhonePe: not built this pass — ask for a PhonePe session later.

---

## Rollback

Clear `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` from `.env` → verify fails closed; UI stays honest.
