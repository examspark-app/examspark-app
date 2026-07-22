# ExamSpark — TODO

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)

**Founder important pending (single list):** [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md)

---

## ✅ Phase 1A — LOCKED 🔒 (founder Jul 11, 2026)

**No further doc edits without founder approval.**

- [x] Product Vision · PRD · IA · Navigation · all flows
- [x] Credits · Storage · Rules · master docs
- [x] `DEVELOPMENT_WORKFLOW.md` — official permanent workflow

**⏸ Phase 5 = NEXT** — ask founder before start.

---

## ✅ API / Environment Setup (COMPLETE — Jul 11, 2026)

- [x] [`API_SETUP.md`](API_SETUP.md) — every env variable by phase
- [x] [`ENV_PASTE_TIMELINE.md`](ENV_PASTE_TIMELINE.md) — founder guide: kab kaunsi keys paste karni hain
- [x] [`.env.example`](.env.example) — master template (empty values)
- [x] [`examspark_backend/.env.example`](examspark_backend/.env.example) — full server keys
- [x] [`examspark_frontend/.env.example`](examspark_frontend/.env.example) — client-safe keys only
- [x] `examspark_frontend/.env` + `examspark_backend/.env` — created with phase comments (empty values, gitignored)

---

## ✅ Phase 1B — Low Fidelity Wireframes (COMPLETE — Jul 11, 2026)

**Model:** Sonnet 5 High · **No Flutter code**

- [x] Mobile wireframes — every screen (28 screens/states/popups)
- [x] Desktop wireframes — every screen (28 screens/states/popups)
- [x] Full 12-point template per screen (Purpose · Mobile · Desktop · Header · Nav · Content · Bottom nav · FAB · Sheet · Popup · User Journey · Screen relationships) — see [`WIREFRAMES.md`](WIREFRAMES.md)
- [x] Founder-requested core pass — 22 requested screens + 9 requested popups, grouped into 8 core UX areas — see [`PHASE_1B_CORE_WIREFRAMES.md`](PHASE_1B_CORE_WIREFRAMES.md)
- [x] Founder approval before Phase 2 (AppShell + Flutter) — founder gave explicit go-ahead Jul 11, 2026

---

## ✅ Phase 2 — Flutter UI (COMPLETE — Jul 11, 2026)

**Founder rules:** Keep Supabase auth · reuse login · UI only · backend connections intact · never rewrite auth unless asked.

- [x] `AppShell` — 5 bottom tabs (kept `AuthGate`, only swapped destination screen)
- [x] Responsive layout — bottom `NavigationBar` (mobile/tablet) / `NavigationRail` (desktop ≥900px)
- [x] Restyle `LoginScreen` — same `_handleLogin` / `_handleSignUp` logic, AppTheme UI
- [x] Home chat layout (`HomeTab` — top bar, conversation, sticky input; real credits/lecture data)
- [x] Home AI via FastAPI `POST /api/v1/home-ai` (education prompt + safety; 5 credits) — Jul 15, 2026
- [x] Home AI Retrieval Rules + optional open-lecture Priority 1 RAG + study-action chips — Jul 15, 2026
- [x] `StudyWorkspace` widget — bottom sheet (mobile) / split panel (desktop), 7 tabs; Notes/Summary wired to FastAPI `fetchLectureNotes` (Jul 14)
- [x] Library · Groups · Progress · Profile (placeholder where noted; Library/Groups use real data)
- [x] Teacher Dashboard cards — business metric cards (Students, Subscribers, Revenue, Credits, Storage, Groups, Analytics) + class folders
- [x] Theme + dark mode + responsive (reused existing `AppTheme`; added `Responsive` breakpoints)
- [x] Keep `LectureService` + `RecordingService` wired — Library/Home use real Supabase data

---

## ✅ Phase 3 — UI Polish (GPT-5.5 Medium) — complete Jul 11, 2026

- [x] Text, icons, padding, small fixes — no architecture redesign
- [x] Login accessibility polish — autofill, focus flow, password tooltip, logo semantics
- [x] Teacher Dashboard responsive metric grid — 2/3/4 columns by width
- [x] Focused analyzer pass — no issues found in polished files

---

## ✅ Phase 4 — Architecture / Data (COMPLETE — Jul 11, 2026)

**Model:** Sonnet 5 High · Founder manual SQL run required (see [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md))

- [x] Supabase SQL schema — `examspark_backend/schema.sql`
- [x] Groups, Teacher Platform, RAG, Credits, RLS policies
- [x] Flutter wiring — GroupsRepository, ClassService, Teacher Dashboard, deductCredits RPC
- [x] [`PHASE_4_SUPABASE_SETUP.md`](PHASE_4_SUPABASE_SETUP.md) founder guide

**Founder must still run SQL in Supabase** — AI guides one step at a time.

### Additional Phase 4 refinements (founder Jul 12, 2026)

- [x] Auth UI redesign (Login/Sign Up toggle, Google icon, forgot password, email verification)
- [x] Student onboarding + Teacher/Student role selection (skip button both)
- [x] Guest "try before signup" flow (one free Ask AI, then signup prompt)
- [x] YouTube Link → Notes — Flutter UI + FastAPI captions pipeline (Jul 16, 2026); founder smoke: [`FOUNDER_YOUTUBE_LINK_SMOKE.md`](examspark_backend/FOUNDER_YOUTUBE_LINK_SMOKE.md)
- [x] Teacher/Groups refinement — recording source restriction, real certificate upload UI, Group Join Limits + Buy Plan sheet, removed Copy Code, interactive group quiz, recorder duration warnings + call-interruption auto-save
- [ ] **Founder must run** `examspark_backend/teacher_group_features_migration.sql` in Supabase (adds `lectures.source_type`, `teacher_certificates.status`, `subscription_plans.max_groups`)

---

## 🔵 Phase 5 — Backend (IN PROGRESS — started Jul 13, 2026)

**Model:** Sonnet 5 High for Sessions 1–3 (Docker/auth/pipeline/RAG); Auto OK for Sessions 4–6 (R2/credits-gating/Razorpay).

**Proof audit (Jul 13, 2026):** [`PHASE_5_AUDIT.md`](PHASE_5_AUDIT.md) — codebase-verified scorecard + Founder Manual Setup Steps 1–7.

**AI infrastructure audit (Jul 15, 2026):** [`AI_INFRASTRUCTURE_AUDIT.md`](AI_INFRASTRUCTURE_AUDIT.md) — providers, models, keys, flows, RAG, web/PYQ gaps, credits (read-only; no code change).

### Gate before Session 3

**Status (Jul 14, 2026):**

**Done (verified):**
- [x] Backend keys SET: Supabase (4) · Groq · OpenRouter · vision model names
- [x] R2 4 keys SET + `head_bucket` OK (live Cloudflare R2 reachability)
- [x] OpenRouter credits: key valid, limit_remaining ≈ **$5** (HAS_BALANCE)
- [x] Flutter: `SUPABASE_*` + `FASTAPI_BASE_URL=http://localhost:8000`
- [x] Unit tests: `tests/test_vision_and_gating.py` — **11 passed**
- [x] Health: `GET /` → `"ExamSpark Backend Active"` + `live_pipeline_audio_vision`

**Done (verified, Jul 14, 2026 evening):**
- [x] Realtime enabled for `lectures` (was the real cause of "Network problem" — Realtime stream, not FastAPI)
- [x] Root cause of "always says network problem" found: `processing_screen.dart` hardcoded one generic message for every backend failure. Fixed — `lectures.error_message` column + `_db_set_status` now carries the real reason through Realtime to the screen.
- [x] Retry button fixed — previously reset the progress bar only, now actually resends the file to FastAPI.
- [x] Recording Setup screen no longer shows camera/mic preview + "Start Recording" for plain PDF/photo/audio uploads opened from Home's attach sheet.
- [x] `invokeProcessing` force-refreshes an expired Supabase session before use.
- [x] **Real bug found via the error-surfacing fix above:** every upload was failing with `401 "Invalid token."` — `auth_service.py` verified the access token locally against `SUPABASE_JWT_SECRET`, fragile-by-design. Replaced with `get_supabase_admin().auth.get_user(token)` (Supabase verifies authoritatively, no local secret needed). Verified live with a real login token — auth now passes (`pytest` still 11/11).
- [x] **Second real bug found (same error-surfacing fix):** after auth passed, audio/PDF uploads failed with `Exception: Qwen3 (OpenRouter) failed: 400 {'error': {'message': 'qwen/qwen3 is not a valid model ID'...}}` — `examspark_backend/.env` had `AI_CHAT_MODEL=qwen/qwen3` (never a real OpenRouter slug). Fixed to real slugs (`qwen/qwen3-30b-a3b-instruct-2507` / `qwen/qwen3-235b-a22b-2507`) in `.env` + both `.env.example` files (value-only, no code change). Restarted backend, verified directly with `scripts/verify_notes_generation.py` — real OpenRouter `200` + parsed notes back. Image upload was never affected (separate, correctly-configured vision model).
- [x] **Empty notes on result screen:** pipeline succeeded but UI showed "No summary available" — Postgres `notes` table stores R2 paths only; UI was reading wrong columns. Fixed: `GET /api/v1/lectures/{id}/notes` reads from R2; `notes_result_screen` uses `fetchLectureNotes()`. Vision SSL: one OpenRouter retry added.

**Founder still (manual)** — full copy-paste checklist:
[`examspark_backend/FOUNDER_SMOKE_AND_NEXT.md`](examspark_backend/FOUNDER_SMOKE_AND_NEXT.md)

- [ ] Run `examspark_backend/credit_economy_v2_1_migration.sql` in Supabase SQL Editor (service_role cannot SELECT `subscription_plans` — must run in dashboard)
- [ ] Re-run `examspark_backend/smoke_test_all_in_one.sql` once more (adds the `error_message` column — safe to re-run)
- [ ] **Restart backend** (new GET route): `cd examspark_backend` → `python -m uvicorn main:app --host 127.0.0.1 --port 8000`
- [ ] **Restart Flutter** (`R` hot restart or quit + `flutter run -d chrome --web-port=8080`)
- [ ] One live smoke: JPG **or** text PDF **or** short speech audio → Processing `done` → **Summary tab shows real text** (do NOT tap Generate More buttons — MCQ/RAG not wired yet)
- [ ] Optional verify: `cd examspark_backend` → `python scripts/verify_smoke_prereqs.py` (add `--e2e-image` for OpenRouter spend)
- [ ] Say **smoke test pass** in chat when step above succeeds once
- [ ] **Do not start Session 3 (RAG)** until smoke passes
- Tavily / RAG keys: leave EMPTY until Session 3

### Best next method (locked Jul 14, 2026) — NO separate polish bag

After founder says **`smoke test pass`**:

1. **Session 3** — RAG + Ask AI — **core shipped Jul 14, 2026** (run `session3_rag_match.sql`; then Ask with RAG on notes). Flashcards/MCQ still pending.
2. **Session 4** — R2 path polish (absorbs half-done R2 polish)
3. **Session 5** — Plan-tier + credit gating polish — **shipped Jul 15, 2026**
4. **Session 6** — Razorpay live (absorbs credit-pack checkout stubs) — **code shipped Jul 15, 2026** (founder keys + SQL + smoke remaining)
5. **Group join limits on refund** — **code shipped Jul 15, 2026** — founder must run `group_join_limits_enforce_migration.sql`

| Half-done / polish leftover | Goes into |
|-----------------------------|-----------|
| R2 path polish | Session 4 |
| Plan-tier gating polish | Session 5 |
| MCQ / Flashcards / Revision / extras on edge function | After Session 3 Ask AI core — founder OK required |
| Home AI chip generate on click + Tavily + PYQ bank | Pending list (Jul 15) — wait for founder |
| Deduct-then-R2 gap | Small fast-follow when founder asks |
| Live payments | Session 6 — code ready; founder test keys + smoke |

**Remember later (not now):**
- Session 3 RAG + Ask AI — **blocked** until `smoke test pass`
- Do **not** start a grab-bag “polish pending” workstream before Session 3

### Pre-Phase-5 Task 0 — Credit Economy v2.1 (COMPLETE — Jul 13, 2026)

- [x] Buy Extra Credits — 5 a-la-carte packs (100/500/1,000/5,000/10,000) in `subscription_plans.dart` `creditPacks` + `credit_packs` table
- [x] Fee-corrected margin validation (worst-case 15% Google Play fee) — `plan_199` 1,300→1,500 credits, `teacher` 20,000→16,000, `free` 50→75 code/DB sync fix
- [x] `credit_economy_v2_1_migration.sql` — founder must run once (see checklist below)

### Session 1 — Docker + Auth skeleton (COMPLETE — Jul 13, 2026)

- [x] `Dockerfile` + `docker-compose.yml` (FastAPI, local dev hot-reload)
- [x] Supabase JWT verification (`app/services/auth_service.py`, `get_current_user` dependency) — every protected route needs `Authorization: Bearer <supabase_access_token>`
- [x] `POST /api/v1/lectures/process` + `GET /api/v1/lectures/jobs/{id}` skeleton (superseded by Session 2's real pipeline)

### Session 2 — Real lecture pipeline (CORE COMPLETE — Jul 13, 2026)

- [x] Groq Whisper Turbo transcription + auto non-turbo fallback on low confidence/error (`whisper_service.py`)
- [x] Qwen3 32B (OpenRouter) notes/summary generation (`qwen_service.py`)
- [x] Server-side credit deduction via `fn_deduct_credits` RPC, charged only after both AI calls succeed (`credits_service.py`)
- [x] No raw audio ever written to disk/R2 — stays in memory only for the request's duration (satisfies "delete audio after Whisper" by never persisting it)
- [x] R2 upload for transcript/notes/summary/key-points/important-terms + Postgres path-only metadata (`r2_storage_service.py`) — first real R2 wiring, pulled forward from Session 4 since Postgres is metadata-only by hard rule
- [x] **Short notes → Supabase** (Jul 16, 2026) — `notes.clean_notes`, `short_summary`, `key_points`, `important_terms`; legacy `r2_notes_path` fallback kept for old lectures
- [x] Flutter switched: `lecture_service.dart` `invokeProcessing()` now calls FastAPI (multipart + Bearer token) instead of the `process-lecture` edge function; `AppConfig.resolvedApiBaseUrl` now reads `.env`'s `FASTAPI_BASE_URL` at runtime (was compile-time-only before, a pre-existing gap)
- [x] **Flashcards + Quiz extras → FastAPI** (Jul 16, 2026) — Study Workspace tabs; JSON in Supabase `extras.payload_json`; **5 / 5 credits**
- [x] **Revision extras → FastAPI** (Jul 16, 2026) — Study Workspace tab; Supabase `extras.payload_json`; **5 credits**
- [x] **Important Questions + Mind Map → Home AI (study_chip)** (Jul 17, 2026) — Home chips; `study_chip` pricing; **10 / 10 credits**
- [x] **Smart Visual Notes Engine (Phase 5)** (Jul 16, 2026) — `notes.visual_payload_json`; Ask/Home AI `visual_payload` on SSE done; Flutter `SmartEducationalContent`; cheat sheet auto in notes
- [x] **Smart Visual diagrams delivery fix** (Jul 17, 2026) — token caps increased (normal/deep) to prevent trailing visual JSON truncation; explicit visual-topic prompt contract; quadratic graph parser fixed; deterministic Math/Biology/History render tests
- [x] **Home AI chat UX fixes** (Jul 17, 2026) — no re-type animation after scroll; Home text selection shows “Select AI”; topic-related Home chips + correct study_chip credits
- [x] **Home Select AI + chip dump fix** (Jul 17, 2026) — Select toolbar always on finished replies; chips/Select open bottom sheet (no full-answer paste into chat); Phase 4C deferred
- [x] **Phase 4C Home AI Smart Study Workspace** (Jul 17, 2026) — Knowledge Object + `response_id`; chip tool APIs; compact first answer; generate-once cache; founder SQL `home_ai_phase4c_migration.sql`
- [x] **Phase 4C Final Hardening** (Jul 17, 2026) — chips free from KO (no AI on open); Recommended/More UI; unique derive payloads; Regenerate paid; founder lock doc updated
- [x] **Phase 4C V2 harden** (Jul 17, 2026) — Knowledge V2 + parent stale chips; semantic duplicate Ask reuse; Exam Booster / Common Mistakes / Teacher Tips; SQL `home_ai_phase4c_v2_migration.sql`; smoke order in `FOUNDER_PHASE4C_HOME_AI.md`
- [x] **CTO Working Charter (Founder Lock)** (Jul 17, 2026) — honesty/user-first gates; `FOUNDER_CTO_WORKING_CHARTER.md` + smoke card; Gate A Phase 4C smoke before new code; Gate B `start …` only
- [x] **Smarter free Home chips** (Jul 17, 2026) — unique derive formats per chip (not same essay); legacy cache auto-upgrade; still 0 credits
- [x] **Session Persistence & Resume (Founder Lock) Phase 1** (Jul 18, 2026) — `FOUNDER_SESSION_PERSISTENCE.md`; AuthGate + tab/workspace + Home chat local restore; visible Ask AI on select
- [x] **Home AI Camera / Upload Image** (Jul 18, 2026) — Plus first 2 options → Home chat; **10 credits**; Web getUserMedia camera; not Study Workspace
- [x] **Phase 4E Notes Instant Open P0** (Jul 18, 2026) — memory + SharedPreferences; sticky-error fix; open-first sync-later; Library title dedupe; lock `FOUNDER_PHASE4E_NOTES_INSTANT.md`
- [x] **Library full-page workspace** (Jul 18, 2026) — Library opens Study Workspace as full page (not side panel); Home keeps split; session keeps `fullPage`
- [x] **Clean Library · Delete · Friendly errors** (Jul 21, 2026) — Library only `done`; FastAPI permanent delete + R2; student messages + support codes; 3-dot after Ask AI
- [ ] **Founder must run** `examspark_backend/lecture_last_opened_migration.sql` — Library time stamp (`3:45pm` updates on open)
- [x] **Mic silence + false Retry fix** (Jul 21, 2026) — no sticky Realtime N101; silent mic → check-mic error, 0 credits
- [x] **Phase 4D Home AI Study History P0** (Jul 18, 2026) — sessions/messages SQL + auto-save + History restore (0 credits); run `home_ai_phase4d_migration.sql`
- [x] **Home AI Mobile UX Simplification** (Jul 18, 2026) — Answer + Visual card + 5 primary chips + More grid; UI only; `FOUNDER_HOME_AI_MOBILE_UX.md`
- [x] **Home chips duplicate cull** (Jul 18, 2026) — UI hide Cheat Sheet / 5 Min / Exam Booster / Teacher Tips (same content as Revision/IQ/Learn More); APIs kept
- [x] **Founder Gate A:** Phase 4C UI smoke — PASS (founder `ok pass` Jul 18, 2026)
- [x] **Tavily web search (gated)** (Jul 18, 2026) — `web_deferred` only + classifier + empty RAG/PYQ; credits 15/30; [`FOUNDER_TAVILY.md`](examspark_backend/FOUNDER_TAVILY.md)
- [x] **Lecture duplicate detection** (Jul 18, 2026) — Layer 1 hash/YouTube ID + Layer 2 transcript ≥0.95; per-student; SQL `lecture_dedupe_migration.sql`; [`FOUNDER_LECTURE_DEDUPE.md`](examspark_backend/FOUNDER_LECTURE_DEDUPE.md)
- [x] **Backend freeze + mic dispose** (Jul 21, 2026) — `asyncio.to_thread` for sync R2/Supabase/yt-dlp; boto3 timeouts; YouTube audio 64k; `RecordingService.releaseForScreen` (no permanent dispose)
- [x] **Post-processing result navigation** (Jul 21, 2026) — pop Processing first, then open full-page Study Workspace next frame; guard duplicate `done` events
- [x] **Full-page `/study_workspace` after process** (Jul 21, 2026) — `pushNamedAndRemoveUntil` clears recording stack; duplicate snackbar on result page; non-empty YouTube unexpected errors
- [ ] **Phase 4D History smoke** — after SQL: ask → History → restore → chat `Phase 4D history smoke pass`
- [ ] **Phase 4D Home AI Study History** — FUTURE polish; lock [`FOUNDER_PHASE4D_HOME_HISTORY.md`](examspark_backend/FOUNDER_PHASE4D_HOME_HISTORY.md)
- [x] **Select & Ask AI (Phase 6)** (Jul 16, 2026) — selection toolbar in Study Workspace; `/api/v1/select-ai` stream; **2 / 3 credits** by action
- [x] **Phase 4B Study Workspace UI/UX** (Jul 16, 2026) — premium empty states, progress bars, quiz Submit→explain, flashcard flip actions, transcript tab + read-only `GET /transcript`; no credit changes
- [x] **Phase 4B Study Workspace performance cache** (Jul 16, 2026) — load-once session cache; instant tab switches; background extras; Refresh / Regenerate only
- [x] **Study Workspace loading harden** (Jul 16, 2026) — KeepAlive + ValueKey + no spinner if content cached; Redis deferred; Teacher/Groups paused until smoke OK
- [ ] **Redis shared cache** — deferred until Flutter tabs feel instant AND multi-worker Railway needs it (not for tab loading)
- [ ] **Teacher / Groups next work** — paused while Study Workspace loading smoke is priority
- [ ] **Not done yet (follow-up):** Answer-Key still calls old `process-lecture` edge function
- [x] **Vision Session (Jul 13, 2026):** PDF/image pipeline — Qwen3-VL Flash → auto Plus escalation; PDF text → Qwen3; tier check before credits; Flutter document upload routes `image_upload` / `pdf_upload` with real filenames
- [x] **Qwen3-VL cross-check (Jul 13, 2026):** logic OK — no mandatory code changes; live smoke test still needs OpenRouter $5 + R2
- [ ] **Known simplification:** uploaded (non-live-recorded) audio files bill at a minimum 1-minute/40-credit floor since Flutter doesn't parse audio file duration client-side — undercharge-safe, not overcharge-risk

### Home AI — pending follow-ups (founder Jul 15, 2026)

**Do not start until founder asks.** Chips / Tavily / PYQ / paid Translate API are listed only — not bugs.

- [x] **Home AI study-action chips → FastAPI generate on click** — Flashcards, Quiz, Revision Sheet, Important Questions, Mind Map, Learn More, **5 Minute Revision**; Cheat Sheet opens Notes (included in notes); **PYQs** chip → related metadata tags (0 credits; Jul 18 fix)
- [ ] **Trusted Web Search (Tavily)** — Home AI Priority 4 (latest / current affairs / when local RAG empty); when live, set `answer_source=WEB`
- [x] **PYQ Database (smoke bank)** — `exam_pyqs` + seed + Related tags in Home/Ask (metadata only). Full bank + `answer_source=PYQ` later. Fix IVFFlat empty: `pyq_fix_ivfflat_index.sql` + local cosine fallback (Jul 18)
- [ ] **Persist `answer_source` / `confidence` to analytics** — API fields shipped Jul 15 (SUCCESS responses); DB + dashboard later for “how many RAG / NO_MATCH / Web”
- [ ] **Translate API (8 credits)** — still Future; multilingual Q&A Phase A already live via prompt LANGUAGE RULE (answer in question language) Jul 15, 2026; **language fidelity harden** (English Q → English A even if notes Hindi) Jul 15, 2026
- [x] **Typo / mistype intent tolerance** — Home + Ask AI silently interpret wrong spelling (e.g. `cradit econocmy` → credit economy) Jul 15, 2026; prompt-only, no new API
- [x] **Faster normal replies** — Home + Ask AI brevity user-line Jul 15, 2026; normal `max_tokens` raised 512 → 1024 Jul 17 so trailing Smart Visual JSON is not truncated; deep mode/model unchanged
- [x] **Performance Phase 1 (Fast First Answer)** — smart route, top-3 RAG, caches, parallel precheck, perf logs Jul 15, 2026 — see [`PERFORMANCE_PHASE1_REPORT.md`](PERFORMANCE_PHASE1_REPORT.md)
- [x] **ChatGPT-style SSE token streaming** for Home AI + Ask AI — additive `/stream` routes Jul 15, 2026 (JSON paths kept; Flutter falls back to JSON+typewriter on stream failure).

### Remaining Phase 5 Sessions

**Order is locked — do not reorder or polish in parallel:**

- [x] Session 3 — RAG chunking + pgvector embed + Ask AI endpoint — **core done Jul 14, 2026** (founder must run `session3_rag_match.sql`; flashcards/MCQ still edge)
- [x] Session 4 — R2 folder/path conventions for PDF/image/exports (canonical `Users/{user_id}/Library/{lecture_id}`; helpers for Teachers/Exports; source PDF/image persist) — **Jul 15, 2026** see [`SESSION_4_R2.md`](examspark_backend/SESSION_4_R2.md)
- [x] Session 5 — Server-side plan-tier + credit gating polish (absorbs half-done gating; vision/recording checks already stubbed)
- [x] Session 6 — Razorpay Web test-mode path (order/verify/webhook + Flutter checkout + credit packs) — **Jul 15, 2026**; founder: [`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md) + `session6_fn_grant_credits_migration.sql`
- [x] Google Play Billing Android code (catalog + verify API + `in_app_purchase`) — **Jul 15, 2026**; founder smoke later: [`FOUNDER_GOOGLE_PLAY_BILLING.md`](examspark_backend/FOUNDER_GOOGLE_PLAY_BILLING.md)
- [x] Refund policy + webhook handler (Razorpay / Play) — **Jul 15, 2026**; [`REFUND_POLICY_AND_PROCESS.md`](REFUND_POLICY_AND_PROCESS.md) · [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](examspark_backend/FOUNDER_PAYMENT_KEYS_WHEN_READY.md)
- [x] Group join limits — fail-closed Flutter + DB trigger + trim on plan refund — **Jul 15, 2026**
- [x] Group join mock UI pass (Free lock + ₹199 1/1) — founder Jul 16
- [x] YouTube Link → Notes smoke pass — founder Jul 16
- [x] Session live sync (credits/plan/groups Realtime + tab refresh) — Jul 15, 2026
- [ ] **Founder NEXT (only open checklist):** [`FOUNDER_PENDING_LOCKED.md`](examspark_backend/FOUNDER_PENDING_LOCKED.md) + [`FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md) — start servers → SQL → UI smoke (Flashcards → Visual → IQ/Mind Map → Select AI → 5 Min); then Realtime+trim; Razorpay when keys; `commit today` when smoke OK
- [ ] **Founder:** Session 6 Razorpay keys + smoke — **⏸ paused** until Test API keys ([`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md))
- [x] **Next coding (founder OK):** `start PYQs` done Jul 18 (5 Minute Revision done Jul 16; Cheat Sheet = inside Visual Notes)
- [ ] PhonePe live (stub only — ask when ready)

---

## ⏳ Phase 6 — Final Polish (GPT-5.5 Medium)

- [ ] Testing · cleanup · docs · performance

---

## 🗑 Marked for Removal (confirm first)

| Item | Reason |
|------|--------|
| `/processing` → `/notes_result` navigation | Inline conversation |
| `/teacher`, `/student` top routes | Groups + Profile |
| Home sidebar | Library tab |
| Root `lib/` duplicate | Deprecated |
| `lib/presentation/screens/dashboard/home_screen.dart` | Replaced by `AppShell` + `HomeTab` (Jul 11, 2026) — no longer referenced by any route, kept for now pending founder confirmation |

---

## 💡 Future

See [`FEATURES.md`](FEATURES.md)
