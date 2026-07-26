# Founder — Smoke SQL pack (soniabuddy73) — **separate files**

Email: **soniabuddy73@gmail.com**  
Rule: **ek time pe ek file** Supabase SQL Editor mein.

| Order | File | Kya karta hai |
|-------|------|----------------|
| **A** | [`FOUNDER_SMOKE_A_VERIFIED_SONIABUDDY73.sql`](FOUNDER_SMOKE_A_VERIFIED_SONIABUDDY73.sql) | Mock **Trusted / AI verified** |
| **B** | [`FOUNDER_SMOKE_B_TEACHER_PLAN_SONIABUDDY73.sql`](FOUNDER_SMOKE_B_TEACHER_PLAN_SONIABUDDY73.sql) | Mock **Teacher plan buy** + 16k credits |
| **C** | [`FOUNDER_SMOKE_C_SAMPLE_LECTURE_SONIABUDDY73.sql`](FOUNDER_SMOKE_C_SAMPLE_LECTURE_SONIABUDDY73.sql) | **TEST — Sample Lecture** (text, no mic) |
| **D** | [`FOUNDER_SMOKE_D_SUBSCRIPTION_ENDING_SONIABUDDY73.sql`](FOUNDER_SMOKE_D_SUBSCRIPTION_ENDING_SONIABUDDY73.sql) | **Subscription ending** (expire plans) |

Optional student audio plan (alag): [`FOUNDER_MOCK_TEST_SONIABUDDY73.sql`](FOUNDER_MOCK_TEST_SONIABUDDY73.sql) = plan_499.

---

## Run order (Teacher Create Group smoke)

1. App mein Teacher account already login (`soniabuddy73@gmail.com`)  
2. Run **A** → verify row `verification_status=verified`  
3. Run **B** → `plan_tier=teacher`, credits ≥ 16000  
4. Hot restart Flutter  
5. Teacher Dashboard → Create Group / Share / Record smoke  
6. Run **C** → Library mein **TEST — Sample Lecture**  
7. Jab expiry test chahiye → **D** (phir Free locks check)

**.env / naya migration:** in 4 files ke liye nahi.

---

## Start **F** ya **B**? (guide)

| Code | Matlab | Abhi? |
|------|--------|--------|
| **B** | Phase **1B wireframes** | **Mat start** — pehle se complete / approve |
| **F** | Locked queue mein aksar **Firebase / FCM** (ya SQL order step F coupon) | Smoke A–C ke **baad** jab push chahiye → bolo `start Firebase` / `start FCM` |
| Phase 2 gaps | Settings/Help ho chuka | Next: `start phase 2 slice 2` (Library Favorites) |

**Recommendation abhi:**  
1) SQL **A → B → C** run + app smoke  
2) Phir **D** sirf expiry test ke liye  
3) Coding next: `start phase 2 slice 2` **ya** `start FCM` — jo pehle chahiye

---

## Manual checklist

- [ ] A verify query = verified / 95  
- [ ] B verify = teacher + credits  
- [ ] C = TEST lecture in Library  
- [ ] D only when testing end-of-plan  
- [ ] Flutter + FastAPI running for UI smoke  
