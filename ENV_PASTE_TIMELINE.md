# ExamSpark — Kab `.env` mein keys paste karein?

> **Audience:** Founder (non-developer)
> **Rule:** Poora `.env` ek saath mat bharo. Har step par sirf us step ki keys paste karo.
> **Companion:** [`API_SETUP.md`](API_SETUP.md) (har key kahan se milegi)

---

## Short answer

| Kab | Kya paste karo |
|-----|------------------|
| **Abhi (optional)** | Sirf `SUPABASE_URL` + `SUPABASE_ANON_KEY` — agar login test chahiye |
| **Phase 4 ke dauran** | Supabase → Groq → OpenRouter → Tavily → Cloudflare R2 → pgvector (step-by-step) |
| **Phase 5 ke dauran** | Razorpay, PhonePe, Google Play, Firebase, Resend, PostHog, JWT, FastAPI URL |

**Jab AI bole "Manual setup required" — tab hi us step ki keys paste karo.**

---

## Files (kahan paste karna hai)

| File | Kya jaata hai |
|------|---------------|
| [`examspark_frontend/.env`](examspark_frontend/.env) | Sirf client-safe keys (Supabase URL + anon key) |
| [`examspark_backend/.env`](examspark_backend/.env) | Saari server keys (phase comments ke saath) |
| Supabase Dashboard → Edge Functions → Secrets | `SUPABASE_SERVICE_ROLE_KEY`, `GROQ_API_KEY`, etc. |

**Kabhi mat karo:** `.env` Git mein commit karna · `SUPABASE_SERVICE_ROLE_KEY` Flutter mein daalna

---

## Abhi kya karna hai (Phase 1–3 complete, Phase 4 not started)

### Step 1 — Files already created

Ye files project mein ban chuki hain (empty values):

- `examspark_frontend/.env`
- `examspark_backend/.env`

### Step 2 — Optional: login test ke liye sirf 2 keys

**Sirf agar login / recording test karna ho:**

1. [Supabase Dashboard](https://supabase.com) kholo
2. Apna project select karo
3. **Project Settings → API**
4. Copy karo:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_ANON_KEY`
5. Paste karo in [`examspark_frontend/.env`](examspark_frontend/.env)
6. App restart:
   ```powershell
   cd examspark_frontend
   flutter run -d chrome
   ```
7. **Verify:** Login screen khule, sign in kaam kare

**Backend `.env` abhi empty chhod sakte ho** — Phase 4 se pehle zaroorat nahi.

---

## Phase 4 — step-by-step key paste

Phase 4 shuru hone par har step ke baad ye keys paste karo:

```
Phase4Start
  → Step1 Supabase (URL, anon, service role)
  → Step2 Groq (transcription)
  → Step3 OpenRouter (Ask AI, Notes, Summary)
  → Step4 Tavily (web search — last resort)
  → Step5 Cloudflare R2 (file storage)
  → Step6 pgvector (RAG — no API key)
  → Phase5
```

| Step | Kab | Keys | Kahan paste |
|------|-----|------|-------------|
| 1 | Supabase SQL + RLS setup | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Flutter `.env` + Backend `.env` + Edge Function Secrets |
| 2 | Recording / transcription live | `GROQ_API_KEY`, whisper models | Backend `.env` + Edge Function Secrets |
| 3 | Ask AI / Notes / Summary live | `OPENROUTER_API_KEY`, `AI_*_MODEL` | Backend `.env` + Edge Function Secrets |
| 4 | Web search fallback | `TAVILY_API_KEY` | Backend `.env` |
| 5 | R2 file storage | `CLOUDFLARE_*`, `R2_*` | Backend `.env` |
| 6 | Vector RAG | `PGVECTOR_ENABLED=true` | Backend `.env` (SQL enable in Supabase) |

**Flutter mein kabhi mat daalo:** `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `JWT_SECRET`

---

## Phase 5 — step-by-step key paste

Phase 4 complete hone ke **baad**, jab payments / notifications wire hon:

| Feature | Keys | Kab paste |
|---------|------|-----------|
| Razorpay payments | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | Payment setup step |
| PhonePe (optional) | `PHONEPE_*` | Jab chuno |
| Google Play billing | `GOOGLE_PLAY_*` | Android subscription step |
| Push notifications | `FIREBASE_*` | FCM setup step |
| Email / OTP | `RESEND_API_KEY` | Email feature step |
| Analytics | `POSTHOG_*` | Analytics step |
| Backend security | `JWT_SECRET`, `ENCRYPTION_KEY` | Backend deploy (random generate) |
| API URL | `FASTAPI_BASE_URL` | Backend deploy |

**Flutter mein sirf:** `RAZORPAY_KEY_ID` (public key) — secret kabhi Flutter mein nahi.

---

## Common mistakes (avoid)

1. Sab keys ek din pehle daal dena — waste + security risk
2. `SUPABASE_SERVICE_ROLE_KEY` Flutter `.env` mein daalna
3. `.env` Git mein commit karna (`.env.example` commit karo, `.env` kabhi nahi)
4. Razorpay / Firebase keys Phase 4 se pehle daalna

---

## Quick checklist

- [ ] `examspark_frontend/.env` exists (created)
- [ ] `examspark_backend/.env` exists (created, phase comments)
- [ ] Optional: Supabase 2 keys pasted for login test
- [ ] Phase 4: paste keys one step at a time when AI says
- [ ] Phase 5: paste payment/notification keys when those features wire

---

## Changelog

| Date | Change |
|------|--------|
| Jul 11, 2026 | Initial ENV_PASTE_TIMELINE.md — founder guide for when to paste keys |
