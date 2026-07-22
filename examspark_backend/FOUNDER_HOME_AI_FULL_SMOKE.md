# Home AI — Full Smoke Guide (everything implemented so far)

**Date:** Jul 18, 2026  
**Scope:** Phase 4C + smarter chips + Mobile UX + duplicate cull  
**Not in this smoke:** Phase 4D History (future)

---

## A) Start servers (do this first)

### Terminal 1 — Backend

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Verify:** browser open → `http://localhost:8000/`  
Expect: `"ExamSpark Backend Active"` (or similar JSON with `home_ai`)

### Terminal 2 — Frontend (Flutter Web)

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter pub get
flutter run -d chrome --web-port=8080
```

**After code changes:** terminal me capital **`R`** (hot restart)

**.env (Flutter):** `FASTAPI_BASE_URL=http://localhost:8000`  
**No new .env keys** for this smoke.

---

## B) SQL (agar abhi tak nahi chalaaya)

Supabase → **SQL Editor** → New query → paste → **Run** (order matter)

| # | File | OK when |
|---|------|---------|
| 1 | `examspark_backend/home_ai_phase4c_migration.sql` | No fatal error / already exists OK |
| 2 | `examspark_backend/home_ai_phase4c_v2_migration.sql` | Result: `phase4c_v2_ok` |

Agar pehle chal chuka → **skip**.

---

## C) Smoke order (ek baar, careful)

Login → Home tab. Credits note karo pehle.

| # | Kya karo | Expect | Pass phrase |
|---|----------|--------|-------------|
| 1 | Ask: `What is photosynthesis?` | Answer card · Visual card (agar ho) · **5 chips:** Quiz, Flashcards, Visual, Revision, Learn More · **More** button · credits **−5 once** | `4c ask pass` |
| 2 | Tap **Flashcards** | Bottom sheet (chat me paste nahi) · Free/Cached · credits **same** | `4c chips free pass` |
| 3 | Flashcards band → dubara kholo | Instant **Cached** · 0 credits | (same) |
| 4 | Tap **Quiz** | MCQ UI only · alag format | `4c unique chips pass` |
| 5 | Tap **More** | Grid: Important Qs · Memory · Mind Map · Common Mistakes · PYQs · **NO** Cheat Sheet / 5 Min / Exam Booster / Teacher Tips | `4c more cull pass` |
| 6 | More → **Mind Map** or **Common Mistakes** | Alag layout · free | (unique) |
| 7 | Naya ask: `photosynthesis meaning` | Fast reuse / **0 extra** credits (same server) | `4c semantic pass` |
| 8 | Ask: `Explain in Hindi` | Naya answer (charged) · naya bubble + chips | `4c v2 follow-up pass` |
| 9 | Library lecture → **Notes**; Chrome minimize → restore | Notes load · Home wipe nahi · login same | `notes + session pass` |

**Stop rule:** Error / galat credit cut → screenshot + `smoke fail` — aage mat badho.

---

## D) Prefer reply (jab sab OK)

```
4c ask pass · 4c chips free pass · 4c unique chips pass · 4c more cull pass · 4c semantic pass · 4c v2 follow-up pass · notes + session pass
```

Phir next: Phase 4D History (`start Phase 4D`).

---

## E) Quick fail checklist

| Symptom | Fix |
|---------|-----|
| Chips / response_id missing | SQL 1+2 run + naya Ask |
| `Not Found` on Home AI | Backend restart (`main:app` port 8000) |
| Old generic chips | Chip dubara kholo (legacy free upgrade) ya naya Ask |
| UI purana | Flutter capital **`R`** |
| Backend not Active | Terminal 1 command dubara |
