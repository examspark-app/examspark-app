# ExamSpark — Founder Manual Setup Guide (Keys & Accounts)

> **Aapke liye simple guide** — kaunsa account banana hai, kya copy karna hai, kis file mein paste karna hai, kab karna hai.
>
> **Rule:** Ek din mein sab mat karo. Har phase mein sirf us phase ki cheezein karo.

**Related docs:** [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) · [`API_SETUP.md`](API_SETUP.md)

---

## Pehle samjho — 3 jagah keys jaati hain

| # | Jagah | Kaun si file / dashboard | Example |
|---|-------|--------------------------|---------|
| 1 | **Flutter app** | `examspark_frontend/.env` | Sirf safe keys (login) |
| 2 | **Backend server** | `examspark_backend/.env` | Saari secret keys |
| 3 | **Supabase website** | Dashboard → Edge Functions → Secrets | Groq, OpenRouter, etc. |

**Kabhi mat karo:**
- `.env` GitHub pe upload karna
- Secret keys Flutter `.env` mein daalna

---

## ABHI kya karna hai (Phase 1–3 complete)

### Option A — Sirf app UI dekhna hai (login ke bina)

**Kuch mat karo.** App placeholder data se chalegi.

### Option B — Login test karna hai (recommended)

Sirf **1 account** + **1 file** + **2 keys**.

---

## ABHI — Step by step (Login test)

### Step 1 — Supabase account banao (free)

1. Browser kholo: **https://supabase.com**
2. **Start your project** → Sign up (Google se bhi ho sakta hai)
3. **New project** banao:
   - Name: `ExamSpark` (kuch bhi)
   - Database password: strong password likho — **save karo** (baad mein chahiye)
   - Region: **South Asia (Mumbai)** — India ke liye best
4. Project banne mein **2–3 minute** wait karo

**Verify:** Dashboard khul jaye, left side "Table Editor" dikhe.

---

### Step 2 — Keys copy karo

1. Supabase Dashboard → left side neeche **⚙️ Project Settings**
2. Click **API**
3. Ye 2 cheezein copy karo:

| Dashboard mein naam | `.env` mein variable | Example shape |
|---------------------|----------------------|---------------|
| **Project URL** | `SUPABASE_URL` | `https://xxxxx.supabase.co` |
| **anon public** key | `SUPABASE_ANON_KEY` | lambi string `eyJhbG...` |

**⚠ Mat copy karo abhi:** `service_role` key — ye secret hai, sirf Phase 4 mein backend ke liye.

---

### Step 3 — Kis file mein paste karo

**File path (Cursor / File Explorer):**

```
ExamSpark-Project
  └── examspark_frontend
        └── .env    ← YAHAN paste karo
```

**File kholo** → ye lines update karo:

```env
SUPABASE_URL=https://apna-project-url.supabase.co
SUPABASE_ANON_KEY=apni-anon-key-yahan
```

**Save karo** (Ctrl + S).

---

### Step 4 — App chalao aur verify karo

PowerShell / Terminal mein:

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome
```

**Expected result:**
- Login screen khule
- Email + password se sign in / sign up kaam kare

**Agar error aaye:** `.env` save hua? URL mein `https://` hai? Extra space to nahi?

---

## BAAD MEIN — Phase 4 (jab bolo "Phase 4 shuru karo")

Tab ye accounts **ek ek karke** banenge. Abhi mat banao (paise / time bachao).

| Order | Account kahan banao | Website | Kya paste | Kis file mein |
|-------|---------------------|---------|-----------|---------------|
| 1 | Supabase (already) | supabase.com | `SUPABASE_SERVICE_ROLE_KEY` | `examspark_backend/.env` + Supabase Secrets |
| 2 | Groq | console.groq.com | `GROQ_API_KEY` | `examspark_backend/.env` + Supabase Secrets |
| 3 | OpenRouter | openrouter.ai | `OPENROUTER_API_KEY` | `examspark_backend/.env` + Supabase Secrets |
| 4 | Tavily | tavily.com | `TAVILY_API_KEY` | `examspark_backend/.env` |
| 5 | Cloudflare | dash.cloudflare.com | `CLOUDFLARE_*`, `R2_*` | `examspark_backend/.env` |
| 6 | pgvector | Supabase SQL | `PGVECTOR_ENABLED=true` | koi API key nahi — SQL run karna |

### Phase 4 — Har account ka short guide

#### 1. Supabase (service role — Phase 4)

- **Kab:** Jab database tables + security (RLS) setup ho
- **Kahan se:** Supabase → Project Settings → API → **service_role** (secret)
- **Kahan paste:**
  - `examspark_backend/.env` → `SUPABASE_SERVICE_ROLE_KEY=`
  - Supabase → Edge Functions → Secrets → same key add
- **Flutter mein:** ❌ Kabhi mat daalo

#### 2. Groq (audio → text)

- **Account:** https://console.groq.com → Sign up → API Keys → Create
- **Kab:** Jab recording / transcription live ho
- **Paste:** `GROQ_API_KEY=` in `examspark_backend/.env`
- **Free tier:** Haan, limited free use

#### 3. OpenRouter (AI — Notes, Ask AI, Quiz)

- **Account:** https://openrouter.ai → Sign up → Keys
- **Kab:** Jab Ask AI / Notes generation live ho
- **Paste:** `OPENROUTER_API_KEY=` in `examspark_backend/.env`
- **Models:** `.env` mein already set hain (`qwen/qwen3` etc.)

#### 4. Tavily (web search — last option)

- **Account:** https://tavily.com → API key
- **Kab:** Jab RAG ke baad web search chahiye
- **Paste:** `TAVILY_API_KEY=` in `examspark_backend/.env`

#### 5. Cloudflare R2 (files store — notes, PDF, images)

- **Account:** https://dash.cloudflare.com → Sign up
- **Kab:** Jab files permanently store karni hon (R2 bucket)
- **Steps:** R2 → Create bucket → API tokens → copy keys
- **Paste in `examspark_backend/.env`:**
  - `CLOUDFLARE_ACCOUNT_ID=`
  - `CLOUDFLARE_API_TOKEN=`
  - `R2_BUCKET_NAME=`
  - `R2_ACCESS_KEY_ID=`
  - `R2_SECRET_ACCESS_KEY=`
  - `R2_PUBLIC_URL=`

---

## AUR BAAD — Phase 5 (payments, notifications)

**Phase 4 complete hone ke BAAD.** Abhi skip karo.

| Account | Website | Keys | File |
|---------|---------|------|------|
| Razorpay | dashboard.razorpay.com | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | Backend `.env` (+ public ID in Flutter) |
| PhonePe | merchant portal | `PHONEPE_*` | Backend `.env` (optional) |
| Google Play | play.google.com/console | `GOOGLE_PLAY_*` | Backend `.env` |
| Firebase | console.firebase.google.com | `FIREBASE_*` | Backend `.env` |
| Resend | resend.com | `RESEND_API_KEY` | Backend `.env` |
| PostHog | posthog.com | `POSTHOG_*` | Backend `.env` |

**JWT_SECRET / ENCRYPTION_KEY:** Khud generate karo (random long string) — sirf `examspark_backend/.env` mein.

---

## Visual — kis file mein kya jaata hai

```
examspark_frontend/.env          examspark_backend/.env
┌─────────────────────────┐      ┌──────────────────────────────┐
│ SUPABASE_URL      ✅    │      │ SUPABASE_URL           ✅    │
│ SUPABASE_ANON_KEY ✅    │      │ SUPABASE_SERVICE_ROLE  ✅    │
│                         │      │ GROQ_API_KEY           ✅    │
│ (Phase 5 optional:)     │      │ OPENROUTER_API_KEY     ✅    │
│ RAZORPAY_KEY_ID (public)│      │ TAVILY_API_KEY         ✅    │
│ FASTAPI_BASE_URL        │      │ R2_* / CLOUDFLARE_*    ✅    │
└─────────────────────────┘      │ RAZORPAY_* (Phase 5)   ✅    │
                                 │ FIREBASE_* (Phase 5)   ✅    │
                                 │ JWT_SECRET (Phase 5)   ✅    │
                                 └──────────────────────────────┘

Supabase Dashboard → Edge Functions → Secrets
┌──────────────────────────────┐
│ SUPABASE_SERVICE_ROLE_KEY    │
│ GROQ_API_KEY                 │
│ OPENROUTER_API_KEY           │
└──────────────────────────────┘
```

---

## Timeline — ek nazar mein

| Phase | Accounts banana? | Keys paste? |
|-------|------------------|-------------|
| **Abhi** | Sirf Supabase (agar login test) | Sirf 2 keys in Flutter `.env` |
| **Phase 4** | Groq, OpenRouter, Tavily, Cloudflare | Step-by-step backend `.env` |
| **Phase 5** | Razorpay, Firebase, etc. | Jab payment/notify live ho |

---

## Aapka checklist (print kar sakte ho)

### Abhi (optional)
- [ ] Supabase account bana
- [ ] Project create kiya (Mumbai region)
- [ ] `SUPABASE_URL` copy → `examspark_frontend/.env`
- [ ] `SUPABASE_ANON_KEY` copy → `examspark_frontend/.env`
- [ ] `flutter run -d chrome` — login test pass

### Phase 4 (baad mein — AI guide karega)
- [ ] Supabase SQL tables run
- [ ] `SUPABASE_SERVICE_ROLE_KEY` → backend `.env`
- [ ] Groq account + key
- [ ] OpenRouter account + key
- [ ] Tavily account + key (optional early)
- [ ] Cloudflare R2 bucket + keys

### Phase 5 (aur baad mein)
- [ ] Razorpay merchant account
- [ ] Firebase project (push notifications)
- [ ] Baaki services jab chahiye

---

## Help chahiye?

Cursor mein likho:
- **"Supabase setup step by step"** — login keys ke liye
- **"Phase 4 shuru karo"** — baaki accounts + keys ke liye

Har step ke baad AI **verify checkpoint** dega — "ho gaya?" confirm karo, phir agla step.

---

## Changelog

| Date | Change |
|------|--------|
| Jul 11, 2026 | Founder manual guide — accounts, files, paste timeline |
