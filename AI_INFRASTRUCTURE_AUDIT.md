# ExamSpark AI Infrastructure Audit (codebase facts only)

> **Audit date:** Jul 15, 2026  
> **Scope:** [`examspark_backend/`](examspark_backend/) + Flutter AI call sites  
> **Method:** Source + config inspection only. Secret values not inspected or printed.  
> **Rule:** If something is absent in code → **Not implemented.** If env exists but unused → **Configured but not currently used.**

---

## 1. AI Providers

### Live FastAPI (primary)

| Provider | Status | Actual endpoint in code |
|----------|--------|-------------------------|
| **OpenRouter** | Used | `https://openrouter.ai/api/v1/chat/completions` — [`qwen_service.py`](examspark_backend/app/services/qwen_service.py), [`qwen_vision_service.py`](examspark_backend/app/services/qwen_vision_service.py), [`home_ai_service.py`](examspark_backend/app/services/home_ai_service.py), [`rag_ask_service.py`](examspark_backend/app/services/rag_ask_service.py) |
| **OpenRouter** | Used | `https://openrouter.ai/api/v1/embeddings` — [`embedding_service.py`](examspark_backend/app/services/embedding_service.py) |
| **Groq** | Used | `https://api.groq.com/openai/v1/audio/transcriptions` — [`whisper_service.py`](examspark_backend/app/services/whisper_service.py) |

### Explicitly Not implemented (no client code)

| Provider | Status |
|----------|--------|
| OpenAI direct (`https://api.openai.com/v1`) | Not implemented |
| xAI / Grok (`https://api.x.ai/v1`) | Not implemented |
| Gemini | Not implemented |
| Anthropic | Not implemented |
| Ollama | Not implemented |
| Tavily / SerpAPI / Brave web search | Not implemented |

Note: OpenAI appears only as an OpenRouter **model slug** (`openai/text-embedding-3-small`), not as a direct OpenAI SDK/host.

### Legacy (still in repo)

| Provider | Endpoint | File |
|----------|----------|------|
| Groq | transcriptions + chat completions | [`functions/process-lecture/index.ts`](examspark_backend/functions/process-lecture/index.ts) |

Flutter does **not** call any AI vendor URL ([`app_config.dart`](examspark_frontend/lib/core/config/app_config.dart) → FastAPI base URL only).

---

## 2. Models

Defined in [`config.py`](examspark_backend/app/config.py) `AIConfig` + [`examspark_backend/.env.example`](examspark_backend/.env.example).

| Model (env / default) | Where used |
|-----------------------|------------|
| `GROQ_WHISPER_TURBO_MODEL` default `whisper-large-v3-turbo` | Lecture audio transcription ([`whisper_service.py`](examspark_backend/app/services/whisper_service.py)) |
| `GROQ_WHISPER_STANDARD_MODEL` default `whisper-large-v3` | Whisper auto-fallback on low confidence / turbo error |
| `AI_CHAT_MODEL` — `.env.example`: `qwen/qwen3-30b-a3b-instruct-2507`; code default `qwen/qwen3` | Home AI, Ask AI, lecture notes from transcript/PDF text ([`home_ai_service.py`](examspark_backend/app/services/home_ai_service.py), [`rag_ask_service.py`](examspark_backend/app/services/rag_ask_service.py), [`qwen_service.py`](examspark_backend/app/services/qwen_service.py)) |
| `AI_EMBEDDING_MODEL` = `openai/text-embedding-3-small` (1536-dim) | RAG index + query embeddings ([`embedding_service.py`](examspark_backend/app/services/embedding_service.py)) |
| `AI_VISION_FLASH_MODEL` = `qwen/qwen3-vl-8b-instruct` | Image / diagram lecture notes (default) ([`qwen_vision_service.py`](examspark_backend/app/services/qwen_vision_service.py)) |
| `AI_VISION_PLUS_MODEL` = `qwen/qwen3-vl-235b-a22b-instruct` | Vision auto-escalation when Flash notes unusable |
| `AI_FALLBACK_MODEL` | Loaded in config — **Configured but not currently used** for request routing |
| `AI_REASONING_MODEL` | In `.env.example` only — **Configured but not currently used** (not in `AIConfig`) |

### Feature map

| Feature | Model path | Status |
|---------|------------|--------|
| Home AI | OpenRouter `AI_CHAT_MODEL` (+ optional RAG embed) | Implemented |
| Ask AI (lecture RAG) | Embed + OpenRouter `AI_CHAT_MODEL` | Implemented |
| Summary / Notes / Key points (audio/PDF) | Whisper (audio) + OpenRouter chat | Implemented |
| OCR / Diagram (image upload) | OpenRouter Qwen3-VL Flash→Plus | Implemented (not a separate OCR route) |
| Flashcards / Quiz / Mind Map / Revision (FastAPI) | — | **Not implemented** |
| Same extras via Supabase edge `process-lecture` | Groq Whisper + Groq `qwen-2-*` hardcodes | Legacy path; Flutter `invokeExtra` can still hit it |

---

## 3. API Keys

| Env var | Configured in code? | Runtime use |
|---------|---------------------|-------------|
| `GROQ_API_KEY` | Yes — `AIConfig` | Used (Whisper) |
| `OPENROUTER_API_KEY` | Yes — `AIConfig` | Used (chat / vision / embeddings) |
| `GROQ_WHISPER_*_MODEL` | Yes | Used |
| `AI_CHAT_MODEL`, `AI_EMBEDDING_MODEL`, `AI_VISION_*` | Yes | Used |
| `AI_FALLBACK_MODEL` | Yes in `AIConfig` | Configured but not currently used |
| `AI_REASONING_MODEL` | `.env.example` only | Configured but not currently used |
| `TAVILY_API_KEY` | `.env.example` only — **not** in `config.py` | Configured but not currently used / Missing from runtime |
| `OPENAI_API_KEY`, `XAI_API_KEY`, `GEMINI_API_KEY`, etc. | Absent | Not implemented |

Whether a founder’s local `.env` has non-empty values cannot be asserted here without printing secrets — this audit reports **which keys the code reads**.

---

## 4. Request Flow

### Home AI (live)

```text
Flutter HomeTab
  → LectureService.homeAi
  → POST /api/v1/home-ai (FastAPI ask_ai router)
  → home_ai_service: plan gate + credit precheck
  → optional: embed_query (OpenRouter embeddings) + pgvector match
  → OpenRouter chat completions (AI_CHAT_MODEL / Qwen)
  → deduct_credits on SUCCESS
  → Response (+ answer_source, confidence)
```

### Ask AI (live)

```text
Flutter RAGChatModal / askAi()
  → POST /api/v1/ask-ai
  → ensure_lecture_indexed → embeddings → match_rag_documents
  → OpenRouter chat (grounded in notes/transcript)
  → deduct_credits on SUCCESS
```

### Lecture audio (live)

```text
Flutter process multipart
  → POST /api/v1/lectures/process
  → Groq Whisper → OpenRouter Qwen notes
  → deduct_credits → R2 path persist
```

### Lecture image (live)

```text
Flutter process
  → Qwen3-VL via OpenRouter (Flash, maybe Plus)
  → deduct_credits → R2
```

No Flutter → OpenRouter/xAI direct path exists.

---

## 5. Payment Provider (who bills ExamSpark)

| Workload | Who bills ExamSpark |
|----------|---------------------|
| Whisper (turbo / standard) | **Groq** (`GROQ_API_KEY`) |
| Chat / notes / Ask / Home / vision | **OpenRouter** (`OPENROUTER_API_KEY`) — OpenRouter then routes to underlying model hosts (e.g. Qwen / OpenAI embedding via OpenRouter catalog) |
| Embeddings model slug `openai/...` | Billed through **OpenRouter**, not a separate OpenAI subscription in this codebase |

**Billing = two providers** for the live FastAPI path: Groq + OpenRouter.

Legacy edge extras (if still used): **Groq only**.

Razorpay / PhonePe / Play in [`config.py`](examspark_backend/app/config.py) are **user payment** stubs — not AI vendor billing.

---

## 6. RAG (actual implementation)

| Piece | Fact |
|-------|------|
| Vector DB | **Supabase Postgres + pgvector** — table `rag_documents` ([`schema.sql`](examspark_backend/schema.sql)) |
| Match RPC | [`session3_rag_match.sql`](examspark_backend/session3_rag_match.sql) — similarity = `(1 - (embedding <=> query))` (cosine) |
| Embeddings | OpenRouter `text-embedding-3-small`, 1536 dims ([`embedding_service.py`](examspark_backend/app/services/embedding_service.py)) |
| Chunking | [`chunk_service.py`](examspark_backend/app/services/chunk_service.py) — ~700 chars / 80 overlap, no AI |
| Index | Lazy on first Ask / optional `POST .../index` — [`rag_index_service.py`](examspark_backend/app/services/rag_index_service.py); chunk text in R2, vectors in Postgres |
| Order | Notes first; if fewer than 2 notes hits, Notes + Clean Transcript; else full-notes R2 fallback — [`rag_ask_service.py`](examspark_backend/app/services/rag_ask_service.py) |
| Thresholds | Soft match 0.20, fallback 0.0, top 5 |
| Keyword / hybrid search | **Not implemented** (vector only) |
| Teacher Shared RAG | Schema/RPC allow `teacher_shared` — **not queried** in Python Session 3 |

---

## 7. Web Search

**Not implemented.**

- No Tavily/SerpAPI/Brave HTTP client under `app/`
- `TAVILY_API_KEY` is env placeholder only
- Home/Ask prompts contain honesty text: do not claim web search ran ([`home_ai_service.py`](examspark_backend/app/services/home_ai_service.py), [`rag_ask_service.py`](examspark_backend/app/services/rag_ask_service.py))

When does it execute? **Never** (this build).

---

## 8. PYQ

**Not implemented** as retrieval.

- No `pyq_bank` table / match service in runnable Python
- `exam_pyqs` appears as a schema stub only ([`schema.sql`](examspark_backend/schema.sql))
- Enum value `PYQ` exists in [`answer_source.py`](examspark_backend/app/constants/answer_source.py) but is never derived from a PYQ lookup
- Prompts encode copyright / “bank not available” honesty

---

## 9. Credits (actual code path)

Shared: [`credits_service.deduct_credits`](examspark_backend/app/services/credits_service.py) → Postgres `fn_deduct_credits`.

| Path | When charged | When free |
|------|--------------|-----------|
| Ask AI / Home AI | After non-empty AI answer → `status=SUCCESS` then deduct (including “not found in notes” if model ran) | API/timeout/network/validation/empty answer — raise before deduct |
| Lecture audio | After Whisper + notes succeed | Failures before deduct |
| Image | After vision notes succeed | Failures before deduct |
| PDF | After text notes succeed | Failures / little extractable text before deduct |

Precheck balance may run before OpenRouter; deduct still only after success ([`rag_ask_service.py`](examspark_backend/app/services/rag_ask_service.py), [`home_ai_service.py`](examspark_backend/app/services/home_ai_service.py), [`lecture_service.py`](examspark_backend/app/services/lecture_service.py)).

Known gap (documented in backend engineering rules): R2 persist can run **after** credit deduct on lecture path — R2 failure can leave credits taken.

---

## 10. Advantages

- Single Flutter → FastAPI gate (no client-side vendor keys)
- Success-based AI credits for Home/Ask (fail = free)
- OpenRouter one key for multiple Qwen / embedding models
- Groq isolated to speech (fast Whisper)
- RAG: Postgres metadata + R2 content + pgvector (matches locked architecture)
- Server-derived `answer_source` / `confidence` (not LLM-trusted)
- Plan-tier gating hooks exist server-side for Ask AI feature

---

## 11. Disadvantages / risks

- Dual AI bills (Groq + OpenRouter) + latency of gateway
- `AI_CHAT_MODEL` code default `qwen/qwen3` is an invalid OpenRouter slug unless `.env` overrides ([`config.py`](examspark_backend/app/config.py))
- `AI_FALLBACK_MODEL` / `AI_REASONING_MODEL` / `TAVILY_API_KEY` unused (config drift)
- Flashcards/Quiz/Mind Map not on FastAPI; edge extras still Groq + older model IDs if invoked
- No hybrid search; empty RAG still runs chat and charges
- No analytics persistence for `answer_source` yet
- Post-deduct R2 failure risk on lecture pipeline
- Embedding via OpenRouter adds cost/latency vs local or direct provider

---

## 12. Future Improvements

- Wire Tavily only when needed; set `answer_source=WEB`
- Build PYQ retrieval against `exam_pyqs` / `pyq_bank`; charge appropriately with copyright policy
- Move flashcards/MCQ/revision to FastAPI; retire or freeze edge Groq chat
- Implement real `AI_FALLBACK_MODEL` routing on OpenRouter errors
- Persist `answer_source`/`confidence` for analytics
- Fix deduct-after-persist (or refund) for lecture R2 failures
- Consider cheaper embedding path or caching; Redis for job queue at scale
- Align root `.env.example` with backend Flash/Plus/embedding vars

---

## One-line architecture summary

```text
Flutter → FastAPI → Groq Whisper (audio only)
                  → OpenRouter → Qwen3 chat / Qwen3-VL / OpenAI embeddings
                  → Supabase pgvector RAG (Notes → Clean Transcript)
Web Search: Not implemented
PYQ retrieval: Not implemented
AI billing providers: Groq + OpenRouter (two)
```

---

## Founder how to re-check later

1. Open this file: [`AI_INFRASTRUCTURE_AUDIT.md`](AI_INFRASTRUCTURE_AUDIT.md)
2. Compare against [`examspark_backend/app/config.py`](examspark_backend/app/config.py) and services under `app/services/`
3. Search the repo for new vendor URLs (`api.x.ai`, `api.openai.com`, `tavily`, etc.) — if none appear in Python/Dart clients, status remains **Not implemented**
