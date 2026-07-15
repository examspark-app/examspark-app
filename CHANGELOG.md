# ExamSpark — Changelog

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Format:** Date · What changed · Trigger / phase

---

## Jul 2026

### Study Workspace Ask AI + Groups open UX (Jul 15, 2026)

Library Study Workspace **Ask AI** tab now uses live FastAPI `askAiStream` (+ JSON fallback) via [`workspace_ask_ai_pane.dart`](examspark_frontend/lib/presentation/widgets/workspace_ask_ai_pane.dart). Groups: after Join → auto-open group info; joined cards show **Open group** + Leave. Important pending list: [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md).

### Performance Phase 1 — Fast First Answer (Jul 15, 2026)

Home/Ask: smart route (skip RAG for Home product/general), RAG top-3 + expand, chunk cap 1200, in-process embedding + answer caches (**cache hit = no LLM, credits_charged=0**), parallel index∥credit on Ask AI, `examspark.perf` timing logs. SSE + max_tokens 512 kept. Report: [`PERFORMANCE_PHASE1_REPORT.md`](PERFORMANCE_PHASE1_REPORT.md). No Redis / model change.

### Faster Home / Ask AI replies (Jul 15, 2026)

Normal mode: `max_tokens` **1024 → 512** + brevity user-line (lead with Direct Answer, omit empty sections). Deep mode unchanged (2048). Shared [`ai_speed.py`](examspark_backend/app/constants/ai_speed.py); JSON + SSE. Model slug unchanged — no new `.env` keys.

### Typo-tolerant Ask / Home AI (Jul 15, 2026)

Students who mistype (e.g. `cradit econocmy`) still get a correct answer: shared `typo_intent_rule_block()` in [`language_hint.py`](examspark_backend/app/constants/language_hint.py) is embedded in Home AI + Ask AI system prompts (JSON + SSE). Silent intent fix — no spelling lecture, no new API, credits/language lock unchanged.

### Safe SSE streaming add-on (Jul 15, 2026)

Additive ChatGPT-style token stream: `POST /api/v1/home-ai/stream` + `POST /api/v1/ask-ai/stream`. Existing JSON `/home-ai` and `/ask-ai` **unchanged**. Credits still deduct only on stream `done` (SUCCESS). Flutter Home + RAG modal try stream first, fall back to JSON + typewriter on failure. Helper: `openrouter_stream.py`.

### Language fidelity harden — Phase A (Jul 15, 2026)

English question → English answer even when lecture notes/RAG are Hindi. Hard LANGUAGE RULE + anti-leak on Home AI + Ask AI; per-request language hint via [`language_hint.py`](examspark_backend/app/constants/language_hint.py). **Conversation lock (same day):** first turn Hindi/Bengali locks that chat language; “I want Hinglish” (or answer-in-X) switches. Client passes `conversation_language` on Home/Ask; response returns the resolved lock. Not Translate (8 cr). SSE later shipped as additive `/stream` routes (same day).

### AI thinking + typewriter UX (Jul 15, 2026)

While Home AI / Ask AI wait on FastAPI, show a pulsing **Thinking…** bubble (not a plain spinner). When the full answer arrives, reveal it word-by-word (client typewriter; tap to skip). Errors stay instant. Credits still update on SUCCESS immediately. Shared widgets: `presentation/widgets/ai/`. Wired on Home + RAGChatModal.

### AI Infrastructure Audit saved (Jul 15, 2026)

Codebase-only audit of providers, models, keys, request flows, RAG, web/PYQ (not implemented), credits, and risk notes. No code changes. Canonical report: [`AI_INFRASTRUCTURE_AUDIT.md`](AI_INFRASTRUCTURE_AUDIT.md). Live path: Groq Whisper + OpenRouter (Qwen chat/vision + embeddings); AI bills = two providers.

### answer_source + Confidence on Ask AI / Home AI (Jul 15, 2026)

Server-derived fields on every SUCCESS response: `answer_source` (`RAG` | `PYQ` | `KB` | `WEB` | `MIXED` | `NO_MATCH`) and Ask AI `confidence` (`HIGH` | `MEDIUM` | `LOW`). Values come from retrieval scores — never from LLM text. This build: Ask AI = `RAG`/`NO_MATCH`; Home without open-lecture RAG = `KB` (Internal Knowledge). Flutter Home + RAG modal show e.g. `Source: Notes · Confidence: High`. Analytics DB persistence still pending.

### Success-based credits — Home AI + Ask AI (Jul 15, 2026)

Credits deduct **only** when `status == SUCCESS` (AI finished and returned a non-empty answer). **Free only for technical failures:** API error, timeout, network error, server error, validation error. A completed answer — even "couldn't find in your notes" — **charges** (Ask AI still runs the model on empty RAG). Flutter Home updates balance only on SUCCESS. Tests: `tests/test_success_based_credits.py`.

### Multilingual answer rule — Phase A (Jul 15, 2026)

Home AI + lecture Ask AI prompts now require answering in the student’s question language (Hindi / Hinglish / English / other Indian languages when asked). Same credits — not the Future Translate (8 cr) feature. Hindi UI still Future.

### Session 4 — R2 path polish (Jul 15, 2026)

Canonical R2 layout: `Users/{user_id}/Library/{lecture_id}/…` (was `Library/{user_id}/…`). Helpers for Teachers shared + Exports. PDF/image source files stored under `source/`; `clean_transcript.txt` path written; RAG chunks use new prefix. Legacy paths remain readable via Postgres. Guide: [`examspark_backend/SESSION_4_R2.md`](examspark_backend/SESSION_4_R2.md). Tests: `tests/test_r2_paths.py`.

### PYQ Copyright Policy in AI prompts (Jul 15, 2026)

Locked founder policy in `home_ai_service.py` + `rag_ask_service.py`: never reproduce full copyrighted exam questions/answer keys; PYQ display = metadata only; exact-PYQ request → original practice question on same concept; no verbatim textbook copy. Pending PYQ DB in TODO updated to match.

### Pending list — Home AI follow-ups (Jul 15, 2026)

Documented in `TODO.md` (no code): Home AI study-action chips → FastAPI generate on click; Trusted Web Search (Tavily); PYQ Database. Start only when founder asks.

### Home AI Retrieval & Generation Rules (Jul 15, 2026)

Home AI uses founder Retrieval & Generation Rules (Study Coach: RAG → PYQ → KB → Web order in prompt, honest labels when layers offline). Optional open Study Workspace `lecture_id` enables Priority 1 lecture RAG from Home (HOF-style questions). After each answer, study-action chips show; click = coming soon (no auto-generate). PYQ / Tavily still not live.

### Home AI “Not Found” fix (Jul 15, 2026)

Running uvicorn was still an old process without `POST /api/v1/home-ai`, so Home chat showed FastAPI’s literal `Not Found` and credits did not change. Restarted backend; health now includes `home_ai`. Home chat maps bare `Not Found` to a clear “Restart FastAPI” message.

### Home AI endpoint (Jul 15, 2026)

Logged-in Home chat no longer uses a placeholder. New `POST /api/v1/home-ai` + `home_ai_service.py` with founder education-first prompt and runtime honesty (no fake PYQ / no fake web search). Credits: Ask AI Normal 5 / Deep 12. Flutter `HomeTab` → `LectureService.homeAi()`. Lecture RAG `POST /ask-ai` unchanged. Guest home stays placeholder.

### History refresh on Home + Library (Jul 14, 2026)

IndexedStack kept old lecture lists after upload. Added refresh IconButton on Home and Library top bars; lists also reload when you switch back to that tab. Pull-to-refresh on Library kept.

### StudyWorkspace loads real notes (Jul 14, 2026)

Home/Library history opened `StudyWorkspace` with hardcoded Newton sample text while list titles were real. Wired Summary / Notes / Key Points / Terms to `LectureService.fetchLectureNotes` (same FastAPI+R2 path as notes result). Flashcards / Quiz / Revision / Transcript show honest “not wired yet” copy — no fake Newton content.

### Ask AI Master Prompt + suggestion chips (Jul 14, 2026)

Adopted founder Master RAG Prompt in `rag_ask_service.py` (scoped to notes/summary/key points/terms/transcript — no fake PYQ/web). Added strict rules: education-only refusals, no ChatGPT-style general chat, web/PYQ disabled until built, concise answers. `RAGChatModal` empty state shows 7 suggestion chips that fill the input without auto-send. MCQ/Flashcards intents politely redirect; Generate More extras still pending.

### Session 3 Ask AI / RAG core (Jul 14, 2026)

Founder confirmed smoke test pass. Careful Session 3 (Ask AI only — flashcards/MCQ unchanged on edge):

- SQL: [`session3_rag_match.sql`](examspark_backend/session3_rag_match.sql) — `match_rag_documents` RPC (founder must run once)
- `chunk_service.py`, `embedding_service.py` (OpenRouter `openai/text-embedding-3-small` 1536-dim), `rag_index_service.py` — lazy index on first Ask (upload/process path untouched)
- `POST /api/v1/lectures/{id}/index` — optional index smoke
- Real `POST /api/v1/ask-ai` — Notes → Clean Transcript → grounded Qwen answer; deduct 5/12 after success; precheck balance
- Flutter `RAGChatModal` → FastAPI `askAi()`; Generate More extras still edge
- Tests: chunk unit tests + vision suite — **15 passed**

### Best next Phase 5 method locked (Jul 14, 2026)

Founder asked: after smoke gate, do half-done polish **or** Phase 5 sessions? **Answer locked:** Phase 5 Sessions **3 → 4 → 5 → 6** only — no separate polish grab-bag. Half-done leftovers map into Sessions 4–6 (R2 polish → Session 4, plan-tier → Session 5, payments → Session 6). Session 3 RAG stays **blocked** until founder types `smoke test pass`. Agent deliverable (no RAG code): [`examspark_backend/FOUNDER_SMOKE_AND_NEXT.md`](examspark_backend/FOUNDER_SMOKE_AND_NEXT.md) — smoke checklist + money-safe Cursor habit + ready Sonnet Session 3 handoff prompt. `TODO.md` Gate + Remaining Sessions updated to match.

### Notes result loads from R2 via FastAPI (Jul 14, 2026)

Root cause of "No summary available" after successful upload (audio/PDF/photo): backend correctly saved notes to Cloudflare R2 and only path metadata in Postgres, but `notes_result_screen.dart` read non-existent columns (`short_summary`, `clean_notes`) from Supabase. Minimal flow fix — no schema change:

- `r2_storage_service.py`: `download_text` / `download_json`
- `lecture_service.py`: `get_lecture_notes(user_id, lecture_id)` — ownership check + R2 read
- `lectures.py`: `GET /api/v1/lectures/{lecture_id}/notes` (auth required)
- `lecture_service.dart`: `fetchLectureNotes()` + shared `_requireAccessToken()`
- `notes_result_screen.dart`: fetch notes from FastAPI instead of Supabase content columns
- `qwen_vision_service.py`: one retry on OpenRouter transport/SSL errors (photo upload intermittent `BAD_RECORD_MAC`)

Generate More (MCQ/Flashcards/RAG) still unwired — not part of smoke test.

### Fixed invalid Qwen3 model ID breaking notes generation (Jul 14, 2026)

Root cause of `Exception: Qwen3 (OpenRouter) failed: 400 {'error': {'message': 'qwen/qwen3 is not a valid model ID'...}}` on both audio recordings and PDF uploads (image upload unaffected — separate, already-correct vision model): `examspark_backend/.env` had `AI_CHAT_MODEL=qwen/qwen3` / `AI_REASONING_MODEL=qwen/qwen3` / `AI_FALLBACK_MODEL=qwen/qwen3` — `qwen/qwen3` was never a real OpenRouter model slug. Confirmed via OpenRouter's live catalog and fixed to real slugs:

```
AI_CHAT_MODEL=qwen/qwen3-30b-a3b-instruct-2507
AI_REASONING_MODEL=qwen/qwen3-235b-a22b-2507
AI_FALLBACK_MODEL=qwen/qwen3-30b-a3b-instruct-2507
```

Value-only `.env` change (also fixed the same stale placeholder in `examspark_backend/.env.example` and root `.env.example` so future setups don't hit this) — no code changes. Restarted uvicorn, then verified directly with a new one-off script (`examspark_backend/scripts/verify_notes_generation.py`) calling `generate_notes()` with a real Newton's-laws transcript: got a real `200` back from OpenRouter with correctly parsed `cleanNotes`, `keyPoints`, `shortSummary`, `importantTerms` — confirmed fixed before asking founder to redo the in-app flow.

### Fixed "Invalid token" 401 on every upload (Jul 14, 2026)

The error-surfacing fix above immediately paid off — it revealed a real, previously-hidden bug: every `/api/v1/lectures/process` call was failing auth with `"Invalid token."` `auth_service.py` was verifying the Supabase access token's signature locally against `SUPABASE_JWT_SECRET` from `.env` — fragile by design (breaks if that value drifts from the Supabase dashboard, and can never work on projects using Supabase's newer asymmetric "JWT Signing Keys"). Replaced with `get_supabase_admin().auth.get_user(token)`, which asks Supabase itself to verify the token authoritatively — no local secret to keep in sync, ever again. Verified live: signed in with a real account, called the endpoint with the real token — got a legitimate `400` (bad test PDF content) instead of the old `401 Invalid token`, proving auth now passes. `pytest` still 11/11 passed.

### Real error messages + honest Retry + Recording Setup upload UX (Jul 14, 2026)

Root cause found for "network problem"/"processing failed" always showing regardless of the real reason: `processing_screen.dart` hardcoded one generic message for every `status='error'`, hiding real backend errors (confirmed from uvicorn log: `Failed to load image: cannot identify image file` for a Windows-screenshot upload). Fixed:

- **`schema.sql` / `smoke_test_all_in_one.sql`:** added `lectures.error_message TEXT` column (idempotent `ADD COLUMN IF NOT EXISTS` for the founder's existing DB).
- **`lecture_service.py`:** `_db_set_status` now writes the real exception message whenever status is set to `'error'` (all three pipelines — audio/vision/PDF), and clears it on any non-error status.
- **`processing_screen.dart`:** reads `error_message` from the Realtime payload and shows it verbatim; falls back to the generic message only if none was set. **Retry button** previously did nothing but reset the progress bar — now actually re-calls `invokeProcessing` with the original file bytes (threaded through `/processing` route args from `recorder_screen.dart` / `app_router.dart`).
- **`lecture_service.dart`:** `invokeProcessing` now force-refreshes an expired Supabase session before reading the access token (reduces intermittent 401s seen in longer test sessions); parses FastAPI's `{"detail": ...}` error body into a clean message instead of raw JSON.
- **`recording_setup_screen.dart`:** no longer always shows camera/mic preview + "Start Recording" for a plain PDF/photo/audio upload opened from Home's attach sheet — adapts heading/button to "Add lecture details" / "Continue" when `initialInputMethod` is an upload, not a recording.

### Why-so-many-errors plan implemented (Jul 14, 2026)

Added [`examspark_backend/FOUNDER_SQL_ORDER.md`](examspark_backend/FOUNDER_SQL_ORDER.md) — single SQL run order for founders. Verified `verify_smoke_prereqs.py` ALL CHECKS PASSED; uvicorn health Active. Fixed `qwen_vision_service.py` crash on missing OpenRouter `choices` key. `smoke_test_all_in_one.sql` credits UPDATE removed (trigger-safe). Founder: one JPG in app after SQL step B + backend on :8000.

### Phase 5 smoke test — terminal + grants fix prep (Jul 14, 2026)

Implemented Full Terminal Smoke Test plan (no Session 3). Verified: `pytest` 11 passed; uvicorn health `ExamSpark Backend Active`; Flutter `.env` keys SET; `flutter pub get` + `flutter run -d chrome` started. Root cause of record/upload 42501 expanded: missing PostgREST **table GRANTs** (not just `group_shared_items`) — updated [`group_shared_items_grants_migration.sql`](examspark_backend/group_shared_items_grants_migration.sql) + [`schema.sql`](examspark_backend/schema.sql). Added [`scripts/verify_smoke_prereqs.py`](examspark_backend/scripts/verify_smoke_prereqs.py). Removed debug instrumentation from `lecture_service.dart`. **Founder manual:** run grants SQL in Supabase SQL Editor, then re-run verify script or in-app JPG/record smoke test.

### Phase 5 next-steps gate progress (Jul 14, 2026)

Founder next-steps plan executed carefully (no Session 3 code). Re-checked without printing secrets: R2 four keys SET and `head_bucket` OK; OpenRouter key valid with ~$5 remaining balance; health endpoint still Active. Docs updated in TODO with Done / Pending / Remember-later. Still founder-manual: run `credit_economy_v2_1_migration.sql` in Supabase SQL Editor, then one live Flutter recording/JPG smoke test. Session 3 RAG planning stays blocked until smoke pass.

### Phase 5 setup gate — Auto partial check (founder Jul 13, 2026)

Careful Auto path per pending setup gate plan (no Session 3). Verified without printing secrets: Supabase/Groq/OpenRouter keys SET; all R2 keys EMPTY; Flutter `FASTAPI_BASE_URL` SET. Ran `pytest tests/test_vision_and_gating.py` — 11 passed. Started uvicorn briefly — `GET /` returned `ExamSpark Backend Active` + `live_pipeline_audio_vision`. Live smoke still blocked on founder: OpenRouter $5 credits, Cloudflare R2 paste, credit_economy SQL run, then one recording/JPG.

### Qwen3-VL cross-check — logic OK (founder Jul 13, 2026)

Founder asked for a code review of the Vision Session before live OpenRouter spend. Verified Flash→Plus escalation, tier-before-credits (`plan_199+` for diagram), deduct-after-AI (25 credits either model), PDF→Qwen3 text vs image→VL, and unit tests. **No VL code changes** — logic matches Option A / engineering rules. Known gap unchanged: R2 persist still runs after credit deduction. Next: OpenRouter $5 + R2 + one JPG smoke test.

### Phase 5 proof audit saved (founder Jul 13, 2026)

Founder requested a proof-based audit (no assumptions) before Session 3. Verified from the repo and saved as [`PHASE_5_AUDIT.md`](PHASE_5_AUDIT.md): feature scorecard, routes, SQL, env vars, Founder Manual Setup Steps 1–7, rollback SQL, and completion % derived only from which Phase 5 blocks have code vs stubs. Gate: do not start Session 3 (RAG) until Steps 1–7 succeed once end-to-end. No pipeline code changed in this save.

### Vision Session — Qwen3-VL Flash + Plus escalation (founder Jul 13, 2026)

Built the image/diagram/PDF path on FastAPI (Option A: all 3 models — Qwen3 text + VL-Flash + VL-Plus) without changing credit prices (still 25 for Diagram, 20 for PDF Analysis).

- **`qwen_vision_service.py`:** Flash default; auto-escalate to Plus on HTTP/JSON failure or empty/low-quality Flash notes; same structured notes shape as text pipeline
- **`plan_tier_service.py`:** tier check before credits — Free can PDF text; Diagram needs `plan_199+`; Record needs `plan_499+` (403 feature locked)
- **`lecture_service.py`:** `image_upload` → VL (25 credits after success); `pdf_upload` → pypdf text extract → Qwen3 (20 credits); scanned/image-only PDF → clear 400 (upload JPG/PNG instead)
- **Env:** `AI_VISION_FLASH_MODEL` + `AI_VISION_PLUS_MODEL` (same `OPENROUTER_API_KEY`)
- **Flutter:** document picker returns filename; routes `image_upload` vs `pdf_upload`; Free PDF gating synced in `plan_tier_gating.dart`
- **Tests:** `tests/test_vision_and_gating.py` — 11 passed (escalation + tier-before-credits)

### Phase 5 Sessions 1–2 — FastAPI Docker/Auth skeleton + real lecture pipeline (founder Jul 13, 2026)

First real Phase 5 backend code. Founder approved starting Phase 5 with Sonnet-dependent sessions first (see `phase_5_priority_order` plan) — this covers Session 1 and the core of Session 2.

- **Session 1 — Docker + Auth:** Added `Dockerfile` + `docker-compose.yml` for local dev (hot-reload) and Railway deploy. Added Supabase JWT verification (`app/services/auth_service.py`) — every protected FastAPI route now requires `Authorization: Bearer <supabase_access_token>`, verified with `SUPABASE_JWT_SECRET` (HS256, `aud=authenticated`). Fails closed (500, not silent pass-through) if the secret isn't configured. Tested end-to-end locally: health check, missing-auth 401, valid-auth 200, invalid-token 401, job-status 404.
- **Session 2 — Real pipeline:** Ported the `process-lecture` edge function's audio path to FastAPI: Groq Whisper Turbo transcription with automatic non-turbo fallback (`whisper_service.py`, triggers on API error or >25% of segments showing low `avg_logprob`/high `no_speech_prob`) → Qwen3 32B via OpenRouter for notes/summary/key-points/terms (`qwen_service.py`, Groq doesn't host Qwen3) → server-side credit deduction via `fn_deduct_credits` RPC, charged only after both AI calls succeed → R2 upload of transcript/notes (`r2_storage_service.py`, boto3 S3-compatible) → Postgres path-only metadata (`transcripts.r2_transcript_path`, `notes.r2_notes_path` etc., never the content itself — R2 wiring was pulled forward from Session 4 specifically because Postgres-metadata-only is a hard rule, not a nice-to-have).
- **No raw audio persistence anywhere:** audio arrives as in-memory `UploadFile` bytes, goes straight to Groq, then is discarded when the request ends — satisfies "delete audio after Whisper" by simply never writing it to disk/R2/Supabase Storage at all (simpler than the old edge function's upload-then-delete-from-temp-bucket dance).
- **Flutter switched:** `lecture_service.dart`'s `invokeProcessing()` now POSTs multipart to FastAPI instead of invoking the `process-lecture` Supabase edge function; `recorder_screen.dart` now passes `source_type` + measured `duration_minutes`. Found and fixed a real gap along the way: `AppConfig.resolvedApiBaseUrl` only read the compile-time `--dart-define`, never the runtime `.env` (`FASTAPI_BASE_URL`) like `main.dart` already does for Supabase — added the same dotenv-first bridge.
- **Scope not done this session (flagged, not silently skipped):** the "extras" actions (MCQ/Flashcards/Revision/Answer-Key/Important-Questions) still call the old edge function; PDF/image/document uploads get a clean 400 from FastAPI now instead of being silently mis-processed through the audio pipeline (a pre-existing gap this surfaces rather than fixes — vision pipeline is a separate future session). Uploaded (non-live) audio files bill at a 1-minute/40-credit floor since Flutter doesn't parse audio duration client-side — undercharge-safe.
- Verified locally end-to-end against a fresh venv (server boot, all routes registered, auth flow, JSON-extraction edge cases, R2 fail-closed behavior) — full pipeline run needs the founder's real `GROQ_API_KEY`/`OPENROUTER_API_KEY`/R2 credentials + `SUPABASE_JWT_SECRET`, none of which exist in this sandbox.

### Credit Economy v2.1 — Buy Extra Credits + Fee-Corrected Margins (founder Jul 13, 2026)

Pre-Phase-5 task, done before starting the backend build: added a-la-carte credit top-ups, and corrected the plan margin math to include a payment-gateway/Google-Play fee line that had been missing.

- **Buy Extra Credits (new):** 5 packs — 100/₹25, 500/₹110, 1,000/₹200, 5,000/₹850, 10,000/₹1,500. Per-credit rate always ≥ the cheapest subscription plan's rate so top-ups never undercut subscribing. No teacher commission on these (commission is on recurring subscription price only). Code: `SubscriptionPlans.creditPacks` in [`subscription_plans.dart`](examspark_frontend/lib/core/payments/subscription_plans.dart), `credit_packs` table seeded via [`credit_economy_v2_1_migration.sql`](examspark_backend/credit_economy_v2_1_migration.sql). Live checkout is still Phase 5 Session 6 (Razorpay webhooks) — pricing/catalog only for now.
- **Fee-Corrected Margin Validation:** the existing "Margin after 30% Teacher Commission" table never subtracted the payment gateway / Google Play cut. Added it back in at a **worst-case 15%** (Android in-app) assumption. Result: `plan_199` lands almost exactly at 50% EBITDA target since it has no audio feature (cheap real AI cost) — freed room to bump its credits **1,300 → 1,500**. `plan_499`/`plan_999` land at ~44–48% EBITDA in the worst case (below 50%, driven by the recording feature + the fee) — **flagged as a watch-item, not acted on this round** per founder decision to leave the 30% commission unchanged; recovers to ~70–75% if payments route through Web/Razorpay's ~2% fee instead.
- **Teacher monthly ceiling resized 20,000 → 16,000:** re-validated against a 60hrs/month max-usage assumption (recording + full extras on every lecture + heavy Ask AI) which tops out at ~13,840 credits even in the extreme case — 16,000 keeps a comfortable buffer while tightening the platform's worst-case exposure. Risk-ceiling adjustment only, not a margin change (real teacher AI cost stays ~₹250–300/month either way).
- **Free tier code/DB sync fix:** code and schema still said 50 credits/month even though `CREDIT_ECONOMY.md` locked 75 on Jul 12 — now synced everywhere.
- Docs updated: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md), [`PAYMENT_ARCHITECTURE.md`](PAYMENT_ARCHITECTURE.md), [`examspark-credit-economy.mdc`](.cursor/rules/examspark-credit-economy.mdc), [`PRODUCT_VISION.md`](examspark_frontend/PRODUCT_VISION.md).

### AI Pipeline Cost Strategy locked into docs (founder Jul 12, 2026)

Follow-up founder discussion after the Teacher Commission session below — no new code (no FastAPI/Phase 5 backend exists yet), but the confirmed AI-pipeline decision tree and free-tier economics are now locked into docs so Phase 5 has an exact spec to build against:

- **Speech decision tree** ([`TECH_STACK.md`](TECH_STACK.md) §AI Models): Groq Whisper Large v3 **Turbo** ($0.04/hr) is the default for every recording. If audio is noisy, a noise-cancellation preprocessing pass runs first. If Turbo still returns low confidence (`avg_logprob`/`no_speech_prob`) or errors, auto-fallback to Whisper Large v3 **non-turbo** ($0.111/hr). A cross-talk/random-voice detection step is locked as a Phase 5 diarization requirement (not built) so Notes generation can exclude background chatter/other students' voices from the main lecture content
- **Vision escalation rule:** Qwen3-VL-**Flash** ($0.05/M in, $0.40/M out) stays the default for every Diagram/Image/Math action; escalate to Qwen3-VL-**Plus** ($0.20/M in, $1.60/M out) only when Flash's output is low-confidence/unparseable (complex multi-step math, unclear diagrams) — escalation is the rare exception, not the default path
- **Free tier widened:** PDF Analysis (text-only) moved from ₹199 into Free — real cost is only ~₹0.10–0.20/use with no vision model involved. Free credits bumped **50 → 75/month** (real-cost check: ~₹0.35–0.45/user/month worst case — negligible at scale). Confirmed **monthly**, not daily, reset — a daily reset was modeled and rejected (~30x higher worst-case free-tier cost, ~₹10–13/user/month, for zero revenue)
- **Non-API Actions (Always Free)** codified in [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md): re-reading already-generated Notes/Summary/Transcript/Flashcards/Quiz in Library, browsing Group feed/Progress/Profile, and selecting text — only tapping "Ask AI" and sending costs credits
- **Teacher credits (20,000) validated, unchanged:** a heavy teacher (~20 hrs lecture/month + extras) only uses ~3,000–4,000 credits (~₹90–150 real cost vs ₹1,999 charged) — the 5x headroom is intentional "never run out" positioning for a paying B2B customer, not a cost risk
- **Margin Validation table recomputed** with real Groq/Qwen pricing (was rough estimates) — actual margins came in higher than originally estimated (e.g. Ask AI Normal ~96% vs the old ~80% guess), confirming current credit pricing is safe to keep as-is
- Audio chunking (10–15 min chunks), Ask AI prompt length (~800–1,000 words normal / ~2,000 deep), and RAG-embeds-both-Notes-and-Clean-Transcript were discussed and confirmed as already-correct existing behavior — no doc change needed for those
- Nothing here changes actual pipeline code — Whisper/Qwen API calls, noise-cancellation, and diarization remain unbuilt Phase 5 FastAPI work; today's change is `TECH_STACK.md` + `CREDIT_ECONOMY.md` documentation only

### Teacher Commission + Select-Text-Ask-AI (founder Jul 12, 2026)

Founder discussion on AI cost/profit strategy → two locked decisions + two shipped features:

- **Teacher Commission (30% recurring):** any Group member with an active paid plan (₹199/₹499/₹999) earns their **primary teacher** — the teacher whose Group they most recently joined (`class_memberships.joined_at`) — 30% of that subscription, every month, for as long as both stay active. Attribution rule exists so a student in multiple teachers' Groups doesn't get double-charged against the platform's own margin. Full formula + margin-after-commission math: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) §Teacher Commission; dashboard card spec: [`TEACHER_PLATFORM.md`](TEACHER_PLATFORM.md)
- DB: new `examspark_backend/teacher_commission_migration.sql` — `teacher_profiles.commission_rate` (default `0.30`) + `fn_teacher_estimated_commission(p_teacher_id)` (primary-teacher attribution via `ROW_NUMBER()` over `class_memberships.joined_at`, summed against `user_subscriptions`/`subscription_plans`). **Display-only** — no real payout wiring (stays Phase 5). `schema.sql` updated to match
- `groups_repository.dart` — new `fetchEstimatedCommission()` (RPC call, safe fallback to `0`); `teacher_dashboard_screen.dart` — new "Estimated Commission" card
- **Select text → Ask AI:** new `ask_ai_selectable_text.dart` — a `SelectableText` wrapper whose `contextMenuBuilder` adds an "Ask AI" button next to Copy/Select All. Wired into `notes_result_screen.dart` (Summary/Key Points/Clean Notes/Important Terms) and the Group shared-content viewer in `group_info_screen.dart`. Tapping it opens the existing `RAGChatModal` (now accepts an `initialQuery`) pre-filled with the selected snippet — reuses the existing Ask AI credit costs (5/12 credits) and the existing `process-lecture` `rag` action, no new backend call
- AI routing strategy (Groq Whisper Turbo → non-turbo fallback → Qwen 3 Instruct → Qwen3-VL for diagrams/math) and RAG priority order were confirmed unchanged — already locked in [`TECH_STACK.md`](TECH_STACK.md)

### Teacher Dashboard & Groups refinement (founder Jul 12, 2026)

UI + Postgres metadata for a batch of founder-requested fixes. Everything below is Flutter UI + client-side logic only — real server-side enforcement (RLS blocking joins over the limit, AI certificate check, etc.) is explicitly Phase 5, per the founder's "UI now, backend later" instruction this session.

- **Recording source restriction (fake-teacher prevention):** `lectures.source_type` (`'recorded'` / `'uploaded_audio'` / `'uploaded_document'`) now tracked on every lecture created from `recorder_screen.dart`. `study_workspace.dart` only shows a **"Share to Group"** action when the lecture is the caller's own AND `source_type == 'recorded'` — uploaded audio/PDF/photo lectures stay personal-only, so a teacher account can't pass off an upload as their own live teaching
- **Share to Group:** new `share_to_group_sheet.dart` — pick a content type (Lecture/Notes/Quiz) + which group, then `ClassService.shareItemToGroup()` inserts a real `group_shared_items` row
- **Certificate upload UI:** `teacher_profile_edit_sheet.dart` now really picks an image (`file_picker`) and titles it via a small dialog, instead of a "coming later" snackbar. Saved certs show a **"Pending Review"** status; a `rejected` status (set manually until Phase 5's AI check exists) shows **"Needs Review — Contact Support"** with a tap-through info dialog. `teacher_certificate_model.dart` gained a `status` field; `groups_repository.dart`'s `updateOwnTeacherProfile()` now actually persists certificates to `teacher_certificates` (previously silently dropped — profile save only touched `teacher_profiles`)
- **Group Join Limits:** founder-locked caps — Free=0, ₹199=1, ₹499=3, ₹999=6, Teacher=unlimited. New `SubscriptionPlanDef.maxGroups` + `GroupsRepository.canJoinAnotherGroup()` (reads `fn_user_plan_tier()` + counts `class_memberships`), wired into all 3 join entry points (Groups tab/list card, Group Info screen, "Join a Class" code dialog) via a new `buy_plan_sheet.dart` shown instead of letting an over-the-limit join through
- **Removed "Copy Code":** Teacher Dashboard's group card now shows only a full-width "Share Invite Link" button (`examspark.app/join/{joinCode}`) — matches the format `group_info_screen.dart`'s "Share Group" now also uses (was previously a mismatched `group.id` UUID)
- **Interactive quiz in group feed:** tapping a `quiz` item in Group Info's "Recent Shared Content" opens the existing `MCQQuizView` (A/B/C/D selection) with sample questions in a bottom sheet; other item types (notes/lecture/homework/announcement) open a simple read-only preview sheet
- **Recorder warnings + call-interruption auto-save** (shared by Home tab AND Teacher Dashboard — same `recorder_screen.dart`): new "Planned Duration" chip picker (≤30/30–60/60–90 min) on the Setup screen; a sound (`SystemSound.play`) + dismissible banner warns once the planned duration is reached (recording is **never** auto-stopped); sound + red snackbar on start/stop failures; `WidgetsBindingObserver` detects an app-pause/inactive event (e.g. an incoming call) **during** an active recording and immediately stops+saves the audio *before* the interruption, then shows a "Process Now / Discard" recovery dialog when the app resumes; network/processing failures after handoff to `/processing` now mark the lecture `'error'` so `processing_screen.dart`'s existing retry UI (+ a new alert sound) picks it up instead of spinning forever
- DB: new `examspark_backend/teacher_group_features_migration.sql` (run once) — adds `lectures.source_type`, `teacher_certificates.status`, `subscription_plans.max_groups` (+ backfills founder-locked values); `schema.sql` master copy updated to match for future fresh installs
- Docs: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md) (new "Group Join Limits" section), [`FEATURES_MASTER.md`](FEATURES_MASTER.md) (statuses updated for all features above)

### YouTube Link → Notes — icon + paste-link UI (founder Jul 12, 2026)

- New dedicated icon in `bottom_input_bar.dart`, placed **next to the Record icon** (not buried in the "+" Attach sheet) — founder-requested placement so it's immediately visible
- New `youtube_link_dialog.dart` — tapping the icon opens a dialog: paste a link, basic format validation (`youtube.com/watch`, `youtu.be/`, `youtube.com/shorts/`), shows the credit range and the public-video/1-hour rules before submitting
- Wired into `home_tab.dart` (logged-in users — submits to a "coming soon" message, since the fetch/transcribe backend isn't built yet) and `guest_home_screen.dart` (anonymous visitors — routes to the signup prompt like Record/Attach, since it's not part of the one free question)
- **Founder-locked pricing/limits (this session):** 1-hour hard cap, public videos only (private/unlisted/age-restricted/region-locked rejected), credits anchored to founder's **~₹15/hour** figure → 35 / 65 / 100 credits for ≤20 / 20–40 / 40–60 min (cheaper than Recording since there's no Whisper cost — captions come straight from the video). Added to `credit_costs.dart`, [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md), and [`FEATURES_MASTER.md`](FEATURES_MASTER.md)
- **Not built yet (Phase 5, needs founder OK first):** actual link fetch, caption/transcript extraction (`youtube-transcript-api`), and feeding it into the Notes/Summary/Flashcards/Quiz pipeline — today's change is Flutter UI + docs only, no backend call is made

### Guest trial — "Anonymous try → One Ask AI → Sign up" (founder Jul 12, 2026)

- Implements `PRODUCT_VISION.md` Core User Flow #1 (already decided, not new scope): **`AuthGate` now shows a chat screen to logged-out visitors instead of jumping straight to Login**
- New `guest_home_screen.dart` — same Home = Chat Screen layout (top bar, welcome, `BottomInputBar`) as the real `HomeTab`, but for anonymous visitors: type **one** free question, get **one** placeholder AI reply (same "Phase 4/5" placeholder `HomeTab` already used — no new backend needed)
- After that one reply: a thin "Free question used — Sign Up" banner appears, and sending another message (or tapping Attach/Record, which were never part of the free trial) opens a new `signup_prompt_sheet.dart` bottom sheet instead — "Create Free Account" / "I already have an account"
- `login_screen.dart` — new `startInSignUp` flag (opens straight on the Sign Up tab when coming from "Create Free Account"), and now pops itself after a successful login/signup when it was pushed on top of `GuestHomeScreen` (vs. being `AuthGate`'s direct root content) so the app underneath becomes visible
- After signup, the existing Role Selection → Student Onboarding / Teacher Dashboard flow (above) runs exactly as before — this only changes what a **logged-out** visitor sees first
- No credits, no real AI call, no auth logic changed — guest mode is purely a UI/UX addition in front of the existing (placeholder) chat

### Role selection screen — Student vs Teacher choice after signup (founder Jul 12, 2026)

- New `role_selection_screen.dart` — first screen after a new signup: "I'm a Student" / "I'm a Teacher" cards + a "Skip" button, shown before the student profile-details screen
- **Student** → continues straight into the existing `StudentOnboardingScreen` (username/age/education/subjects)
- **Teacher** → flips `users.role` to `'teacher'` (`SupabaseClient.chooseTeacherRole()`), then jumps directly into the **existing** Teacher Dashboard with its **existing** "Edit Teacher Profile" sheet auto-opened — no new/duplicate teacher-profile form was built, per the "single source of truth" rule
- **Skip** → stays a student with defaults, straight into the app (same as skipping inside the student screen)
- `groups_repository.dart` — `fetchOwnTeacherProfile()` now pre-fills a brand-new teacher's own edit sheet with their real name (from signup) instead of the "Mr. Rohan Sharma" mock, which was confusing right after picking "I'm a Teacher"
- `teacher_dashboard_screen.dart` / `app_router.dart` — new `openEditOnLoad` flag (via `/teacher` route args) auto-opens the edit sheet on first arrival
- `profile_tab.dart` — "Teacher Dashboard" row now only shows for users whose `role` is actually `'teacher'`
- New `core/router/app_navigation.dart` (global `navigatorKey`) so the role screen can hand off to `/teacher` right after `AuthGate` switches to `AppShell`

### Student onboarding screen — profile setup after signup (founder Jul 12, 2026)

- New `student_onboarding_screen.dart` — one screen shown right after a student's first login: avatar colour picker, username, age (scroll wheel picker), education level (chips), subjects of interest (multi-select chips), "Skip" button + "Finish Setup"
- Teachers are **not** shown this screen — they already set up their profile from the Teacher Dashboard, so they're marked onboarded immediately on signup
- `auth_gate.dart` now fetches the user's `role`/`onboarding_completed` after login and routes students who haven't onboarded yet to the new screen before `AppShell` — fails open into the app if the row/columns aren't found (e.g. migration not yet run) instead of blocking login
- DB: `examspark_backend/student_onboarding_migration.sql` (run once) — adds `users.username` (unique), `users.avatar_color`, `users.onboarding_completed`, and a new `student_profiles` table (`age`, `education_level`, `subjects[]`) with owner-only RLS; `schema.sql` master copy updated to match for future fresh installs
- New `SupabaseClient.completeStudentOnboarding()` / `skipStudentOnboarding()`
- New shared constants: `core/constants/subjects.dart` (also now reused by `recording_setup_screen.dart` — no more duplicate subject list), `core/constants/education_levels.dart`, `core/constants/avatar_colors.dart`
- New `StudentProfileModel` (`fromMaps`/`toUsersMap`/`toStudentProfileMap`/`copyWith`)

### Auth UI redesign — Login/Sign Up split + password reset (founder Jul 12, 2026)

- `login_screen.dart` rebuilt: segmented Login/Sign Up toggle (old vs new user flow now unmistakable) instead of two stacked buttons, "Forgot password?" link, real Google "G" mark instead of the generic `g_mobiledata` icon
- New `email_verification_screen.dart` — real page shown after sign-up when Supabase requires email confirmation (was previously just a snackbar, looked like nothing happened)
- New `reset_password_screen.dart` + `update_password_screen.dart` — full forgot-password flow (send link → email → set new password)
- `auth_gate.dart` now listens for Supabase's `passwordRecovery` auth event and routes to `UpdatePasswordScreen` instead of dumping the user into the app
- `supabase_client.dart`: added `resetPasswordForEmail()`, `updatePassword()`, `resendSignUpEmail()`, `isPasswordRecoveryEvent()`
- New `google_logo.dart` — brand-colour Google "G" drawn with `CustomPainter`, no image asset/extra package needed
- Auth logic itself untouched (still Supabase `signInWithPassword`/`signUp`/`signInWithOAuth`) — UI/UX restyle only, per Phase 2 auth rule

### Phase 4 — Architecture / Data Layer (founder Jul 11, 2026)

- Full Supabase schema in `examspark_backend/schema.sql`: teacher platform (`teacher_profiles`, `teacher_certificates`, `teacher_achievements`), group system (`class_folders` extended, `group_shared_items`, `class_memberships`), RAG (`rag_documents` with `source_type`/`chunk_hash`/ivfflat index), R2 path columns, payment tables (schema only)
- Postgres functions: `fn_deduct_credits` (server-enforced credits), `fn_user_plan_tier`, `fn_group_item_access` (join-before/after-share rule)
- Row Level Security policies on all sensitive tables
- Flutter wiring: `GroupsRepository` → real Supabase with mock fallback; `ClassService` join/leave/feed; Teacher Dashboard Students/Groups/Credits real data; `SupabaseClient.deductCredits()` RPC
- Model `fromMap`/`toMap` on GroupModel, TeacherProfileModel, certificates, achievements, suggested teachers
- New [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md) — founder one-run SQL guide
- No FastAPI, no R2 upload, no live AI pipeline — those remain Phase 5

### FOUNDER_MANUAL_SETUP_GUIDE.md — accounts & paste steps (founder Jul 11, 2026)

- Added [`FOUNDER_MANUAL_SETUP_GUIDE.md`](FOUNDER_MANUAL_SETUP_GUIDE.md) — non-developer guide: kaunsa account banana hai, kya copy karna hai, kis file (`.env`) mein paste karna hai, kab karna hai

### ENV_PASTE_TIMELINE.md — when to paste `.env` keys (founder Jul 11, 2026)

- Added [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) — simple founder guide: abhi sirf optional Supabase keys; Phase 4 step-by-step; Phase 5 payments later
- Created `examspark_frontend/.env` (Supabase keys only active; Phase 5 keys commented out) and `examspark_backend/.env` (all keys with phase section comments, empty values) — both gitignored
- Linked from `API_SETUP.md`, `README.md`, `TODO.md`, `PROJECT_WORKING_RULES.md`

### Docs + env alignment sync (founder Jul 11, 2026)

- Updated `README.md`, `PROJECT_ROADMAP.md`, `TODO.md`, `PROJECT_WORKING_RULES.md` — phase status now shows Phases 1B–3 complete, Phase 4 next
- `examspark_backend/main.py` — reads `SUPABASE_SERVICE_ROLE_KEY` (falls back to legacy `SUPABASE_KEY`)
- `examspark_frontend/lib/core/config/app_config.dart` — reads `FASTAPI_BASE_URL` (falls back to legacy `API_BASE_URL`)

### API_SETUP.md — environment variable guide (founder Jul 11, 2026)

- Added [`API_SETUP.md`](API_SETUP.md) — single source of truth for every API key / env variable, grouped by phase (1–5)
- Documents where to get each key, what it is used for, and which file to paste it into (Flutter `.env`, backend `.env`, Supabase secrets, Cloudflare)
- Updated [`examspark_frontend/.env.example`](examspark_frontend/.env.example) and [`examspark_backend/.env.example`](examspark_backend/.env.example) to match canonical variable names
- Added root [`.env.example`](.env.example) — master template with all empty variables (founder-specified list)
- Standardized `SUPABASE_SERVICE_ROLE_KEY` (replaces old backend `SUPABASE_KEY` name in docs/templates)
- Rule: never commit `.env`, always commit `.env.example`, one variable name across Flutter / FastAPI / Edge Functions / Cloudflare

### Phase 3 — UI polish pass (founder Jul 11, 2026)

- Founder approved Phase 3 using GPT-5.5 Medium for small UI polish only — no architecture redesign
- `LoginScreen` polish: added autofill hints, keyboard focus flow, drag-to-dismiss keyboard behavior, password visibility tooltip, logo semantics, and cleaner button/loading formatting. Supabase login/signup logic remained untouched.
- `TeacherDashboardScreen` polish: fixed `_creditBalance` lint by making it final; business metric cards now use a responsive 2/3/4-column grid depending on available width
- Focused analyzer check on polished files passed: `No issues found`
- No backend, Supabase SQL, `.env`, Cloudflare, payments, RAG, or auth logic changes

### Phase 2 — AppShell + 5-tab Flutter UI (founder approved Jul 11, 2026)

- Founder approved Phase 1B wireframes and explicitly requested Phase 2 (Flutter UI), listing: AppShell, 5 bottom tabs, responsive layout, components, theme, dark mode, reusable widgets, animations, Home ChatGPT UI, Study Workspace, Teacher Dashboard, Groups, Library — placeholder data only
- New `AppShell` (`lib/presentation/shell/app_shell.dart`) — single navigation root after login: bottom `NavigationBar` on mobile/tablet, `NavigationRail` on desktop (≥900px). `AuthGate` now shows `AppShell` instead of the old `HomeScreen`; `/home` route updated to match. **Auth logic itself untouched.**
- New shared `StudyWorkspace` widget (`lib/presentation/widgets/study_workspace.dart`) — the core "conversation + Study Workspace" differentiator. 7 tabs (Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI). Opens as a swipe-up bottom sheet on mobile, as a persistent right-side split panel on desktop (`StudyWorkspaceSidePanel`, animated open/close). Placeholder tab content this pass — does not touch or replace the existing `/notes_result` (`NotesResultScreen`) route, which keeps working exactly as before.
- New reusable widgets (`lib/presentation/widgets/`): `AppTopBar`, `CreditsPill`, `BottomInputBar`, `LectureCard`, `ProfileRow` — shared across all 5 tabs for one consistent visual language
- New `Responsive` breakpoint helper (`lib/core/theme/responsive.dart`) — mobile <600, tablet 600–899, desktop ≥900
- New tabs, all under `lib/presentation/screens/`:
  - `home/home_tab.dart` — ChatGPT-style conversation UI (no sidebar). Credits balance + recent lectures are **real** Supabase/`LectureService` data. General chat replies are placeholder (Ask AI backend not wired yet); mic button still opens the real `/recording_setup` flow
  - `library/library_tab.dart` — Recent + Folders (grouped by subject) using **real** `LectureService.getLecturesForUser()` data — honest empty state instead of fake sample lectures
  - `groups/groups_tab.dart` — same `GroupsRepository` + `GroupCard` as the standalone `/groups` screen, embedded without its own back arrow
  - `progress/progress_tab.dart` — placeholder study stats (streak, study time, quiz score, recent activity)
  - `profile/profile_tab.dart` — Subscription · Credits · Storage · Library Size · Teacher Dashboard · Settings · Help · Logout rows; logout calls real `SupabaseClient.signOut()`
- `flutter analyze` — 0 errors, 0 new warnings (20 pre-existing info/warnings untouched)
- **Phase 2 completion pass (same day):** `LoginScreen` restyled with `AppTheme` (auth logic untouched); `TeacherDashboardScreen` gained business metric cards grid (Students · Subscribers · Revenue · Credits · Storage · Groups · Analytics) — placeholder data only
- `lib/presentation/screens/dashboard/home_screen.dart` is no longer referenced by any route — marked in `TODO.md` for removal, **not deleted** pending founder confirmation
- **Not done this pass (still placeholder/not wired):** general Ask AI chat replies, Study Workspace real content (Notes/Summary/Transcript/Flashcards/Quiz/Revision), Settings screen, Storage/Library Size real numbers, Progress real analytics — all Phase 4/5 backend work

### Phase 1B — Core wireframes completion pass (founder Jul 11, 2026)

- Founder asked for a focused 8-10 core wireframe pass while still covering the requested screen list and popups
- Added [`PHASE_1B_CORE_WIREFRAMES.md`](PHASE_1B_CORE_WIREFRAMES.md) — 22 requested screens + 9 requested popups, grouped into 8 core UX areas
- Includes Mobile + Desktop ASCII wireframes for: Home, Library, Groups, Progress, Profile, Study Workspace, Recording, Upload, Notes, Summary, Flashcards, Quiz, Teacher Dashboard, Teacher Profile, Group Information, Create Group, Subscription, Credits, Settings, Splash, Login, Signup
- Includes popup wireframes for: Join Group, Leave Group, Share, Delete, Report, Plan Locked, Credits Low, Upload Options, Confirmation Dialogs
- Includes Phase 1B Completion Report: total screens, total popups, missing items, UX consistency check, navigation consistency check, founder approval checklist
- No Flutter code, widgets, or navigation implementation were added
- **Gate unchanged:** Phase 2 will not start until founder approval

### Phase 1B — Wireframes v2, full 12-point detail (founder Jul 11, 2026)

- Founder asked to continue Phase 1B with a stricter, complete template: every screen now documents **Purpose · Mobile Wireframe · Desktop Wireframe · Header · Navigation · Main Content · Bottom Navigation · Floating Action Button · Bottom Sheet placement · Popup placement · User Journey · Screen relationships**
- [`WIREFRAMES.md`](WIREFRAMES.md) expanded from 22 → **28 screens/states/popups** — added Search Overlay, Notifications Panel, Help/FAQ, Credits Detail, Storage Detail, Library Size Detail (all referenced in `IA_SCREEN_HIERARCHY.md` Profile rows / header icons but not previously drafted)
- Still ASCII-only — no Dart, no widgets, no navigation code, per Phase 1B rule
- Updated `TODO.md` — screen count corrected to 28
- **Gate unchanged:** Phase 2 (`AppShell`, 5-tab navigation) will NOT start until founder approves `WIREFRAMES.md`

### Phase 1B — Low Fidelity Wireframes v1 drafted (founder Jul 11, 2026)

- Founder chose to strictly follow the permanent workflow: no `AppShell`/Flutter code until Phase 1B wireframes are approved
- Added `WIREFRAMES.md` v1 — 22 screens/states, Mobile + Desktop, ASCII-only low-fidelity wireframes (no Dart, no widgets, no navigation code)
- Covers: Splash, Home (empty + inline study block), Sign Up Gate, Study Workspace, Library (+folder), Groups List, Group Info, Progress (student + teacher), Profile, Teacher Dashboard, Settings, Subscription, Auth, and 6 popups
- Updated `TODO.md`, `PROJECT_ROADMAP.md`, `DEVELOPMENT_WORKFLOW.md` — Phase 1B status → "Draft created, awaiting founder approval"
- **Gate:** Phase 2 (`AppShell`, 5-tab navigation) will NOT start until founder approves this document

### Teacher Profile & Group Information System — fast-tracked (founder Jul 11, 2026)

- Founder explicitly fast-tracked this feature straight to Flutter code (skipped 1B wireframe step for this feature only, per founder's own choice when asked)
- New models: `TeacherProfileModel`, `TeacherCertificateModel`, `TeacherAchievementModel`, `GroupModel` (+ `GroupSharedItem`), `SuggestedTeacherModel` — `lib/core/models/`
- New placeholder repository: `GroupsRepository` (`lib/core/data/groups_repository.dart`) — mock data only, TODO comments mark exact Supabase swap points for Phase 4/5
- New screens: `GroupsListScreen`, `GroupInfoScreen` (`lib/presentation/screens/groups/`) — Study Community pattern, WhatsApp-inspired but not a copy, no chat/messaging
- Teacher Dashboard updated with editable public profile card (`TeacherProfileCard` + `TeacherProfileEditSheet`)
- New routes `/groups`, `/group_info`; temporary entry point added on Home top bar (will move into 5-tab `AppShell` once built)
- Did NOT touch Supabase auth, login, or existing recording/lecture logic
- `flutter analyze`: 0 errors, 0 new lints on all new files

### Phase 1 — LOCKED (founder approval)

- Founder declared Phase 1 **LOCKED** Jul 11, 2026
- Locked: Product Vision, IA, Navigation, UX, Components, Rules, Storage, AI Flow, Credits, Teacher/Student flows
- **Rule:** No further Phase 1 doc edits without founder approval
- Phase 2 still blocked until founder says "Phase 2 shuru karo"

### Permanent Development Workflow (founder Jul 11, 2026)

- Added [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md) — official phases 1A–6, model strategy, Sonnet budget
- Added `.cursor/rules/examspark-development-workflow.mdc` — always-on
- **New phase split:** 1A LOCKED · **1B wireframes NEXT** · Phase 2 blocked until 1B approved
- Phases 3–6 added (UI polish, architecture, backend, final polish)
- Permanent unless founder says "Update Development Workflow"

### Additional Permanent Development Rules (founder Jul 11, 2026)

- `PROJECT_WORKING_RULES.md` §13 — manual setup guide, .env rules, feature completion report
- Every code change must end with Manual Setup Checklist + .env Checklist
- Never hide manual work; never auto-delete files; non-developer explanations mandatory

### Pre-Phase 2 — Master Documentation (Complete)

- Added [`FEATURES_MASTER.md`](FEATURES_MASTER.md) — every feature by category with status, screen, dependencies
- Added [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md) — temp, R2, Postgres, vector DB (founder-friendly)
- Added [`APP_FLOW.md`](APP_FLOW.md) — full user journey + mermaid flow diagram
- Updated `README.md`, `ARCHITECTURE.md` — index links
- **Gate:** Phase 2 Flutter UI still blocked — waiting for founder approval

### Phase 2 constraint — Auth reuse (founder rule)

- `PROJECT_WORKING_RULES.md` — keep Supabase auth, reuse login, UI-only changes, backend intact
- `PROJECT_ROADMAP.md` — Phase 2 hard rules updated (no auth rewrite)
- `.cursor/rules/examspark-working-rules.mdc` — always-on auth rule

### Phase 1 — IA + Screen Hierarchy (Complete)

- Added [`IA_SCREEN_HIERARCHY.md`](IA_SCREEN_HIERARCHY.md) — every screen in simple language
- Realigned [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) — Sonnet 5 phase workflow (1–5)
- Phase gate: ask founder before Phase 2 Flutter UI
- **Not started:** Supabase, SQL, RAG, payments (by design)

### Project Core Rules

- Added [`PROJECT_CORE_RULES.md`](PROJECT_CORE_RULES.md) — storage tiers, strict sharing, RAG 4-tier, PYQ, watermark, security
- Updated `TECH_STACK.md`, `TEACHER_PLATFORM.md`, cursor rules

### UX Architecture

- Added [`UX_ARCHITECTURE.md`](UX_ARCHITECTURE.md) — Home chat, Study Workspace hero, 5-tab nav, Library, Groups, Profile
- Study Workspace: desktop split + mobile bottom sheet
- Design process: IA → Nav → Hierarchy → UI

### Product

- Added [`PRD.md`](PRD.md) — full product flow, build order
- Updated [`examspark_frontend/PRODUCT_VISION.md`](examspark_frontend/PRODUCT_VISION.md) — vision filled

### Credit Economy v2

- Updated `CREDIT_ECONOMY.md`, `credit_costs.dart`, `subscription_plans.dart`, backend seeds
- Plans: ₹199 / ₹499 / ₹999 / Teacher; session-based recording costs

### Earlier (scaffold phases 0–5)

- Flutter screens: recorder, processing, notes result, subscription, dashboards
- Supabase schema, edge function interim, payment architecture (no live keys)
- Auth gate, recording services, credit constants v1→v2

---

## How to Log Changes

When completing a task:

1. Add entry here (date + summary)
2. Check off in [`TODO.md`](TODO.md)
3. Update [`PROJECT_ROADMAP.md`](PROJECT_ROADMAP.md) if phase advances
4. Update feature checkboxes in [`FEATURES.md`](FEATURES.md) if applicable
