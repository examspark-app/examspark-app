# Session 6 — Razorpay (Web, test mode) — Founder setup guide

Follow these steps in order. After each step, do the **Verify** check before continuing.

---

## What this enables

- Web users can pay for **plans** (`plan_199` / `499` / `999` / `teacher`) and **credit packs**
- FastAPI creates the Razorpay order (amount from server catalog — Flutter cannot lie about price)
- Checkout success is only trusted after **server signature verify** or **webhook**
- Credits granted = **plan package or pack only** (no Free 50 stacked on paid)

Android subscriptions stay on **Google Play stub** (not Razorpay).

---

## Step 1 — SQL (grant credits function)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your ExamSpark project
2. Left menu: **SQL Editor** → **New query**
3. Open this file on your PC and copy **all** of it:

   `examspark_backend/session6_fn_grant_credits_migration.sql`

4. Paste into SQL Editor → click **Run**
5. **Verify:** no red error. You should see “Success”.

---

## Step 2 — Razorpay Dashboard (test mode)

1. Go to [https://dashboard.razorpay.com](https://dashboard.razorpay.com) → log in
2. Top-left: switch to **Test Mode** (not Live)
3. **Settings** → **API Keys** → **Generate Test Key** (if you do not have one)
4. Copy:
   - **Key ID** (starts with `rzp_test_…`)
   - **Key Secret** (show once — save in a password manager)

**Verify:** You can see a Test Key ID in API Keys.

---

## Step 3 — Paste keys into backend `.env`

1. Open file: `examspark_backend/.env`  
   (If missing: copy from `examspark_backend/.env.example` first)
2. Paste (replace with your real test values):

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=
```

Leave `RAZORPAY_WEBHOOK_SECRET` empty until Step 5.

3. Optional Flutter `.env` (public key only — same Key ID):

   File: `examspark_frontend/.env`

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
```

(Key Secret must **never** go in Flutter.)

4. **Verify:** Restart FastAPI after saving `.env`.

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Browser: `http://localhost:8000/`  
Look for `"payments": "razorpay_web_test_ready"`.

---

## Step 4 — Flutter Web API base

In `examspark_frontend/.env` you need FastAPI URL, for example:

```env
FASTAPI_BASE_URL=http://localhost:8000
```

**Verify:** Full restart Flutter Web (stop + `flutter run -d chrome`), not only hot reload.

---

## Step 5 — Webhook (recommended) + ngrok

Checkout verify works without webhook. Webhook is the backup if the browser closes early.

1. Install ngrok (or any tunnel) if needed: [https://ngrok.com](https://ngrok.com)
2. With FastAPI running on port 8000:

```powershell
ngrok http 8000
```

3. Copy the HTTPS URL, e.g. `https://abcd.ngrok-free.app`
4. Razorpay Dashboard → **Settings** → **Webhooks** → **Add New Webhook** (Test Mode)
5. URL:

```text
https://YOUR-NGROK-HOST/api/v1/payments/webhooks/razorpay
```

6. Events: at least **`payment.captured`** (and optionally `order.paid`)
7. After save, copy **Webhook Secret**
8. Paste into `examspark_backend/.env`:

```env
RAZORPAY_WEBHOOK_SECRET=whsec_xxxxxxxx
```

9. Restart FastAPI.

**Verify:** Razorpay shows webhook Active. Send a Test event if the dashboard offers it — FastAPI should return 200 (signature must match).

---

## Step 6 — Smoke test (test cards)

1. Log into ExamSpark Web as a free user
2. Open **Plans** (Profile → Subscription / Plans)
3. Buy **₹199** with Razorpay **test card** (Razorpay docs: `4111 1111 1111 1111`)
4. After success:
   - Credits should show **~1500** granted from the plan (not Free 50 + 1500 as a double “free” grant)
   - Audio record/upload still **locked** (needs ₹499+)
5. Then buy **₹499** → audio should **unlock**

**If checkout opens but credits do not change:**  
Check FastAPI terminal for errors. Confirm Step 1 SQL ran. Confirm you are logged in (Bearer token).

---

## Rollback

- Remove/clear Razorpay keys from `.env` and restart → create order returns “not configured”
- No need to delete DB rows for smoke tests (test payments are fake money)

---

## Files safe to leave

Keep `FOUNDER_RAZORPAY_SESSION6.md` and `session6_fn_grant_credits_migration.sql` — do not delete.

---

## After Session 6 pass

Tell the agent: Session 6 pass → next (YouTube notes / generate FastAPI / etc.).
