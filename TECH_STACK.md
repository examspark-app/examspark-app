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

### Speech (founder-locked Jul 12, 2026 — full decision tree)

1. **Default:** Groq Whisper Large v3 **Turbo** ($0.04/hr transcribed) for every recording
2. **Noise handling:** if the input audio is noisy, run a noise-cancellation preprocessing pass first, then transcribe with Turbo as normal
3. **Auto fallback to non-turbo:** if Turbo still returns low confidence after noise-cancellation (via `verbose_json` segment `avg_logprob` / `no_speech_prob`) or the Turbo call errors/times out, automatically re-transcribe with Whisper Large v3 **non-turbo** ($0.111/hr — ~2.8x costlier, same model family so quality gain is real, not marginal). Expected to trigger on a minority of noisy lectures, not routinely.
4. **Cross-talk / random-voice detection:** flag segments where an unexpected extra voice (background chatter, another student talking, overlapping speech) is detected, so Notes generation excludes that content instead of transcribing it as if the teacher/main speaker said it. Phase 5 diarization step — locked as a design requirement, not built yet (no diarization model wired).

### LLM

- Qwen3 32B ($0.29/M input tokens, $0.59/M output tokens) — default for all text generation (Notes, Summary, Quiz, Flashcards, Ask AI)

### Vision (founder-locked Jul 12, 2026 — cost-safe escalation)

- **Default:** Qwen3-VL-**Flash** ($0.05/M input, $0.40/M output) for every Diagram/Image/Math action
- **Escalate to Qwen3-VL-Plus** ($0.20/M input, $1.60/M output) only when Flash's output is low-confidence or unparseable — e.g. a complex multi-step math derivation or an unclear/dense diagram. Escalation should be the rare exception, never the default path, so the cheap model carries the bulk of vision traffic.

### Web Search

- Tavily API
- Ya future own search pipeline

### Real Cost Reference (Jul 2026 pricing — recheck periodically, provider rates change)

| Model | Rate |
|-------|------|
| Whisper Large v3 Turbo | $0.04 / hour transcribed |
| Whisper Large v3 (non-turbo) | $0.111 / hour transcribed |
| Qwen3 32B | $0.29/M input · $0.59/M output tokens |
| Qwen3-VL-Flash | $0.05/M input · $0.40/M output tokens (~256 tokens per 1024×1024 image) |
| Qwen3-VL-Plus | $0.20/M input · $1.60/M output tokens |

Computed real cost per feature (at ~₹87/$1, recheck as INR/USD moves): Ask AI Normal ~₹0.03, Ask AI Deep ~₹0.08, Quiz ~₹0.10, Diagram (Flash) ~₹0.02, Diagram (Plus) ~₹0.07, Record 30–60 min (Turbo STT + notes) ~₹3.1 — see [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) Margin Validation for the full table against charged credits.

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
├── Users/{user_id}/Library/{lecture_id}/   (Transcript, Clean Transcript, Notes, Summary, extras, source PDF/image, rag chunks)
├── Teachers/{teacher_id}/Groups/{group_id}/shared/
└── Exports/{user_id}/
```

Legacy (still readable via Postgres paths): `Library/{user_id}/{lecture_id}/…`  
Canonical builder: `examspark_backend/app/services/r2_storage_service.py` (Session 4).

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
| Jul 2026 | R2 full asset list + folder architecture; Teacher Platform spec |
| Jul 12, 2026 | AI Models: full Speech decision tree (noise-cancellation → confidence-based non-turbo fallback → cross-talk detection) + Vision escalation rule (Flash default, Plus only on low-confidence) + real Jul 2026 pricing reference | Founder `save` |
