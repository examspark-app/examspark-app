# ExamSpark — Changelog

> **Maintained per** [`PROJECT_WORKING_RULES.md`](PROJECT_WORKING_RULES.md)
> **Format:** Date · What changed · Trigger / phase

---

## Jul 2026

### Freeze lock ~70% core (Jul 22, 2026)

Founder pass: no more feature/backend changes without `start …`. Next allowed lane = UI/UX only when named. Language lock + notes/Ask paths stay as-is.

### Language lock: notes = input; Ask/Home = user chat (Jul 22, 2026)

Notes: English audio/OCR → English notes only (no Hindi/Khmer invent). Ask AI / Home AI: answer in student question language (Hinglish/Marathi/…) with conversation lock + anti-leak so notes language cannot override chat.

### Notes Retry duplicate + YouTube JSON (Jul 22, 2026)

Image Retry L101: `transcripts_lecture_id` unique — upsert now uses `on_conflict=lecture_id`. YouTube L101 JSON delimiter: stronger `_extract_json_object` salvage + clearer generate_notes failure. Download path already OK.

### Image notes JSON truncate fix (Jul 22, 2026)

Root cause of L101/500 on image → notes: vision prompt included huge `NOTES_SYSTEM_EXTENSION` → model cut mid-JSON (`Unterminated string`) → Plus escalation also failed → empty notes / 500. Fix: compact vision prompt, `max_tokens` 8192, truncated-JSON salvage, never return unusable empty notes. YouTube audio download path already OK (verified).

### YouTube non-CC download restore (Jul 22, 2026)

Apology path: non-CC Whisper download was broken by 403 + blame-y CC-only messaging. Restored multi-client yt-dlp attempts (android/ios/tv/web), softer errors, longer timeouts. Image/YouTube UI copy no longer blames photo quality or “must enable CC”.

### YouTube fail-fast + clearer process errors (Jul 22, 2026)

YouTube Whisper fallback: socket timeout + 90s download / 120s Whisper caps (no 5-min hang on 403). Process route logs unexpected 500s with traceback. I101 mapping tightened so random errors are not shown as “image” failures. Founder: restart backend clean once after language edits (`--reload` mid-request caused bare 500s).

### Multilingual India + world (Qwen3) (Jul 22, 2026)

Language policy: match student/source language worldwide (not English-only, not India-only). Ask AI / Home / Select use MATCH_QUESTION for Latin + world scripts; Hindi/Bengali/Hinglish locks kept. Notes + chips + YouTube CC prefer India + major world langs; any CC track still accepted. Prompts state Qwen3 is multilingual.

### All-India multilingual product-wide (Jul 22, 2026)

Ask AI / Home AI / Select AI: language lock covers Hindi, Bengali, Hinglish, English, plus MATCH_QUESTION for other Indic/Urdu scripts (Tamil, Telugu, …). Notes + flashcards/quiz/revision/mind map/important Qs + Home chips use shared STUDY_CONTENT_LANGUAGE_RULE (same language as source). YouTube captions already multilang.

### YouTube multilingual (Bengali/Hindi+) (Jul 22, 2026)

YouTube captions: not English-only — prefer hi/bn/en (+ Indian langs), then any CC track YouTube lists. Notes prompt: write notes in the **same language** as the transcript (Bengali lecture → Bengali notes). Clearer V101 when CC missing / YouTube 403.

### YouTube Bengali/Hindi captions fix (Jul 22, 2026)

Caption fetch was English-only (`languages=('en',)`). Now prefers hi/bn/en + other Indian langs, then any available CC track. Clearer V101 + 403 messages. Hindi often worked via English auto-CC; Bengali-only CC failed before.

### Quiz Attempts Slice A (Jul 22, 2026)

Study Workspace quiz finish saves `quiz_attempts` (score/total). Progress Learning Score = average of recent finishes; Recent Activity shows Quiz Completed. SQL: `quiz_attempts_migration.sql` · guide `FOUNDER_QUIZ_ATTEMPTS.md`. Soft-fail if table missing. No Home AI / Select AI attempts.

### Student Progress Slice 1 live (Jul 22, 2026)

Progress tab loads real lectures + study credit spend: streak (open/save days), Topics Mastered (distinct topic/subject), subject insights, weekly lecture activity bars, honest Recent Activity (Quiz Generated — not scores). Study Time + Learning Score stay `—` until duration/attempts exist. No Home AI / chats. No new SQL.

### Student Progress UX upgrade (Jul 22, 2026)

Student Progress tab only: Topics Mastered + Learning Score cards, AI Insights (strong / needs improvement / recommended next), weekly activity bars, clearer Recent Activity. Same theme/nav; still placeholder stats until server analytics. No teacher dashboard / gaming / Home AI exposure.

### Processing P1 — notes-first + adaptive prompts (Jul 22, 2026)

1. **Notes before optional R2** — Record/upload: Supabase notes → `done` → background R2 transcript + RAG (Workspace opens sooner; Transcript tab may fill seconds later).
2. **Long-lecture wait copy** — clearer Listening messages for large audio; admin logs `whisper_chunk i/n` (no schema change).
3. **Adaptive medium prompt** — duration-aware short/medium/long bands; medium uses a lighter prompt than full long-lecture mode.

Credits / UI layout / schema unchanged. PDF/vision/YouTube still use full sync persist.

### Processing P0 reliability — Whisper retry + poll-before-error (Jul 22, 2026)

1. **Groq Whisper safe retry** — same Turbo call up to 2× on timeout / transport / 429 / 5xx (1s→2s backoff); never retry HTTP 400 / no-speech; then existing non-turbo fallback.
2. **Client poll before error** — on network drop of long `/process`, poll lecture status up to 90s; open notes if `done`; avoid false sticky errors while server still works.
3. **Admin timing logs** — upload / whisper / openrouter / r2_and_db + `pipeline_timing_fail` with `exc_type` and Groq HTTP status (not shown to students).

Credits still deduct only after notes succeed. No UI / schema / architecture rewrite.

### Processing P0 performance (Jul 22, 2026)

Safe speed/wait improvements only (no product/credits/schema redesign):
1. **Short-audio smart prompt** — lighter OpenRouter system prompt + lower `max_tokens` for short transcripts (~&lt;2 min); medium/long keep full quality prompt.
2. **Single R2 transcript upload** — `transcript` + `clean_transcript` DB paths share one object until a real cleaner exists (no duplicate upload).
3. **Honest processing stages** — Preparing → Listening → Generating notes → Finalizing → Done; progress never jumps to 100% early; “Still processing…” when over estimate.
4. **Admin pipeline timing logs** — Whisper / OpenRouter / R2+DB stage seconds in server logs only (not student UI).

### Processing time estimate on lecture pipeline (Jul 22, 2026)

Processing screen shows an honest **time range** (from recording length + upload size): low ≈ 75% of model, high ≈ 135% + 45s buffer. Updates every 5s; if work runs past the high end, copy switches to “Still working…” instead of looking broken. Progress bar stays tied to real backend status (not fake %).

### Credits History screen (Jul 22, 2026)

Dedicated read-only **Credits History** (`/credits/history`): This Month spend, date sections, filters. Tap a lecture row → **Study Workspace** on the right tab (Quiz, Flashcards, etc.). Home-only rows show a hint; no re-charge on tap.

### Record / Audio Upload → 1 credit per minute (Jul 22, 2026)

Founder-approved: Recording + Audio Upload charge **1 credit per actual minute** (round up, max 180). Duration chips remain planned-duration warnings only. YouTube stays on 10/20/40 bands. Server still uses ffprobe length → single deduct after Whisper + notes succeed.

### 3-hour Record + hide Fast/High Accuracy (Jul 21, 2026)

Setup Recording no longer shows Fast / High Accuracy (server still Turbo → auto fallback). Duration chips include **90–180 (up to 3 hr)** at **240 credits**. Long Record/upload audio is Whisper-chunked via ffmpeg; short path unchanged. Hard max 180 minutes with a friendly student message.

### Home chat + recording UX polish (Jul 21, 2026)

Home AI/photo failures show friendly network messages + Retry (no duplicate question). Sent photos show a thumbnail in the user bubble (session memory). Add content sheet is scrollable (no bottom overflow). Recording goes straight to consolidated setup (Subject/Topic + Quality/Duration); fake camera/mic placeholder page skipped.

### Teacher-safe 5-minute silence warning (Jul 21, 2026)

Recording silence warning moved from 1 min to **5 continuous minutes** (teacher pauses OK). Beep + `Continue Recording` / `Stop & Process`; re-arms after voice resumes. Call/app interruption Discard/Process dialog also beeps.

### Mic silence + false Retry fix (Jul 21, 2026)

Realtime stream blips no longer show sticky N101; `done` clears error UI; client HTTP failures do not overwrite finished lectures. Silent/no-mic recordings reject before notes/credits (“Kindly check your microphone”); amplitude popup after ~1 min silence while recording.

### Library last-opened time stamp (Jul 21, 2026)

Library / Home Recent cards show time like `3:45pm` (today) or `21/7 · 3:45pm`. Updates when Study Workspace opens (`last_opened_at`). SQL: `lecture_last_opened_migration.sql`. List sorts by last opened.

### Clean Library · Delete · Friendly errors (Jul 21, 2026)

Library / Recent only list `status=done` lectures (draft/error job rows stay for retry, never look like files). Study Workspace three-dot after Ask AI → permanent FastAPI delete (`DELETE /api/v1/lectures/{id}`) with R2 prefix cleanup + duplicate-child removal. Student errors use support codes (V101/N101/C101/…) — no R2/RAG/SSL/Whisper text in UI. Processing copy softened (“Preparing your study tools…”). Legacy Notes Result delete now uses the same FastAPI path.

### Full-page Study Workspace after processing (Jul 21, 2026)

Processing done now uses `pushNamedAndRemoveUntil('/study_workspace')` so recording routes are cleared and Notes · Summary · Quiz open as a real full page (not hidden under Recording Setup). Duplicate notice shows on the result page. Empty YouTube unexpected errors now always include `repr(e)`.

### Post-processing result navigation fix (Jul 21, 2026)

Processing now closes before `OpenWorkspaceBridge` opens the result on the next frame, preventing `Navigator.pop` from immediately dismissing the new mobile workspace sheet. Processing requests a full-page Study Workspace so Notes · Summary · Quiz are clearly visible; repeated `done` realtime events are guarded against duplicate navigation.

### Backend freeze + mic dispose fix (Jul 21, 2026)

Root cause: sync boto3 R2 / Supabase / yt-dlp ran on the FastAPI event loop → one stuck network call froze **all** lecture types + `/health`. Fix: `asyncio.to_thread` for blocking pipeline/extras work; boto3 `connect_timeout=10` / `read_timeout=30` / `max_attempts=2`; YouTube Whisper download uses `worstaudio` + mp3 64k. Mic: shared `RecordingService` no longer permanently disposes `AudioRecorder` on screen leave (`releaseForScreen` + lazy recreate). **Follow-up:** Chrome red-screen `Library not defined` on recording/processing — `recording_service.dart` no longer imports `dart:io` directly (conditional `recording_io_stub` / `recording_io_native`); requires full Flutter quit + restart, not hot reload.

### YouTube Notes UX fixes (Jul 21, 2026)

After processing, opens **StudyWorkspace** (same as Library) via `OpenWorkspaceBridge` — Generate More chips + Ask AI work. Eager RAG index at end of audio/YouTube pipeline (faster first Ask). Auto YouTube title via yt-dlp metadata. Layer 1 dedupe HIT/MISS logs + Supabase verify query in `FOUNDER_LECTURE_DEDUPE.md`. Broader YouTube URL validator in dialog.

### YouTube credits 10/20/40 + Turbo-only Whisper (Jul 21, 2026)

YouTube Notes charges **10 / 20 / 40** (not Record 40/80/120). No-CC path uses **Whisper Turbo only** (`allow_non_turbo_fallback=False`); Record path keeps non-Turbo fallback. Free+ YouTube unlock unchanged; audio still ₹499+.

### Tavily web search — gated live (Jul 18, 2026)

Last-resort current affairs only (`web_deferred` + empty RAG/PYQ + LLM classifier). Credits **10/20** (founder fix). Logs `tavily_usage`. Guide: `FOUNDER_TAVILY.md`. Free-tier `TAVILY_API_KEY` in backend `.env`. Smoke list: `FOUNDER_SMOKE_AFTER_JUL18_PASS.md`.

### Lecture duplicate detection (Jul 18, 2026)

Per-student only: Layer 1 (audio SHA-256 / YouTube video ID) before AI → 0 credits + reuse notes. Layer 2 (transcript embedding ≥ 0.95 vs own RAG) after Whisper → skip notes + RAG pollute, 0 credits. Clear Flutter snackbar. SQL: `lecture_dedupe_migration.sql`. Guide: `FOUNDER_LECTURE_DEDUPE.md`.

### RAG store policy — audio + YouTube only (Jul 18, 2026)

Founder lock: `rag_documents` only for `recorded` / `uploaded_audio` / `youtube_link`. PDF/photo (`uploaded_document`) never indexed; Ask AI still uses that lecture’s notes via direct fallback; chips use Knowledge Object. Optional cleanup: `rag_exclude_pdf_photo_cleanup.sql`.

### YouTube Whisper + full-store RAG (Jul 18, 2026)

Captions-first YouTube; Whisper fallback via temp yt-dlp audio (deleted after). Credits = Record 40/80/120 (max 90 min). User-wide RAG RPC `match_rag_documents_user` + weighted merge (open lecture first). Ask Shape 1/2/3 confirmed. Tavily still not live (web_deferred reinforce only). Guide: `FOUNDER_YOUTUBE_WHISPER_FALLBACK.md`.

### Founder lock — Jul 18 night pass (Jul 18, 2026)

Founder `all pass ok lock`: Phase 4D History + PYQ smoke bank (Important Qs weightage) + Shape 1 short-complete + chip Regenerate disclaimer. Do not re-smoke unless bug. Next coding only on new `start …`.

### Chip disclaimer — Regenerate = AI (Jul 18, 2026)

Phase 4C tool sheet: small black line on free/derived open — “Want a fresh AI version? Tap Regenerate (uses credits).” More sheet copy aligned. Regenerate still Qwen AI from KO (not lecture RAG).

### Shape 1 — short but complete (Jul 18, 2026)

Simple factual Home/Ask answers must be 2–4 useful sentences (not one bare line); still no forced section headers. Prompts in `home_ai_service` / `rag_ask_service` + `_BREVITY_NORMAL`.

### PYQ UX — Important Qs weightage + chip speed (Jul 18, 2026)

Similarity 0.45 hidden from students. Home/Ask answers skip PYQ match (faster). Important Questions uses PYQ `weightage_stars` as chance bias (free derive + paid regen). Learn More regen `max_tokens` 1600; IQ regen 2200. PYQs More-chip stays removed.

### Home — hide PYQs chip (Jul 18, 2026)

Founder: remove More → **PYQs** chip (reply delay confusion). Related tags in answer path stay server-side until founder says otherwise. Learn More: first open = KO free; **Regenerate** = paid AI (5 credits).

### PYQ match speed — less Home reply delay (Jul 18, 2026)

PYQ was adding 3–6s before first token (2 embeds + broken RPC + Supabase each ask). Now: 1 embed, local scan + in-memory bank cache, PYQ overlaps RAG. Warm path ~0.01s.

### PYQ Related fix — IVFFlat empty + Home chip (Jul 18, 2026)

Founder: no Related PYQ in chat; PYQs chip said coming soon. Root cause: IVFFlat on ~12 rows returned zero RPC neighbors despite cosine ~0.55; threshold 0.80 was also too high (now 0.45). Fix: local cosine fallback in `pyq_retrieve.py`; SQL `pyq_fix_ivfflat_index.sql` drops bad index; Home **PYQs** chip → related tags sheet (0 credits).

### Start PYQs — exam_pyqs bank + vector match (Jul 18, 2026)

Founder `ok start` / Gate B. SQL `pyq_exam_pyqs_migration.sql` (metadata + `match_exam_pyqs`); seed embeddings via `scripts/seed_pyq_embeddings.py`; live `match_pyqs_for_query` (tags only). Guide: `FOUNDER_START_PYQS.md`.

### Adaptive RAG + PYQ answer shapes (Jul 18, 2026)

Prompt + retrieval hook: Ask AI / Home AI use Shape 1/2/3 with hard OMIT. Code injects `VERIFIED PYQ` user-message block via `pyq_retrieve.py` (live after `start PYQs` SQL + seed). Metadata-only tags (2A copyright).

### Home/Ask answer template flexibility (Jul 18, 2026)

Prompt-only: `_HOME_SYSTEM` / `_ASK_SYSTEM` keep compact replies but sections are optional by question type (not a forced checklist). Vision `_format_home_vision_answer` skips empty/filler Easy Explanation / Exam Tip. `_BREVITY_NORMAL` aligned. No orchestration/RAG/credits/KO changes.

### Phase 4D Home AI Study History P0 (Jul 18, 2026)

Gate A 4C pass + `start phase 4`. Sessions/messages in Supabase (`home_ai_phase4d_migration.sql`). Every SUCCESS Home AI answer auto-saves into a Study Session; chips stay in Phase 4C `home_ai_tools`. History UI on Home (clock icon) restores Q+A+chips with **0 credits / no AI**. Doc: `FOUNDER_PHASE4D_HOME_HISTORY.md`.

### Library Study Workspace = full page (Jul 18, 2026)

Desktop Library no longer opens Notes in a squeezed right panel next to the list. Lecture opens as a **full-page** Study Workspace (same Notes/Summary/Transcript tabs). Home still uses the right split panel. Close / tap Library again returns to the list. Minimize restores the same full-page (or side panel) via session persistence.

### Home AI Camera + Upload Image (Jul 18, 2026)

Plus (+) menu: **Camera** and **Upload Image** are first. Both send the photo to Home AI chat (`POST /api/v1/home-ai/vision`) — **not** Study Workspace. Credits: **10** (founder). Web Camera uses getUserMedia permission dialog. PDF/Audio stay workspace flows. Phase 4E P0 notes cache lock: `FOUNDER_PHASE4E_NOTES_INSTANT.md`.

### Session Persistence & Ask AI select fix (Jul 18, 2026)

Founder Lock saved: [`FOUNDER_SESSION_PERSISTENCE.md`](examspark_backend/FOUNDER_SESSION_PERSISTENCE.md) — minimize/resume must restore UI; never regenerate AI / never re-charge. Phase 1 code: AuthGate ignores token refresh + same-user auth noise (2.5s sign-out debounce); AppShell persists tab + open workspace; Home AI chat persists (memory + SharedPreferences); visible **Ask AI** on text selection (Home + Notes, Web DOM selection).

### Select → Ask AI → Home chat (Jul 18, 2026)

App-wide minimize: text selection context menu defaults to **Ask AI**. Click adds the selection as the next Home chat question and streams the reply in chat (no Select AI sheet / no follow-up dialog). Study Workspace selection uses `HomeAskBridge` → Home tab.

Photosynthesis (and known topics) auto-get a real Visual Card / diagram — not “Direct Answer → Easy Explanation” boxes. Visual chip moved under More; primary = Quiz/Flashcards/Revision/Learn More/Important Qs. Removed Copy/Export buttons from Home sheets + Study Workspace tabs. Notes R2 fallback hard-timeout 8s; Flutter notes timeout 12s.

Founder lock saved: permanent Study Sessions + history UI + Supabase-only chat (never R2). Extend Phase 4C; do not rewrite Home AI. **No code until** Gate A 4C smoke pass + founder `start Phase 4D`. Doc: `FOUNDER_PHASE4D_HOME_HISTORY.md`.

### Home AI Mobile UX Simplification (Jul 18, 2026)

UI-only Founder Lock: Answer card → collapsible Visual card → max 5 primary chips (Quiz/Flashcards/Visual/Revision/Learn More) + More grid sheet. No API/AI/credit changes. Docs: `FOUNDER_HOME_AI_MOBILE_UX.md`.

**Same-day cull:** Hidden duplicate chips from UI — Cheat Sheet, 5 Min, Exam Booster, Teacher Tips (same KO paragraphs as Revision / Important Qs / Learn More). Backend tool_types kept.

### Smarter free Home chips (Jul 17, 2026)

`home_ai_tool_derive.py` rewritten — each chip is a distinct study job (active-recall cards, shuffled MCQ, timed 5-min drill, marks script, cue+scene memory). Still 0 credits / no LLM on open. Legacy cached payloads without `format` auto-refresh once free.

### CTO Working Charter (Jul 17, 2026)

Founder Lock: honesty / selfless / user-first CTO behavior; Gate A = Phase 4C careful smoke; Gate B = next coding only via `start …`. Docs: `FOUNDER_CTO_WORKING_CHARTER.md`, `FOUNDER_PHASE4C_SMOKE_CARD.md`; wired into `FOUNDER_PENDING_LOCKED.md`, `PROJECT_WORKING_RULES.md`, `.cursor/rules/examspark-cto-charter.mdc`.

**Priority stack (same day):** User → Founder → Easy/Helpful/Ethical → Profit; intent match before multi-file code.

### Phase 4C V2 harden (Jul 17, 2026)

Knowledge follow-up → version N+1 + parent chips marked stale; soft semantic duplicate Ask reuse (0 credits); Exam Booster / Common Mistakes / Teacher Tips identity chips. SQL: `home_ai_phase4c_v2_migration.sql`. Careful smoke order in `FOUNDER_PHASE4C_HOME_AI.md`.

### Phase 4C Final Hardening (Jul 17, 2026)

Founder lock: one Ask → Knowledge Object; study chips open **free** by deriving unique payloads from the KO (no AI on chip open). Explicit Regenerate remains paid. UI: Recommended + More. Dynamic chip recommendations. See `FOUNDER_PHASE4C_HOME_AI.md`.

### AuthGate token-refresh remount fix (Jul 17, 2026)

Chrome minimize / tab switch was firing Supabase `TOKEN_REFRESHED`, which rebuilt `AuthGate` → new `AppShell` → Home chat emptied and tab jumped to Home. AuthGate now ignores token refresh for UI rebuilds, debounces brief session-null blips, and keeps stable `AppShell` / tab keys.

### Study Workspace Notes loading harden (Jul 17, 2026)

Notes GET no longer blocks extras; 25s client timeout + Retry; cached notes stay visible on refresh failure; backend notes load runs off the event loop (`asyncio.to_thread`) so R2 fallback cannot freeze the API.

### Phase 4C Home AI Smart Study Workspace (Jul 17, 2026)

Home AI first answer is compact (Direct / Easy / Key Points). Successful answers persist as a Knowledge Object with `response_id`. Study chips call tool APIs with only `response_id` + `tool_type` — they never resend the full prior answer. Generate once → cache → free reopen; Regenerate is explicit and paid. New SQL: `home_ai_phase4c_migration.sql`. Founder guide: `FOUNDER_PHASE4C_HOME_AI.md`.

### Home Select AI + chip dump fix (Jul 17, 2026)

- Select AI toolbar always visible on finished Home replies; highlight text enables actions (Explain / Simplify / Ask / Memory / Copy). Fixed Flutter Web selection via `SelectableText.onSelectionChanged` (no nested SelectionArea).
- Select AI + study chips (Flashcards, Quiz, etc.) open a **bottom sheet** — they no longer paste the full prior answer into a new Home chat message.
- Phase 4C (`response_id` tools) still deferred until founder asks.

### Smart Visual diagrams delivery fix (Jul 17, 2026)

Home / Ask AI normal-mode output budget increased from 512 to 1024 tokens so the trailing `<<VISUAL_JSON>>` block is not cut off. Visual prompts now require compact structured output for explicitly visual topics (graphs, diagrams, timelines, flows, trees). Flutter graph rendering now uses `math_expressions` with implicit-multiplication normalization, fixing quadratic functions such as `x^2 - 5x + 6`. Added deterministic Math graph, Biology diagram, and History timeline widget tests. No credit, model, database, or API changes.

### Home AI chat UX fixes (Jul 17, 2026)

- Home AI reply text now stays “revealed” after scroll (no re-typewriter animation on re-visibility).
- Home AI text selection now shows a “Select AI” menu (ChatGPT-like interaction).
- Home reply chips are generated on the topic of the Home AI reply (not lecture/YouTube copy) and deduct correct credits:
  - Most chips: 5 credits
  - Mind Map + Important Questions: 10 credits (via `study_chip`)
- Home AI normal/deep token caps raised to reduce truncation on hard Maths/Physics answers.
- Visual delivery harden: stronger visual prompt, user-message visual reminder, and server fallback graph/diagram when the model skips `<<VISUAL_JSON>>` (so graph questions still render).

### Flashcards Quiz Revision smoke pass (Jul 17, 2026)

Founder confirmed Study Workspace Flashcards / Quiz / Revision (5/5/5) UI smoke after loading harden + backend up. Next smoke: Visual Notes → IQ/Mind Map → Select AI → 5 Minute Revision.

Flutter-only fix for tab loading: KeepAlive on every Study tab, `ValueKey(lectureId)` on workspace mounts, spinners only when content is empty, soft header “Updating…” while extras fetch in background. **Redis deferred** (wrong tool for tab UX — later for multi-worker AI cache). **Teacher / Groups paused** until loading smoke passes. Hot restart Flutter → open lecture once → switch tabs should be instant (same session).

### Phase 4B Study Workspace performance cache (Jul 16, 2026)

Study Workspace loads lecture content once into an in-memory session cache (`WorkspaceLectureCache`). Tab switches reuse cached Notes/Summary/Transcript/Flashcards/Quiz/Revision — no duplicate GETs or full-page spinners. Extras load in the background after notes. Reload only on header Refresh, Regenerate, or opening a different lecture.

### Phase 4B Study Workspace UI/UX (Jul 16, 2026)

Frontend polish for Study Workspace (Notes · Summary · Transcript · Flashcards · Quiz · Revision · Ask AI): shared header with subject/date/reading time, visual progress bars, premium empty states, Copy/Export actions, flashcard flip UX with local bookmark/difficult/shuffle, quiz Select→Submit→Explain→Next + completion screen. Minimal read-only backend: `GET /api/v1/lectures/{id}/transcript` (R2 text, no credits/AI). No credit or generation prompt changes.

### Pending backlog LOCKED + smoke/start runbook (Jul 16, 2026)

Frozen honest status in [`FOUNDER_PENDING_LOCKED.md`](examspark_backend/FOUNDER_PENDING_LOCKED.md): A shipped/smoke-pending · B founder manual · C next `start …` · D NOT complete (Railway live, Tavily, PYQ bank, full Teacher). Includes copy-paste uvicorn + Flutter start + SQL + smoke pass phrases. Linked from [`FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md) + [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md). No new feature code.

### 5 Minute Revision → FastAPI (Jul 16, 2026)

Home AI chip **5 Minute Revision** (5 credits) generates a short exam skim sheet via FastAPI + Qwen3, stored in Supabase `extras.payload_json` as type `five_min_revision`. Endpoints: `GET/POST /api/v1/lectures/{id}/five-min-revision`. Distinct from full **Revision Sheet** (also 5 credits). Results open in a Home bottom sheet with `SmartEducationalContent`. Tests extended in `test_extras_generation.py`.

### Founder Jul 16 night-check note (Jul 16, 2026)

Saved tonight’s review card [`FOUNDER_TODAY_JUL16_NIGHT_CHECK.md`](examspark_backend/FOUNDER_TODAY_JUL16_NIGHT_CHECK.md): today’s shipped list, backend pending, code audit, smoke pass phrases. Linked from [`FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md). Tiny doc cleanup: stale Flutter credit comments (5/5/5) + duplicate `visual_notes_prompt.py` docstring.

### Founder master checklist + Jul 16 SQL one-paste (Jul 16, 2026)

Consolidated daily founder to-do in [`FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md): SQL → uvicorn/Flutter → smoke order (Flashcards/Quiz/Revision → Visual Notes → IQ/Mind Map → Select AI) → later Realtime/Razorpay → `start PYQs`. One-paste migration: [`FOUNDER_SQL_JUL16_PENDING.sql`](examspark_backend/FOUNDER_SQL_JUL16_PENDING.sql). Aligned [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md) + [`FOUNDER_SQL_ORDER.md`](examspark_backend/FOUNDER_SQL_ORDER.md). Cursor `.plan.md` files = history only.

### Select & Ask AI — Phase 6 (Jul 16, 2026)

Students can select text in Study Workspace (Notes, Summary, Revision, Flashcards, Transcript) and run focused AI actions: Explain / Simplify / Memory Trick / Exam View / Translate / Ask follow-up (**2 credits**), or mini Quiz / Flashcards from selection (**3 credits**). FastAPI `POST /api/v1/select-ai` + `/stream`; selection-first + max 2 RAG chunks; Smart Visual Notes reuse; no auto-save. Tests: `tests/test_select_ai.py`.

### Smart Subject Understanding Rule (Jul 16, 2026)

Expanded visual decision prompts: AI must judge if plain text alone is enough before adding graphs/diagrams/tables. Per-subject guidance for Math, Physics, Chemistry, Biology, History, Geography, Economics, CS, English. Wired into notes, revision, Ask AI, Home AI via `visual_notes_prompt.py`. No code/credit changes.

### Smart Visual Notes Engine — Phase 5 (Jul 16, 2026)

Single Qwen3 call now produces optional structured visuals (graphs metadata, text/emoji diagrams, timelines, trees, cheat sheet in notes) stored in `notes.visual_payload_json`. Ask/Home AI attach `visual_payload` on SSE `done` event. Flutter `SmartEducationalContent` renders markdown, LaTeX, graphs. No extra credits, no image APIs. Migration: `notes_visual_payload_migration.sql`.

### Important Questions + Mind Map → FastAPI (Jul 16, 2026)

Home AI chips **Important Questions** (20 credits) and **Mind Map** (30 credits) now generate via FastAPI + Qwen3, stored in Supabase `extras.payload_json`. Endpoints: `GET/POST /api/v1/lectures/{id}/important-questions` and `GET/POST /api/v1/lectures/{id}/mind-map`. Results open in a bottom sheet on Home. Tests extended in `test_extras_generation.py`.

### Flashcards + Quiz + Revision → 5 credits everywhere (Jul 16, 2026)

Founder locked a new unified extras price: **Flashcards = 5**, **Quiz = 5**, **Revision = 5** everywhere in product — Home AI chips, Study Workspace, Ask/RAG lecture extras, backend constants, and Flutter labels/checks all aligned.

### Short notes → Supabase columns (Jul 16, 2026)

`summary`, `key points`, `important terms`, and `clean notes` now store in Supabase `notes` table columns instead of R2 JSON for new lectures. Transcript + clean transcript remain in R2. API notes reads, RAG indexing, and extras source text now prefer Supabase columns with legacy `r2_notes_path` fallback. Migration: `notes_short_supabase_migration.sql`. Tests: `test_notes_storage.py`.

### Revision sheet on FastAPI + Supabase (Jul 16, 2026)

Study Workspace **Revision** tab: generate exam-focused recap via Qwen3 (**5 credits**), stored in `extras.payload_json` per locked Storage Policy. Endpoints: `GET/POST /api/v1/lectures/{id}/revision`. Tests extended in `test_extras_generation.py`.

### Home AI study-action chips → FastAPI (Jul 16, 2026)

From Home screen AI replies, tapping **Flashcards**, **Quiz**, or **Revision Sheet** now generates via FastAPI (credits deducted server-side) and opens the Study Workspace for that lecture. **Learn More** triggers a follow-up Home AI call (5 credits). Other study chips remain “coming soon” until their FastAPI endpoints are built.

### Storage Architecture Policy locked (Jul 16, 2026)

Founder locked final policy in [`DATA_STORAGE_POLICY.md`](DATA_STORAGE_POLICY.md): Supabase = structured JSON + metadata + pgvector; R2 = large files + exports + temp audio only. Synced `PROJECT_CORE_RULES.md`, `TECH_STACK.md`, `ARCHITECTURE.md`, cursor rules (`examspark-core-rules`, `examspark-tech-stack`, `examspark-backend-engineering`). Flashcards/Quiz already aligned in code.

### Flashcards + Quiz storage → Supabase JSON (Jul 16, 2026)

Per locked Storage Policy: Flashcards/Quiz structured JSON now stored in Supabase `extras.payload_json` (not R2). Legacy `r2_path` rows still load with automatic backfill. Migration: `extras_payload_json_migration.sql`. Credits unchanged: Flashcards **20**, Quiz **25**.

### Flashcards + Quiz on FastAPI (Jul 16, 2026)

Study Workspace **Flashcards** (5 credits) and **Quiz / 20 MCQ** (5 credits) now generate via FastAPI + Qwen3, persist to Supabase `extras.payload_json`, metadata in `extras` table. GET = free read; POST = generate + server-side credit deduct. Flutter: `StudyWorkspace` tabs wired; `LectureService.generateFlashcards` / `generateQuiz` / `fetch*`. Tests: `tests/test_extras_generation.py`.

### Next-session backlog card (Jul 16, 2026)

Single memory doc [`FOUNDER_NEXT_SESSION.md`](examspark_backend/FOUNDER_NEXT_SESSION.md): no re-nag of passed smoke; open = Realtime+trim → Razorpay when keys → Flashcards coding when founder says start. `FOUNDER_IMPORTANT_PENDING.md` / `TODO.md` aligned. YouTube smoke marked pass.

### YouTube Link → Notes (PDF-parity + credits) (Jul 16, 2026)

Captions-only pipeline (`youtube-transcript-api`) → Qwen3 Notes/Summary; charge **35 / 65 / 100** by duration after SUCCESS. Free+ credits. Flutter Home dialog wired to FastAPI `youtube_link`. Quiz/Flashcards not bundled. SQL: `youtube_link_source_type_migration.sql`. Smoke: [`FOUNDER_YOUTUBE_LINK_SMOKE.md`](examspark_backend/FOUNDER_YOUTUBE_LINK_SMOKE.md).

### Library folders open + Profile Library Size (Jul 16, 2026)

Library subject folders were display-only (tap did nothing). Folders now open to that subject’s lectures (back → Library). Profile **Library Size** shows real lecture count. **Storage** no longer shows fake “128 MB” — honest “Soon” until R2 usage metering.

### Founder next path after Groups mock (Jul 16, 2026)

Groups mock pass → coding pause. One guide: [`FOUNDER_NEXT_AFTER_GROUPS.md`](examspark_backend/FOUNDER_NEXT_AFTER_GROUPS.md) (Realtime + trim SQL, then Session 6 Razorpay test smoke). `FOUNDER_IMPORTANT_PENDING.md` / `TODO.md` point here. No new product feature until smoke pass.

### Auto-leave groups on subscription change (Jul 16, 2026)

Trigger `trg_trim_groups_on_subscription_change` calls `fn_trim_group_memberships` when subs expire/cancel/plan change (not only refund). Migration: `subscription_change_trim_groups_migration.sql`. Free / downgrade now auto-trims memberships.

### Buy Plan sheet overflow fix (Jul 16, 2026)

`buy_plan_sheet.dart`: scroll + max-height (fixes BOTTOM OVERFLOWED), drag handle, cleaner plan compare card. Free smoke SQL: `SMOKE_ALL_ACCOUNTS_TO_FREE.sql`.

### Groups: no mock when logged in + demo seed (Jul 16, 2026)

Logged-in fetch no longer falls back to fake `group_1` cards (caused Join INSERT UUID fail). Seed: `SEED_DEMO_GROUPS.sql`. Flow unchanged: Free=lock sheet; ₹199/499/999 = 1/3/6.

### Fix Groups RLS recursion (Jul 16, 2026)

Root cause of Join showing plan **Unknown** / fake pre-joined mock group while Profile shows ₹499: Postgres `42P17` infinite recursion between `class_folders` and `class_memberships` RLS. Migration: `fix_class_folders_rls_recursion_migration.sql` (`fn_is_class_member` / `fn_is_class_teacher`). Mock Organic Chemistry no longer `isJoined: true`.

### Session live sync — credits / plan / groups (Jul 15, 2026)

`SessionLiveSync`: Supabase Realtime on `users` + `user_subscriptions` + `class_memberships`, plus tab-focus and app-resume refetch. Home/Groups/Profile update without logout. Founder: enable Realtime publication — [`FOUNDER_SESSION_LIVE_SYNC.md`](examspark_backend/FOUNDER_SESSION_LIVE_SYNC.md).

### Fix Free join UI bypass (Jul 15, 2026)

`toggleMembership` no longer mocks success after INSERT fail (was opening group page for Free). `maxGroups<=0` hard-blocks; join errors show Buy Plan sheet. Retest: [`FOUNDER_GROUP_JOIN_LIMITS_MOCK_TEST.md`](examspark_backend/FOUNDER_GROUP_JOIN_LIMITS_MOCK_TEST.md).

### Group join limits — founder mock test guide (Jul 15, 2026)

Step-by-step mock test (SQL → Free Join → lock sheet): [`FOUNDER_GROUP_JOIN_LIMITS_MOCK_TEST.md`](examspark_backend/FOUNDER_GROUP_JOIN_LIMITS_MOCK_TEST.md). Linked from `FOUNDER_IMPORTANT_PENDING.md`.

### Group join limits — server enforce + trim on refund (Jul 15, 2026)

Fail-closed Flutter `canJoinAnotherGroup`. SQL: `fn_enforce_group_join_limit` trigger + `fn_trim_group_memberships` (`group_join_limits_enforce_migration.sql`). Plan refunds call trim from `refund_service` (Free → leave all; downgrade keep newest). Docs: `CREDIT_ECONOMY.md`, `REFUND_POLICY_AND_PROCESS.md`.

### Refund policy + keys checklist (Jul 15, 2026)

Founder: [`FOUNDER_PAYMENT_KEYS_WHEN_READY.md`](examspark_backend/FOUNDER_PAYMENT_KEYS_WHEN_READY.md) (Razorpay + Play `.env` paste). Policy/process: [`REFUND_POLICY_AND_PROCESS.md`](REFUND_POLICY_AND_PROCESS.md). Play guide expanded with license-tester + Console refund steps. Server: `refund_service.py` + Razorpay `refund.processed` / Play voided RTDN → mark refunded, cancel sub, clawback credits (idempotent).

### Google Play Billing — Android code ready (Jul 15, 2026)

Play product catalog (`examspark_plan_*` / `examspark_pack_*`), FastAPI `google_play_gateway` + Developer API verify (`play_billing_verify.py`), Flutter `in_app_purchase` + Android purchase → `/verify` → same activate/credits path. Live Store listing not required — Internal testing + service account. Guide: [`FOUNDER_GOOGLE_PLAY_BILLING.md`](examspark_backend/FOUNDER_GOOGLE_PLAY_BILLING.md). PhonePe still stub. Razorpay Web unchanged (keys pending).

### Subscriptions / Credits UX polish (Jul 15, 2026)

Plans screen: remaining + used (est.) + plan allotment, `CreditUsageDisplay` line, Current Plan by **plan id**, pull-to-refresh. Credit history list with timestamps (`getCreditTransactions`). Student plans vs separate Teacher section. INR credit packs (removed USD top-ups + Extra Hours). Pay buttons still call Session 6 flow — no fake success without keys.

### Session 6 — Razorpay Web test-mode (Jul 15, 2026)

FastAPI: real Razorpay order create, checkout signature verify, webhook HMAC + replay-safe fulfill, activate `user_subscriptions` / credit packs, `fn_grant_credits` + `credit_history` (plan/pack credits only — no Free 50 stacked). Flutter Web: `PaymentRepository` → Checkout.js → verify; Plans screen refreshes plan + credits; Android stays Google Play stub. Tests: signature fail, duplicate webhook, catalog amounts. Guide: [`FOUNDER_RAZORPAY_SESSION6.md`](examspark_backend/FOUNDER_RAZORPAY_SESSION6.md). `PAYMENT_ARCHITECTURE.md` → test-mode ready.

### Audio lock UI — ₹499 panel on Recorder (Jul 15, 2026)

Record + Upload Audio show a full **Audio locked** panel (₹499+, View Plans) instead of mic/Select File. Setup screen blocks audio flow before opening recorder. Lock copy hardcoded to ₹499. PDF/Photo tab stays open.

Anonymous 1-prompt trial now saved via `shared_preferences` ([`guest_trial_store.dart`](examspark_frontend/lib/core/services/guest_trial_store.dart)) so refresh/reopen does not reset. Clearing browser/app data can still reset — server IP rate-limit planned when guest Ask AI is real.

### Founder cheat sheet — Credit rules as shipped (Jul 15, 2026)

Simple Hindi explanation of plan unlock + credits (Session 5 as implemented): [`FOUNDER_CREDIT_RULES_AS_SHIPPED.md`](FOUNDER_CREDIT_RULES_AS_SHIPPED.md). Docs only — no code change.

### Session 5 Free-tier smoke guide expanded (Jul 15, 2026)

Founder guide in [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md): UUID copy → `fn_user_plan_tier` SELECT → expire paid `user_subscriptions` (not credits zero) → F1–F5 → rollback. Docs only — no code / no new migration.

### Session 5 — Server-side plan-tier gating (Jul 15, 2026)

Rule 6 enforced on FastAPI: **plan unlock → credits → AI → deduct on SUCCESS**. Structured **403 FEATURE_LOCKED** payload (`code`, `message`, `feature`, `current_plan`, `required_plan`) on lecture process (record / diagram / PDF) and Ask/Home AI (JSON + SSE). Flutter: Recorder soft-gates with `PlanTierGating` + snackbar; ProcessingScreen / LectureService surface lock message (not generic network error). Unit tests: Free blocks Record/Diagram; Free allows Ask AI + PDF. Aligns with CREDIT_ECONOMY v2.1 (`free` / `plan_199` / `plan_499` / …). **No new SQL** if `fn_user_plan_tier` already applied. Smoke: [`FOUNDER_IMPORTANT_PENDING.md`](FOUNDER_IMPORTANT_PENDING.md) Session 5 Free-tier lock steps. Non-goals (still Session 6+): Razorpay, Flashcards/MCQ FastAPI, Tavily/PYQ.

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
