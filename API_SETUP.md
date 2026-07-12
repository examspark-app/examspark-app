# ExamSpark — API Setup Guide

This file explains every environment variable used in the project.

**Audience:** Founder (non-developer) + Cursor AI + future developers.

**Companion docs:** [`TECH_STACK.md`](TECH_STACK.md) · [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) · [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md) · [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) (**when to paste keys — read this first**)

---

## Rules

- **Never commit** `.env`
- **Always commit** `.env.example`
- All real keys go inside `.env`
- Keep the **same variable names** in Flutter, FastAPI, Supabase Edge Functions, and Cloudflare
- **Never hardcode API keys** in source code
- **Backend-only secrets** (`JWT_SECRET`, `ENCRYPTION_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) must **never** be exposed to Flutter

### Where to paste keys

| App / service | File |
|---------------|------|
| Flutter (Web / Android / iOS) | `examspark_frontend/.env` |
| FastAPI backend | `examspark_backend/.env` |
| Supabase Edge Functions | Supabase Dashboard → Edge Functions → Secrets |
| Cloudflare Workers / R2 | Cloudflare Dashboard → Workers & Pages → Settings → Variables |

---

## Phase 1 — Product Foundation

**No API required.**

Documentation only (IA, wireframes, rules).

---

## Phase 2 — Flutter UI

**No API required.**

UI only. Placeholder data. Existing Supabase login may already use `.env` if configured — that is optional for UI testing.

---

## Phase 3 — UI Polish

**No API required.**

UI polish only (padding, icons, typography, responsive fixes).

---

## Phase 4 — Architecture (Data Layer)

These keys are needed when Supabase SQL, RAG, R2 storage, and live AI pipelines are wired.

### Supabase

**Create project:** [https://supabase.com](https://supabase.com)

**Dashboard path:** Project Settings → API

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

| Variable | Who uses it | Notes |
|----------|-------------|-------|
| `SUPABASE_URL` | Flutter, FastAPI, Edge Functions | Public project URL |
| `SUPABASE_ANON_KEY` | Flutter only | Safe for client apps (with RLS) |
| `SUPABASE_SERVICE_ROLE_KEY` | FastAPI, Edge Functions only | **Never** put in Flutter |

**Used for:** Login · Signup · Database · RLS · Storage metadata

---

### Groq (Speech / Transcription)

**Create API key:** [https://console.groq.com](https://console.groq.com)

```env
GROQ_API_KEY=
GROQ_WHISPER_TURBO_MODEL=whisper-large-v3-turbo
GROQ_WHISPER_STANDARD_MODEL=whisper-large-v3
```

| Variable | Used for |
|----------|----------|
| `GROQ_API_KEY` | Whisper transcription |
| `GROQ_WHISPER_TURBO_MODEL` | Fast transcription (default) |
| `GROQ_WHISPER_STANDARD_MODEL` | Fallback when Turbo fails or audio quality is poor |

**Used for:** Fast transcription · Recording transcription

---

### OpenRouter (LLM + Vision)

**Create API key:** [https://openrouter.ai](https://openrouter.ai)

```env
OPENROUTER_API_KEY=
AI_CHAT_MODEL=qwen/qwen3
AI_REASONING_MODEL=qwen/qwen3
AI_VISION_MODEL=qwen/qwen2.5-vl
AI_FALLBACK_MODEL=qwen/qwen3
```

**Used for:** Ask AI · Notes · Summary · Flashcards · Quiz · Vision / OCR

---

### Tavily (Web Search — last resort)

**Create API key:** [https://tavily.com](https://tavily.com)

```env
TAVILY_API_KEY=
```

**Used for:** Web search **only after RAG** — never answer directly from web.

**RAG priority (mandatory order):**

1. User Library / Notes  
2. Clean Transcript chunks  
3. Teacher Shared content  
4. Tavily Web Search (last resort)

---

### Cloudflare

**Dashboard:** [https://dash.cloudflare.com](https://dash.cloudflare.com)

```env
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_API_TOKEN=
```

**Used for:** Cloudflare APIs (DNS, CDN, Workers)

---

### Cloudflare R2 (Permanent file storage)

**Dashboard:** R2 → Create bucket

```env
R2_BUCKET_NAME=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_PUBLIC_URL=
```

**Used for:** Transcript · Notes · Summary · Flashcards · Mind maps · PDFs · Images · Teacher files · Exports

**Never store permanently:** Raw audio (deleted after Whisper → save transcript)

---

### PostgreSQL Vector (pgvector)

No separate API key. Enable on Supabase PostgreSQL.

```env
PGVECTOR_ENABLED=true
```

**Used for:** RAG vectors (clean transcript chunks + notes + teacher shared notes)

---

### FastAPI (backend URL)

```env
FASTAPI_BASE_URL=
```

| Environment | Example value |
|-------------|---------------|
| Development | `http://localhost:8000` |
| Production | `https://api.examspark.app` |

**Note:** Flutter `app_config.dart` reads `FASTAPI_BASE_URL` first, with `API_BASE_URL` as legacy fallback until all builds migrate.

---

## Phase 5 — Backend (Payments, Notifications, Analytics)

### Razorpay (India — website payments)

**Dashboard:** [https://dashboard.razorpay.com](https://dashboard.razorpay.com)

```env
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
```

**Used for:** Website / web subscription payments

---

### PhonePe (optional)

**Merchant Dashboard**

```env
PHONEPE_MERCHANT_ID=
PHONEPE_SALT_KEY=
PHONEPE_SALT_INDEX=
```

**Used for:** Optional India payment gateway

---

### Google Play Billing (Android subscriptions)

**Google Play Console**

```env
GOOGLE_PLAY_PACKAGE=
GOOGLE_PLAY_LICENSE_KEY=
```

**Used for:** Android in-app subscriptions

---

### Firebase (Push notifications)

**Firebase Console**

```env
FIREBASE_PROJECT_ID=
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
```

**Used for:** Push notifications (FCM)

---

### Resend (Email / OTP)

**Dashboard:** [https://resend.com](https://resend.com)

```env
RESEND_API_KEY=
```

**Used for:** OTP · transactional emails

---

### PostHog (Analytics)

**Dashboard:** [https://posthog.com](https://posthog.com)

```env
POSTHOG_API_KEY=
POSTHOG_HOST=
```

**Used for:** Product analytics

---

### Security (backend only — generate random values)

```env
JWT_SECRET=
ENCRYPTION_KEY=
```

**Rules:**

- Generate long random strings (32+ characters)
- **Backend only** — never expose to Flutter or client apps
- Never commit real values to Git

---

## Quick copy — full `.env.example` templates

See committed templates (safe to share in Git):

- [`.env.example`](.env.example) — **master template** (all variables, empty values)
- [`examspark_backend/.env.example`](examspark_backend/.env.example) — copy this to `examspark_backend/.env`
- [`examspark_frontend/.env.example`](examspark_frontend/.env.example) — client-safe keys only (Flutter)

---

## Important rules (summary)

| Do | Don't |
|----|-------|
| Commit `.env.example` | Commit `.env` |
| Use environment variables everywhere | Hardcode API keys in code |
| Use one standard variable name across all services | Use duplicate or old variable names |
| Keep service-role keys on server only | Put `SUPABASE_SERVICE_ROLE_KEY` in Flutter |

---

## Changelog

| Date | Change |
|------|--------|
| Jul 11, 2026 | Initial API_SETUP.md — phase-gated variable guide (founder request) |
