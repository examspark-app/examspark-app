# Founder — Dev mock purchase (`IS_TESTING`)

**What it does:** When `IS_TESTING=true` on **both** backend and Flutter:

| Buy | What happens |
|-----|----------------|
| **Credit pack** | +50 credits only (quick smoke) |
| **Plan** (₹199 / ₹499 / ₹999 / **Teacher ₹2,999**) | Plan **active** + **full monthly credits** (Teacher = **16,000**) |

Jul 25 fix: mock Teacher used to grant only **+50** while unlocking plan — that made balance look like ~150. Now mock plan matches real monthly allotment.

**Safety:** Backend `IS_TESTING` false → **403**. Production / Railway must keep **off**.

---

## 1. Turn mock ON (local)

### A) Backend — `examspark_backend/.env`

```env
IS_TESTING=true
```

### B) Flutter — `examspark_frontend/.env`

```env
IS_TESTING=true
FASTAPI_BASE_URL=http://localhost:8000
```

### C) Restart backend (Ctrl+C → start again). Flutter **R**.

---

## 2. If account already stuck at ~150 after Teacher mock

1. Open [`FOUNDER_TEACHER_MOCK_CREDITS_TOPUP.sql`](FOUNDER_TEACHER_MOCK_CREDITS_TOPUP.sql)  
2. Replace `YOUR_EMAIL@gmail.com` with your login email  
3. Supabase → SQL Editor → Run  
4. Flutter **R** → credits pill should show ~16000  

---

## 3. Smoke — Teacher Record + credits

1. Subscription → **Get Teacher plan** (mock)  
2. Expect: plan active **and** +16,000 credits (not +50)  
3. Teacher Dashboard → Record unlocked  
