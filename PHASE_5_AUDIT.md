# Phase 5 Audit — Proof from Codebase (No Assumptions)

> **Date:** Jul 13, 2026  
> **Rule:** Read actual files only — no summary guesses.  
> **Gate:** Do **not** start Session 3 (RAG + pgvector) until Founder Manual Setup Steps 1–7 succeed once end-to-end.

Classifications:
- **Fully implemented** — code present (and unit-tested where noted)
- **Needs manual setup** — code present; keys / SQL / URL required before live use
- **Not implemented** — no working code path
- **Placeholder only** — stub / TODO / returns fake data

---

## Credit Packs

**Status: Needs manual setup** (catalog in code + SQL; live purchase = Not implemented)

| Pack ID | Credits | Price |
|---------|---------|-------|
| `pack_100` | 100 | ₹25 |
| `pack_500` | 500 | ₹110 |
| `pack_1000` | 1,000 | ₹200 |
| `pack_5000` | 5,000 | ₹850 |
| `pack_10000` | 10,000 | ₹1,500 |

**Where stored:**
- Flutter: `examspark_frontend/lib/core/payments/subscription_plans.dart` → `SubscriptionPlans.creditPacks`
- SQL seed: `examspark_backend/schema.sql` (`credit_packs` INSERT)
- Migration upsert: `examspark_backend/credit_economy_v2_1_migration.sql`

**Not live:** `examspark_backend/app/services/payment_orchestrator.py` still has `# TODO: load from credit_packs table` and returns `0` for pack amount. Checkout = Session 6.

**Plans also updated:** Free 75 · plan_199 1,500 · teacher 16,000 (same Dart + SQL + migration).

---

## Docker

**Status: Fully implemented** (files exist)

| File | Fact |
|------|------|
| `examspark_backend/Dockerfile` | CMD: `uvicorn main:app --host 0.0.0.0 --port ${PORT}` |
| `examspark_backend/docker-compose.yml` | service `api`, `8000:8000`, `--reload` |
| `examspark_backend/.dockerignore` | present |

**Startup (no Docker):** `cd examspark_backend` → `pip install -r requirements.txt` → `uvicorn main:app --host 0.0.0.0 --port 8000`  
**Startup (Docker):** `cd examspark_backend` → `docker compose up`

---

## Authentication

**Status: Needs manual setup** (`SUPABASE_JWT_SECRET` in `.env`)

**File:** `examspark_backend/app/services/auth_service.py`
- HS256 JWT; secret `SUPABASE_JWT_SECRET` or `JWT_SECRET`; audience `authenticated`
- Dependency: `get_current_user`

**Protected routes only:**
- `POST /api/v1/lectures/process`
- `GET /api/v1/lectures/jobs/{job_id}`

**Not implemented:** payments / admin routers do **not** use `get_current_user`.

---

## Whisper

**Status: Needs manual setup** (`GROQ_API_KEY`)

**File:** `examspark_backend/app/services/whisper_service.py`
- Turbo: POST `https://api.groq.com/openai/v1/audio/transcriptions`
- Fallback to non-turbo if Turbo errors **or** >25% segments poor (`avg_logprob` / `no_speech_prob`)

---

## Qwen text

**Status: Needs manual setup** (`OPENROUTER_API_KEY`)

**File:** `examspark_backend/app/services/qwen_service.py`
- Prompt: `_NOTES_SYSTEM_PROMPT` → `cleanNotes`, `keyPoints`, `shortSummary`, `importantTerms`
- Request: OpenRouter `https://openrouter.ai/api/v1/chat/completions`, model `AI_CHAT_MODEL`
- Parser: `_extract_json_object`

---

## Qwen vision (Flash / Plus)

**Status: Needs manual setup** (unit-tested in repo)

**File:** `examspark_backend/app/services/qwen_vision_service.py`
- Flash first → auto Plus on HTTP/parse fail or empty/unusable notes
- Wired for `image_upload` in `lecture_service.py`

**Tests:** `examspark_backend/tests/test_vision_and_gating.py` (11 tests — escalation + Free blocked for diagram)

---

## Credits deduction

**Status: Fully implemented** (order in lecture pipelines)

**File:** `examspark_backend/app/services/lecture_service.py`  
**RPC:** `examspark_backend/app/services/credits_service.py` → `fn_deduct_credits`

**Order (audio):** Whisper → Qwen3 notes → **`deduct_credits`** → R2 persist  
Same for vision/PDF: AI first, then deduct.

**Known gap:** if R2 fails after deduct, credits are already gone (flagged in backend engineering rules).

**Tier before credits:** `examspark_backend/app/services/plan_tier_service.py` — Free PDF OK; diagram `plan_199+`; record `plan_499+`.

---

## Cloudflare R2

**Status: Needs manual setup** (R2 bucket + keys)

**File:** `examspark_backend/app/services/r2_storage_service.py`  
Uploads: `transcript.txt`, `notes.json`, `summary.txt`, `key_points.json`, `important_terms.json` under `Library/{user_id}/{lecture_id}/`

**Postgres paths only:** `lectures.r2_folder_path`, `transcripts.r2_transcript_path`, `notes.r2_*_path` — no content columns in persist path.

---

## Audio

**Status: Fully implemented** (this FastAPI path)

- Router: `await file.read()` → memory only
- Whisper: multipart bytes to Groq — no tempfile / no R2 audio upload
- R2: text/JSON only

---

## Flutter → FastAPI

**Status: Needs manual setup** (`FASTAPI_BASE_URL` in frontend `.env`)

| Method | Target |
|--------|--------|
| `invokeProcessing` | FastAPI `POST /api/v1/lectures/process` multipart + Bearer |
| `invokeExtra` | **Still** Supabase edge `process-lecture` — Not migrated |

**Recorder API source types:** `recording` / `audio_upload` / `pdf_upload` / `image_upload`  
**File:** `examspark_frontend/lib/presentation/screens/recording/recorder_screen.dart`

---

## Live routes (code)

| Method | Path | Auth |
|--------|------|------|
| GET | `/` | public |
| POST | `/api/v1/lectures/process` | JWT |
| GET | `/api/v1/lectures/jobs/{job_id}` | JWT |
| POST | `/api/v1/ask-ai` | Placeholder only |
| `/api/v1/payments/*` | stubs | Placeholder / Not live |

---

## SQL

**File:** `examspark_backend/credit_economy_v2_1_migration.sql`

| Change | Detail |
|--------|--------|
| Updates | `subscription_plans.monthly_credits` for `free`, `plan_199`, `teacher` |
| Upserts | 5 rows in `credit_packs` |
| New tables | None (`credit_packs` already in `schema.sql`) |

**Rollback:**
```sql
UPDATE subscription_plans SET monthly_credits = 50 WHERE id = 'free';
UPDATE subscription_plans SET monthly_credits = 1300 WHERE id = 'plan_199';
UPDATE subscription_plans SET monthly_credits = 20000 WHERE id = 'teacher';
DELETE FROM credit_packs WHERE id IN ('pack_100','pack_500','pack_1000','pack_5000','pack_10000');
```

---

## Environment variables (backend `.env`)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | DB + admin client |
| `SUPABASE_SERVICE_ROLE_KEY` | server writes / RPC |
| `SUPABASE_JWT_SECRET` | verify Flutter Bearer tokens |
| `GROQ_API_KEY` | Whisper |
| `OPENROUTER_API_KEY` | Qwen3 + VL |
| `AI_CHAT_MODEL` | text model |
| `AI_VISION_FLASH_MODEL` | VL Flash |
| `AI_VISION_PLUS_MODEL` | VL Plus |
| `CLOUDFLARE_ACCOUNT_ID` | R2 |
| `R2_BUCKET_NAME` | R2 |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | R2 |

**Frontend `.env`:** `FASTAPI_BASE_URL=http://localhost:8000` (uncomment)

---

## Feature scorecard

| Feature | Status |
|---------|--------|
| Credit pack catalog | Needs manual setup (run migration) |
| Credit pack live purchase | Not implemented |
| Docker files | Fully implemented |
| JWT on lecture routes | Needs manual setup |
| Whisper Turbo + fallback | Needs manual setup |
| Qwen3 notes | Needs manual setup |
| Qwen3-VL Flash→Plus | Needs manual setup (+ tests in repo) |
| Credits after AI success | Fully implemented |
| R2 + Postgres paths | Needs manual setup |
| Audio never permanent | Fully implemented |
| Flutter `invokeProcessing` → FastAPI | Needs manual setup |
| Flutter `invokeExtra` → FastAPI | Not implemented |
| Ask AI / RAG / pgvector | Placeholder / Not implemented |
| Razorpay live webhooks | Placeholder / Not implemented |
| Payments JWT | Not implemented |

---

## Founder Manual Setup

### Step 1 — Run credit economy SQL

Open: [https://supabase.com/dashboard](https://supabase.com/dashboard) → your ExamSpark project → **SQL Editor** → **New query**

Paste: full contents of `examspark_backend/credit_economy_v2_1_migration.sql`

Click: **Run**

Expected Result: success. Then run:
```sql
SELECT id, monthly_credits FROM subscription_plans ORDER BY price_inr_paise;
SELECT id, credits, price_inr_paise FROM credit_packs ORDER BY credits;
```
Expect Free=75, plan_199=1500, teacher=16000, and 5 packs.

### Step 2 — Supabase JWT Secret

Open: Supabase → **Project Settings** → **API** → **JWT Settings**

Copy: **JWT Secret** (not anon, not service_role)

Paste into: `examspark_backend/.env` → `SUPABASE_JWT_SECRET=`

Expected Result: saved; file stays gitignored.

### Step 3 — Groq key

Open: [https://console.groq.com](https://console.groq.com) → API Keys → Create

Paste into: `examspark_backend/.env` → `GROQ_API_KEY=`

### Step 4 — OpenRouter key

Open: [https://openrouter.ai](https://openrouter.ai) → Keys → Create

Paste into: `examspark_backend/.env` → `OPENROUTER_API_KEY=`

Confirm:
- `AI_VISION_FLASH_MODEL=qwen/qwen3-vl-8b-instruct`
- `AI_VISION_PLUS_MODEL=qwen/qwen3-vl-235b-a22b-instruct`

(Adjust slugs if OpenRouter dashboard shows different names.)

### Step 5 — Cloudflare R2

Open: [https://dash.cloudflare.com](https://dash.cloudflare.com) → **R2** → Create bucket (e.g. `examspark-library`)

Create API token: R2 → Manage R2 API Tokens → Create (read/write on bucket)

Paste into `examspark_backend/.env`:
- `CLOUDFLARE_ACCOUNT_ID=`
- `R2_BUCKET_NAME=`
- `R2_ACCESS_KEY_ID=`
- `R2_SECRET_ACCESS_KEY=`

### Step 6 — Flutter → local backend

Open: `examspark_frontend/.env`

Change `# FASTAPI_BASE_URL=http://localhost:8000` to:
`FASTAPI_BASE_URL=http://localhost:8000`

### Step 7 — Smoke test

Terminal:
```
cd examspark_backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Browser: `http://localhost:8000/`  
Expected: `"status": "ExamSpark Backend Active"` and lectures pipeline flag.

Then Flutter: log in → short record **or** JPG upload (₹199+ for image).  
Expected: lecture `done`, credits drop, Library shows lecture.

### Rollback

- Code: restore unwanted files via git (no force-push).
- SQL: use rollback block in SQL section above.
- Keys: blank them in `.env` and stop uvicorn.

---

## Final Status (facts only)

| Metric | Verified |
|--------|----------|
| Phase 5 overall | Partially done — Task 0 + Session 1 + Session 2 core + Vision coded; Sessions 3–6 not done |
| Phase completion | ~35–40% of planned Phase 5 blocks |
| Backend | ~45% (Docker/auth/lecture/vision/R2 path; no RAG/live payments/extras) |
| Flutter | ~30% (`invokeProcessing` migrated; extras still edge) |
| AI pipeline | ~70% core (audio + notes + vision; no RAG Ask AI / extras / diarization) |
| Payments | ~10% (stubs + catalog; no live webhooks) |
| Remaining Sonnet-heavy | Session 3 (RAG) |
| Remaining Auto/GPT-friendly | Sessions 4–6 |

**Recommendation:** Complete Steps 1–7 and one successful end-to-end lecture before Session 3.
