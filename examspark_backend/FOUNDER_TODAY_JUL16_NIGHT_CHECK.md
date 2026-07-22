# Jul 16, 2026 — Tonight check (side note)

> **Purpose:** Raat ko smoke / review. Daily master list: [`FOUNDER_NEXT_SESSION.md`](FOUNDER_NEXT_SESSION.md).  
> **Rule:** Code shipped ≠ UI smoke pass. Pass messages chat mein likho.

---

## Aaj kya implement hua

| Area | Status | Kahan |
|------|--------|--------|
| Flashcards / Quiz / Revision FastAPI | Code done | `lecture_service.py`, `lectures.py`, Study Workspace |
| Credits 5 / 5 / 5 | Code done | `credit_costs.py` + Dart |
| Important Questions (20) + Mind Map (30) | Code done | Home chips + FastAPI GET/POST |
| Short notes → Supabase columns | Code done | `notes.clean_notes` etc. |
| Smart Visual Notes | Code done | `visual_payload_json`, `smart_educational_content.dart` |
| Select AI (2 / 3 credits) | Code done | `/api/v1/select-ai/stream` + `select_ai/` widgets |
| **5 Minute Revision** (5 credits) | Code done | Home chip → `GET/POST .../five-min-revision` |
| Home chips wired | Partial | Flashcards/Quiz/Revision/IQ/Mind Map/Learn More/Cheat→Notes/**5 Min Revision**; **PYQs = coming soon** |
| Founder SQL one-paste | Prepared | [`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql) |
| Automated tests | Green | extras + visual + notes + select_ai (+ 5 Min Revision) |

---

## Raat smoke order

1. **SQL** (agar abhi tak nahi) — paste [`FOUNDER_SQL_JUL16_PENDING.sql`](FOUNDER_SQL_JUL16_PENDING.sql) in Supabase SQL Editor → Run  
2. **Backend** — `python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000`  
3. **Flutter** — `flutter pub get` → restart (`R`) · `FASTAPI_BASE_URL` set  
4. Smoke → chat pass:

| # | Test | Pass message |
|---|------|----------------|
| 1 | Flashcards → Quiz → Revision (5/5/5) | `Flashcards Quiz Revision smoke pass` |
| 2 | Visual Notes (Physics/Math Notes + Home AI) | `Visual Notes 5A smoke pass` |
| 3 | Important Questions + Mind Map (Home; 20/30) | after #2 — report pass/error |
| 4 | Select AI (Explain 2 / Quiz 3) | `Select AI smoke pass` |
| 5 | 5 Minute Revision (Home; 5 credits) | `5 Minute Revision smoke pass` |

---

## Backend pending (coding / product)

**Abhi naya feature mat mangna — pehle smoke.** Phir:

| Pending | Type |
|---------|------|
| Founder SQL run (agar pending) | Manual |
| Founder UI smoke (upar) | Manual |
| Realtime 3 tables + trim SQL | Manual (coding done) |
| Razorpay Session 6 keys + smoke | Manual when keys ready |
| **PYQs → FastAPI** | Next coding (`start PYQs`) |
| Answer Key still on old `process-lecture` edge | Legacy gap |
| Select AI Bookmark/save to DB | Stub (“coming soon”) |
| Tavily / PYQ bank / paid Translate API | Later |
| Known: deduct-then-persist gap (credits cut, upsert fail → empty) | Fast-follow when you ask |

Not “missing from today” — intentional hold.

---

## Code audit (Jul 16 review)

### Fix-worthy (chhote, non-blocker) — agent fixed in same pass

1. Stale Flutter doc comments (Flashcards 20 / Quiz 25) → corrected to **5 / 5**
2. Duplicate docstring in `visual_notes_prompt.py` → removed

### Known architecture gap (pehle se)

3. Extras: **deduct → then upsert** — if Supabase upsert fails after deduct, credits gone with nothing saved. Fix when founder asks.

### Intentional / not bugs

4. Select AI plan gate = `ASK_AI` (Free+) — by design  
5. Select AI selection via clipboard — SDK limit; fragile if clipboard cleared mid-flow  
6. Cheat Sheet = Notes visual payload, not paid extra  
7. PYQs Home chip = “coming soon” until `start PYQs` (5 Minute Revision shipped)  
8. Full notes `.md` may still use R2 legacy; short fields in Supabase — storage policy

### Looks solid

- Credit deduct **after** AI success (Select AI + extras; tests cover no-deduct-on-fail)  
- Plan unlock before credits  
- Router in `examspark_backend/main.py`  
- Flutter Select AI under `lib/presentation/widgets/select_ai/`

---

## Prefer reply (copy-paste)

`Flashcards Quiz Revision smoke pass` · `Visual Notes 5A smoke pass` · `Select AI smoke pass` · `5 Minute Revision smoke pass` · `start PYQs`
