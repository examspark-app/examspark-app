# Founder — Payment keys jab milen (paste + test)

Keys aane ke baad **sirf paste + restart + smoke**. Code already ready. Secret keys **Git / Flutter me mat daalo**.

---

## 1) Backend `.env` — dono gateway same file

File: `examspark_backend/.env`

### Razorpay (Web)

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=          # webhook setup ke baad
```

### Google Play (Android)

```env
GOOGLE_PLAY_PACKAGE_NAME=com.example.examspark_frontend
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=C:\secrets\examspark-play.json
```

(JSON file path **ya** raw JSON string — dono OK.)

### Restart FastAPI

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
pip install -r requirements.txt
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Browser: `http://localhost:8000/` → payments line should mention razorpay / play code ready.

---

## 2) Flutter `.env` (public only)

File: `examspark_frontend/.env`

```env
FASTAPI_BASE_URL=http://localhost:8000
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
```

Phone se Android test: `localhost` ki jagah PC ka LAN IP (e.g. `http://192.168.x.x:8000`).

**Never:** `RAZORPAY_KEY_SECRET` or Play service-account JSON in Flutter.

Full Flutter restart (stop + `flutter run`), sirf hot reload nahi.

---

## 3) SQL (ek baar — credits grant after pay)

Supabase SQL Editor me run:

`examspark_backend/session6_fn_grant_credits_migration.sql`

---

## 4) Smoke tests (alag paths)

| Platform | Guide | What to prove |
|----------|--------|----------------|
| **Web** | [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md) | ₹199 → ~1500 credits, audio lock; ₹499 → audio unlock |
| **Android** | [`FOUNDER_GOOGLE_PLAY_BILLING.md`](FOUNDER_GOOGLE_PLAY_BILLING.md) | Internal testing purchase → plan/credits |

Dono same din set / test kar sakte ho — clash nahi.

PhonePe: abhi stub — keys hone pe alag session.

---

## 5) Refunds (money vs app access)

- **Paisa return:** Razorpay Dashboard (Web) ya Google Play Console (Android) — Flutter se “fake refund” nahi.
- **App access band:** refund hone pe server subscription cancel + payment `refunded` mark karta hai.
- Full rules: [`REFUND_POLICY_AND_PROCESS.md`](../REFUND_POLICY_AND_PROCESS.md)

---

## Checklist

- [ ] Razorpay test keys in backend `.env`
- [ ] Play package + service account in backend `.env` (Android jab ready)
- [ ] `fn_grant_credits` SQL run
- [ ] FastAPI restart + health OK
- [ ] Web smoke **or** Android smoke (jo keys ready hain)
- [ ] Chat: **Session 6 pass** (Web) / **Play smoke pass** (Android)
