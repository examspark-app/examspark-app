# ExamSpark — Final smoke / mock test (Jul 21, 2026)

**Servers (already for this session):**
- Backend: `http://127.0.0.1:8000` (docs OK)
- Frontend: `http://localhost:8080` (Chrome)

If either died, restart:

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

After code pull: Flutter me **hot restart** (`R` in the Flutter terminal), not only `r`.

---

## Code audit snapshot (CTO)

| Area | Status |
|------|--------|
| YouTube credits 10/20/40 | OK — backend + Flutter constants |
| YouTube Whisper Turbo-only | OK — `allow_non_turbo_fallback=False` |
| Audio lock Free/₹199 | OK — still ₹499+ (unchanged) |
| YouTube unlock Free+ | OK |
| After YouTube → StudyWorkspace | OK — `OpenWorkspaceBridge` |
| Eager RAG index after process | OK |
| Multilingual Q&A | OK — Home AI + Ask AI use `language_hint` lock/override |
| Automated tests | whisper + youtube + dedupe + language_hint suites pass |

**No new .env / SQL** for this smoke.

---

## Mock test — do in order

Write credits balance before each billable step. Tick Pass / Fail.

### A. Multilingual (Home AI) — free-ish (Ask credits)

| # | You type | Expected |
|---|----------|----------|
| A1 | `What is Newton's first law?` | English answer |
| A2 | Same chat: `हिंदी में बताओ` or `answer in hindi` | Hindi answer |
| A3 | Same chat: `force kya hai` (roman Hindi after Hindi lock) | Stays Hindi (conversation lock) |
| A4 | `answer in english` | Switches to English |
| A5 | Optional: `answer in hinglish` | Mixed Hinglish |

Credits: ~5 per Ask (normal). Fail if answer language ignores lock or copies notes language blindly.

### B. Multilingual (Library Ask AI)

| # | Action | Expected |
|---|--------|----------|
| B1 | Open any lecture → Ask AI: English question | English |
| B2 | `বাংলায় বলো` or `answer in bengali` | Bengali (if model supports) |
| B3 | First Ask on **fresh** YouTube lecture | Streams reasonably fast (RAG already indexed) |

### C. YouTube credits + Turbo + workspace

| # | Action | Expected |
|---|--------|----------|
| C1 | YouTube dialog cost text | Shows **10/20/40** (not 40/80/120) |
| C2 | Short public video with CC (≤30 min) | Notes done; **−10** credits; title ≈ video name |
| C3 | After done | **StudyWorkspace** opens (Library-like tabs), **not** old notes_result chips fail |
| C4 | Tap Flashcards or Quiz | Generates OK (no “Failed to generate content”) |
| C5 | Paste **same** link again | “already added…”, **0** credits; backend log `Layer1 YouTube dedupe HIT` |
| C6 | (Optional) No-CC public video | Notes via Whisper Turbo; still 10/20/40 by length |

### D. Audio lock polish (Free or ₹199 account)

| # | Action | Expected |
|---|--------|----------|
| D1 | Tap mic / Record | Lock sheet or lock page — **View Plans** |
| D2 | YouTube icon | Still works (unlocked on Free) |

Use a **Free** test account if your main account is ₹499 — otherwise mic will correctly unlock.

### E. Tavily (only if `TAVILY_API_KEY` in `.env`)

| # | Action | Expected |
|---|--------|----------|
| E1 | `What are today's current affairs headlines in India?` | Source: Live web; note about **10** credits |
| E2 | Syllabus ask e.g. `What is photosynthesis?` | **No** live web charge (normal Ask / notes) |

---

## Pass phrase

When A–D look good, reply: **`all pass jul21 smoke`**

If something fails, send: step id + screenshot + credits before/after + backend last error lines.

## Rollback

No SQL for this batch. Revert recent YouTube credit / whisper / OpenWorkspaceBridge commits if needed (ask CTO before git reset).
