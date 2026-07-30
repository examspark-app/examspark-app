# ExamSpark — Pending LOCKED (Jul 16, 2026)

> **Purpose:** Honest freeze — kya shipped hai, kya aapka haath, kya next coding, kya **complete nahi**.  
> **Rule:** Is list ko random polish se mat badlo. Pass / `start …` ke baad hi update.  
> **CTO charter (Founder Lock):** [`FOUNDER_CTO_WORKING_CHARTER.md`](FOUNDER_CTO_WORKING_CHARTER.md)  
> **NOW smoke (Gate A):** [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md)  
> **Daily smoke steps (older):** [`FOUNDER_NEXT_SESSION.md`](FOUNDER_NEXT_SESSION.md)  
> **Night card:** [`FOUNDER_TODAY_JUL16_NIGHT_CHECK.md`](FOUNDER_TODAY_JUL16_NIGHT_CHECK.md)

**Honest line:** Core **Student AI backend code** mostly done. Full product backend (Railway live, Tavily, Teacher, PYQ bank) **complete nahi**.

### Gate A — do this before any new coding (Jul 17, 2026)

Phase 4C careful one-time smoke → [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md).  
**Gate A:** Founder `ok pass` Jul 18, 2026.  
**Gate B:** Phase 4D History — **PASS locked Jul 18**.  
**Gate B:** `start PYQs` smoke bank + Important Qs weightage + Shape 1 + chip Regenerate disclaimer — **PASS locked Jul 18 night** (`all pass ok lock`).

### Freeze — ~70% core PASS (Jul 22, 2026 night)

Founder: **`accha lock pass`** + no more feature/backend churn.  
**Freeze / lock / freeze lock (Founder Lock Jul 22 night):** jab founder ye bole → agent **backend code / business logic edit nahi karega**. Smoke/test pass ke baad re-edit se naye bugs banne ka risk — isliye freeze = status answers + docs lock notes only. Backend sirf jab founder us lane ke liye explicitly `start …` bole. UI only jab founder screen name kare + `start …` bole.

- Core student AI / notes / Ask+Home language lock / YouTube+image notes path = **PASS locked**
- **No backend / business-logic code changes** unless founder says `start …` for that work
- Prefer: status answers, docs lock notes — not “small fixes” to Python/FastAPI after pass
- Agar change hoga → **UI/UX only** (founder must name the screen + `start …`)
- Remaining ~30% = Railway live, Teacher, polish, etc. — **alag session**, not drive-by
---

## A — Code shipped (founder UI smoke pending)

| Feature | Credits | Notes |
|---------|---------|--------|
| Flashcards / Quiz / Revision | 5 / 5 / 5 | Study Workspace FastAPI — **UI smoke PASS Jul 17, 2026** |
| Important Questions / Mind Map | 20 / 30 | Home chips |
| Smart Visual Notes | (in notes) | `visual_payload_json` |
| Select AI | 2 / 3 | `/api/v1/select-ai/stream` |
| 5 Minute Revision | 5 | Home chip; separate from full Revision Sheet |
| Session 6 Razorpay | — | **Code** shipped; keys + smoke alag |
| Jul 16 SQL one-paste | — | [`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql) |

Also already **smoke-passed earlier:** Groups join limits · YouTube Link → Notes.

---

## B — Founder manual (coding nahi)

| # | Action |
|---|--------|
| B1 | Run Jul 16 SQL if not done (section “Start + SQL” below) |
| B2 | UI smoke + chat pass messages (section “Smoke order” below) |
| B3 | Realtime ON: `users` · `user_subscriptions` · `class_memberships` + trim SQL — [`FOUNDER_SESSION_LIVE_SYNC.md`](FOUNDER_SESSION_LIVE_SYNC.md) |
| B4 | Razorpay Test keys + smoke when ready — [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md) |
| B5 | **Git commit** — today’s work disk pe safe; **GitHub pe nahi** jab tak aap bolo `commit today` |

---

## C — Next coding (Gate B — only after Gate A smoke pass)

**Hard gate:** Founder must say exactly `start …` for **one** row. Agents must refuse random polish / Teacher / Tavily / PYQ / Railway until then.

| Say in chat | Work |
|-------------|------|
| `start PYQs` / `ok start` | PYQ metadata bank + vector match — **PASS locked Jul 18 night** · guide [`FOUNDER_START_PYQS.md`](FOUNDER_START_PYQS.md) · Important Qs uses weightage; Home answer skips PYQ match; no PYQs More-chip |
| `start Tavily` | Home/Ask Priority 4 web — **CODE Jul 18** · guide [`FOUNDER_TAVILY.md`](FOUNDER_TAVILY.md) — founder: add `TAVILY_API_KEY` + smoke |
| `start Railway deploy guide` | Production FastAPI (Dockerfile hai; live deploy pending) |
| ↳ **Deploy-time bundle (same session)** | **AI kill switch + rate limit** — cyber / 50k flood pe paid AI OFF karne ke liye. **Abhi mat banao** — sirf jab Railway live deploy ho. Cloudflare DDoS = alag `start web deploy guide` |
| `start Phase 4D` / `start home history` | Home AI Study History — **PASS locked Jul 18** · [`FOUNDER_PHASE4D_HOME_HISTORY.md`](FOUNDER_PHASE4D_HOME_HISTORY.md) |
| YouTube Whisper + full RAG | **CODE Jul 18** — SQL [`rag_match_user_wide_migration.sql`](rag_match_user_wide_migration.sql) · guide [`FOUNDER_YOUTUBE_WHISPER_FALLBACK.md`](FOUNDER_YOUTUBE_WHISPER_FALLBACK.md) — founder smoke pending |
| Teacher / Groups | Teacher Share loop **CODE Jul 23** — SQL + smoke: [`FOUNDER_TEACHER_SHARE.md`](FOUNDER_TEACHER_SHARE.md) |

---

## D — Explicit NOT complete

- Railway **production** live
- **Deploy-time security (locked on list Jul 26):** AI kill switch (`AI_ENGINE=OFF`) + per-user/IP rate limit — **build only with** `start Railway deploy guide` (not local feature work). Cloudflare shield with web deploy.
- Tavily web search — **code live Jul 18**; needs founder `TAVILY_API_KEY` + smoke ([`FOUNDER_TAVILY.md`](FOUNDER_TAVILY.md))
- Full PYQ bank UI / Home PYQs chip (smoke bank + Important Qs Focus **locked**; chip intentionally hidden)
- Full Teacher dashboard (revenue, analytics, student lists)
- Groups Realtime checklist (until you finish B3)
- Redis shared cache
- Phase 6 final polish / dead-code delete
- Answer Key still on old `process-lecture` edge (legacy)

---

## E — Next work queue (freeze; wait for `start …`)

**Saved:** Jul 22, 2026 night · Founder-ordered FUTURE backlog.  
**Freeze still ON.** Docs only until founder says `start [item]` for **ONE** item. No coding, no backend/app logic edits, no drive-by polish.

| # | Work | Notes |
|---|------|--------|
| 1 | Teacher **OR** student Groups | Prefer `start Teacher Coupon` then Discovery — see [`FOUNDER_TEACHER_COUPON.md`](FOUNDER_TEACHER_COUPON.md) |
| 2 | Firebase setup + notifications | In-app shipped with coupon SQL; FCM → [`FOUNDER_FCM_SETUP.md`](FOUNDER_FCM_SETUP.md) |
| 3 | Settings implement | |
| 4 | Share features | User shares photo/documents → share click shows WhatsApp, ChatGPT, ExamSpark app, etc. (system share sheet / share targets) |
| 5 | UI polish + navigation | |
| 6 | Extra file remove + polish carefully | **Ask before delete** |
| 7 | Extra pages | Terms & Conditions · Privacy Policy · Refund & Cancellation Policy |
| 8 | Admin panel | **Later only** — founder will say when; **do not start now** |

**Remind:** Coding starts only after founder says e.g. `start Groups` / `start Firebase` / `start Settings` — **one item at a time**. Admin panel = not in queue until founder explicitly calls it.

---

## Start servers (backend + frontend)

### Terminal 1 — Backend (open rakho)

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Verify:** browser open `http://localhost:8000/` → `"ExamSpark Backend Active"`  
(Not `/health`.)

### Terminal 2 — Flutter

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter pub get
flutter run -d chrome
```

Hot restart: **`R`**.  
`.env` must have: `FASTAPI_BASE_URL=http://localhost:8000` (or your PC IP for phone).

---

## SQL once (agar abhi tak nahi)

1. Supabase Dashboard → **SQL Editor** → New query  
2. Open file [`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql) → copy all → paste → **Run**  
3. Agar pehle chalaya / “already exists” → OK, skip  

Or separately: `extras_payload_json_migration.sql` → `notes_short_supabase_migration.sql` → `notes_visual_payload_migration.sql`

---

## Smoke order + pass phrases

| # | Test | Chat mein likho |
|---|------|-----------------|
| 1 | Flashcards → Quiz → Revision (5/5/5) | `Flashcards Quiz Revision smoke pass` |
| 2 | Visual Notes (Physics/Math Notes + Home AI) | `Visual Notes 5A smoke pass` |
| 3 | Important Questions + Mind Map (20/30) | report pass / error |
| 4 | Select AI (Explain 2 / Quiz 3) | `Select AI smoke pass` |
| 5 | 5 Minute Revision (Home; 5) | `5 Minute Revision smoke pass` |

Error → screenshot / exact text. Naya plan mat kholo.

Detail steps: [`FOUNDER_NEXT_SESSION.md`](FOUNDER_NEXT_SESSION.md)

---

## Prefer reply (copy-paste)

**NOW (Gate A):** see [`FOUNDER_PHASE4C_SMOKE_CARD.md`](FOUNDER_PHASE4C_SMOKE_CARD.md) pass block.

Older (if re-checking): `Flashcards Quiz Revision smoke pass` · `Visual Notes 5A smoke pass` · `Select AI smoke pass` · `5 Minute Revision smoke pass` · `groups + realtime checklist done` · `commit today`

**Gate B (after 4C smoke):** `start PYQs` · `start Railway deploy guide` · `start Tavily`

**Freeze queue (§E):** `start Groups` · `start Firebase` · `start Settings` · `start Share` · `start UI polish` · … — **one at a time**. Admin panel mat start karo jab tak founder alag se na bole.