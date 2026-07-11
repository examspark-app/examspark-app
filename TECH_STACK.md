# ExamSpark — Tech Stack

> **Saved:** Jul 2026 — founder command `save tech`
> **Status:** Target architecture. Current codebase may differ — see [Current vs Target](#current-vs-target) below.

---

## Current vs Target

| Area | Current codebase (interim) | Target (this doc) |
|------|--------------------------|-------------------|
| AI processing | Supabase Edge Function `examspark_backend/functions/process-lecture/index.ts` | **FastAPI** on Railway |
| File storage | Supabase Storage (`temp-audio`) | **Cloudflare R2** |
| Queue / Cache | Not implemented | **Redis** |
| Deploy | Manual / placeholder | **Docker from day 1** (Railway → VPS/K8s later) |

Edge function = interim. New work should align toward **FastAPI + R2 + Redis** unless founder says otherwise.

---

## Frontend

**Flutter**

- Android
- iOS (future — structure ready now, App Store ~3 months)
- Web
- Same UI everywhere (ChatGPT/Claude style)

Canonical source: `examspark_frontend/lib/`

---

## Backend

**FastAPI (Python)**

- AI integration ke liye best
- Fast
- Async support
- Future own model support

**Docker from day 1** — chahe pehle Railway par deploy karo, Docker-based deployment rakho taaki Railway → VPS ya Kubernetes migrate karna aasaan ho.

---

## Authentication

**Supabase Auth**

- Email
- Google
- Apple (future)

---

## Database

**PostgreSQL (Supabase)** — **metadata only**

- Users · Teacher · Groups · Lecture metadata
- Credits · Subscription · Library metadata
- R2 storage paths · Usage · Payment · Analytics

**Never store large files in PostgreSQL.** Full spec: [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md)

---

## Storage

**Cloudflare R2** — permanent assets only

**Temporary (delete after processing):** Raw audio · temp AI files · temp OCR · upload cache

**Permanent R2:**

- Clean Transcript · User Transcript (Library)
- Notes · Summary · Flashcards · Quiz · MCQ · Revision · Formula · Mind Map (future)
- PDF · Images · Teacher Shared Files

**Do not store raw audio permanently** — delete after processing. Teacher opt-in exception only.

---

## Vector Database (RAG)

**pgvector (Supabase PostgreSQL)**

**Store ONLY embeddings for:**

- Clean Transcript chunks
- AI Notes chunks
- Teacher Shared Notes chunks

**Do NOT vectorize:** Raw audio · raw image/PDF binaries

**RAG search priority** (mandatory order — never skip):

1. **User Notes**
2. **Transcript** (Clean Transcript chunks)
3. **Teacher Shared Content**
4. **Web Search** (Tavily)

PYQ = topic mapping tags only — never direct answers. See [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md)

---

## AI Models

### Speech

- Groq Whisper Large v3 Turbo
- Auto fallback: Whisper Large v3

### LLM

- Qwen 3 Instruct

### Vision

- Qwen3-VL

### Web Search

- Tavily API
- Ya future own search pipeline

---

## Queue

**Redis**

Use:

- Background Notes
- AI Jobs
- Retry

---

## Cache

**Redis**

Cache:

- Ask AI
- Web Search
- Notes

---

## Payments

| Region | Provider |
|--------|----------|
| India | Razorpay |
| International | Stripe (future) |

---

## Notifications

**Firebase Cloud Messaging (FCM)**

---

## Analytics

**PostHog**

Track:

- Feature usage
- Credits
- Conversion
- Retention

---

## Hosting

### Backend / API

- **MVP:** Railway (Docker)
- **Later:** Hetzner VPS, Contabo VPS

### Flutter Web

- **Cloudflare Pages**

### CDN + DNS

- **Cloudflare**

---

## Monitoring

- Sentry
- Better Stack

---

## Admin Panel

**Flutter Web** — same design as main app

---

## Architecture

```text
Flutter App
        │
        ▼
Cloudflare
        │
        ▼
FastAPI
        │
 ┌──────┼─────────────┐
 │      │             │
 ▼      ▼             ▼
Postgres Redis      R2 Storage
 │
 ▼
pgvector
 │
 ▼
Qwen
Whisper
Qwen-VL
```

---

## User Library & Cloudflare R2

**Transcripts saved permanently** — users re-read original explanation. **Raw audio deleted** after processing (default).

### R2 — Permanently store

```
Transcript · Clean Transcript · Notes · Summary · Flashcards · Quiz · MCQ
Mind Map · Revision Notes · Formula Sheet · PDF · Images · Teacher Files
User Library · Exports
```

### R2 — Do NOT store (default)

```
Raw Audio
```

**Teacher exception (saved Jul 2026):** Settings → `☐ Save Original Audio` — **default OFF**. Teacher opt-in only.

### Processing flow

```text
Audio → Whisper → Transcript → Delete Audio → Save Transcript (R2)
→ Generate Notes → Save Notes (R2)
```

### R2 folder architecture

```text
Cloudflare R2
├── Users
├── Library/          (Transcript, Notes, Summary, Flashcards, Quiz, Revision, MindMap, Formula, Images, PDFs)
├── Teachers/         (Groups, Shared Notes, Shared PDFs, Shared Files)
└── Exports
```

### Library UI (user-facing)

```text
📁 Physics → Lecture 12 → Transcript | Notes | Summary (+ extras when generated)
```

| Asset | R2 | Purpose |
|-------|-----|---------|
| Transcript | Yes | Original explanation |
| Clean Transcript | Yes | RAG embeddings (#2 priority) |
| Notes / Summary / Extras | Yes | Study + RAG (#1) |
| Raw Audio | **No** | Delete after Whisper |

### RAG vs Library

- Library read = free (no credits)
- Ask AI = credits; order: Notes → Clean Transcript → Web Search

### Teacher platform

Full spec: [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md) — business dashboard, student access logic, group analytics.

---

## Deployment Flow

```text
Flutter App
    ↓
Play Store + Flutter Web (Cloudflare Pages)
    ↓
FastAPI (Railway, Docker)
    ↓
Supabase (Postgres + Auth + pgvector)
    ↓
Cloudflare R2
    ↓
Groq (Whisper) + Qwen (LLM + VL)
```

---

## Scale Path (After 1 Lakh+ Users)

Move gradually:

- Railway → Dedicated VPS
- Managed Redis → Self-hosted Redis
- API models → Your own Qwen server (GPU)
- pgvector → Dedicated PostgreSQL cluster
- Background workers → Multiple worker nodes

---

## Technology Ratings

| Technology | Choice | Rating |
|------------|--------|--------|
| App | Flutter | ⭐⭐⭐⭐⭐ |
| Backend | FastAPI | ⭐⭐⭐⭐⭐ |
| Database | PostgreSQL (Supabase) | ⭐⭐⭐⭐⭐ |
| RAG | pgvector | ⭐⭐⭐⭐⭐ |
| Storage | Cloudflare R2 | ⭐⭐⭐⭐⭐ |
| Queue | Redis | ⭐⭐⭐⭐⭐ |
| AI | Qwen 3 + Qwen3-VL + Groq Whisper | ⭐⭐⭐⭐⭐ |
| Hosting (MVP) | Railway | ⭐⭐⭐⭐☆ |
| Hosting (Scale) | Hetzner VPS + Docker | ⭐⭐⭐⭐⭐ |
| CDN | Cloudflare | ⭐⭐⭐⭐⭐ |
| Payments | Razorpay | ⭐⭐⭐⭐⭐ |

---

## Changelog

| Date | Change |
|------|--------|
| Jul 2026 | Initial tech stack saved (founder `save tech`) |
| Jul 2026 | User Library: save transcript for users; RAG priority Notes → Clean Transcript → Web Search | Founder `save` |
| Jul 2026 | PRD + UX Architecture (Home, Library, Groups, Study Workspace, 5-tab nav) | Founder `save all` |
| Jul 2026 | Project Core Rules — storage, sharing, RAG, PYQ, watermark, security | Founder `save all` |
| Jul 2026 | R2 full asset list + folder architecture; Teacher Platform spec | Founder `save` |
