# Founder smoke — YouTube Link → Notes

> Jul 16, 2026 — captions → Notes + Summary; Quiz/Flashcards still separate credits.

## One-time setup

1. Supabase SQL Editor → run all of  
   [`youtube_link_source_type_migration.sql`](youtube_link_source_type_migration.sql)  
   **Verify:** Success (no red error).

2. Backend terminal:

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
pip install youtube-transcript-api
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

3. Flutter: hot restart **`R`** (or re-run Chrome).

## Test steps

| # | Action | Expected |
|---|--------|----------|
| 1 | Free account with **≥35** credits | Profile shows balance |
| 2 | Home → YouTube icon → paste **short public** video **with CC/captions** | Processing → Notes |
| 3 | Credits after success | Drop by **35** (≤20 min), **65** (20–40), or **100** (40–60) |
| 4 | Paste >60 min or no-caption / private video | Error message; **credits unchanged** |
| 5 | Quiz later (when that button is live) | Separate **25** credits — not included in YouTube fee |

Pass line: `YouTube Link smoke pass`

## .env

No new keys. Needs existing `FASTAPI_BASE_URL` + OpenRouter (same as PDF notes).

## Rollback

- Stop using YouTube icon.
- Optional: leave SQL constraint in place (harmless).
