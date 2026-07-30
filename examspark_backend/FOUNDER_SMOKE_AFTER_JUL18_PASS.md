# ExamSpark — Smoke list AFTER last mock pass (Jul 18 night)

> Last lock: Phase 4D + PYQs `all pass ok lock`.  
> **Is list = uske baad naya code.** Ek-ek karke tick karo.

**Credits note:** Live web (Tavily) = **10** normal / **20** deep (fixed Jul 18).

---

## Before you start

1. Backend running (`uvicorn` port 8000)  
2. Flutter Chrome running  
3. SQL already run (if not):
   - `lecture_dedupe_migration.sql`
   - `rag_match_user_wide_migration.sql` (full-store RAG — if not done)
4. Optional: `rag_exclude_pdf_photo_cleanup.sql` (old PDF chunks hataane ke liye)  
5. `.env`: `TAVILY_API_KEY=...` → backend **restart** after paste  
6. Note your **credit balance** before each test  

---

## A — Lecture duplicate (0 credits on reuse)

| # | Test | How | Pass if |
|---|------|-----|---------|
| A1 | Same audio twice | Upload/record → done → **same file** again | Snackbar “already added…”; opens old notes; **0 credits** 2nd time |
| A2 | Same YouTube twice | Same link → Notes twice | Same snackbar; **0 credits** 2nd time |
| A3 | Re-record (optional) | Same lecture, **new** audio file | Layer 2 may reuse after Whisper; **0** notes charge (first lecture RAG-indexed help karta hai) |

SQL verify: `lectures_dedupe_cols` = ok (migration run).

---

## B — RAG store (audio + YouTube only)

| # | Test | How | Pass if |
|---|------|-----|---------|
| B1 | Audio/YouTube Ask AI | Lecture from record/YouTube → Ask AI | Answers from notes/transcript (RAG OK) |
| B2 | PDF/photo | Upload PDF or photo → notes banen | Notes/chips kaam karein; **shared RAG mein PDF/photo na jaye** (dusre lectures ke Ask pe ye content “pollute” na kare) |

---

## C — YouTube Whisper fallback (if not smoked yet)

| # | Test | How | Pass if |
|---|------|-----|---------|
| C1 | Video **with** captions | YouTube → Notes | Notes OK; credits 40/80/120 by length |
| C2 | Video **without** captions (optional) | Known no-caption short video | Whisper fallback → notes; temp audio not kept |

Needs: `yt-dlp` installed on backend machine (see `FOUNDER_YOUTUBE_WHISPER_FALLBACK.md`).

---

## D — Tavily (smart / last resort) — **10 credits**

| # | Test | How | Pass if |
|---|------|-----|---------|
| D1 | Syllabus | Home: `Explain photosynthesis` | **No** Live web; charge **5**; no waste of Tavily free API |
| D2 | Current affairs | Home: `What are today's current affairs headlines in India?` | Source **Live web search**; charge **10**; log `tavily_usage usable=True tavily_credits=1` |

Balance before D2 ≥ **10**.

---

## Pass chat lines (jab section OK)

- Dedupe: `dedupe smoke pass`  
- RAG PDF policy: `rag pdf policy pass`  
- YouTube Whisper: `youtube whisper smoke pass`  
- Tavily: `Tavily smoke pass`  

Ya ek saath: `jul18 night features smoke pass`

---

## Guides

- [`FOUNDER_LECTURE_DEDUPE.md`](FOUNDER_LECTURE_DEDUPE.md)  
- [`FOUNDER_TAVILY.md`](FOUNDER_TAVILY.md)  
- [`FOUNDER_YOUTUBE_WHISPER_FALLBACK.md`](FOUNDER_YOUTUBE_WHISPER_FALLBACK.md)  
