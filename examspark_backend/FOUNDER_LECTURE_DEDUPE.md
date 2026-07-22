# ExamSpark — Duplicate content detection (per-student)

**What it does:** Same student re-uploading the same audio / same YouTube link / re-recording near-identical lecture content does **not** pay credits again and does **not** add duplicate RAG vectors.

| Layer | When | Check | Credits |
|-------|------|-------|---------|
| **1** | Before any AI | YouTube video ID **or** audio file SHA-256 hash | **0** |
| **2** | After Whisper, before notes | Transcript embedding vs **this student's** `clean_transcript` RAG (≥ 0.95) | **0** (Whisper API may already have run — that is OK) |

**Privacy:** Never compares Student A’s files to Student B’s.

**RAG store (related lock):** Only **audio** (`recorded` / `uploaded_audio`) and **YouTube** go into `rag_documents`. PDF/photo uploads stay out — Ask AI still answers from that lecture’s notes; chips use Knowledge Object. Optional purge of old PDF chunks: `rag_exclude_pdf_photo_cleanup.sql`.

---

## Manual setup (you must do this)

### 1. Run SQL in Supabase

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your ExamSpark project  
2. Left menu → **SQL Editor** → **New query**  
3. Open this file on your PC:  
   `examspark_backend/lecture_dedupe_migration.sql`  
4. Copy **all** text → paste into SQL Editor → click **Run**  
5. Verify bottom results show:
   - `lectures_dedupe_cols` = `ok`
   - `match_own_transcript_near_dup` = `ok`

If you see errors about columns already existing — that is usually fine (safe re-run).

### 2. Restart backend

In the terminal where FastAPI runs:

1. Stop with `Ctrl+C`  
2. Start again:

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

### 3. .env

**No new .env keys.** Uses existing OpenRouter embedding key (same as RAG).

### 4. Flutter

Hot restart the app (not only hot reload) after pull:

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter run -d chrome --web-port=8080
```

---

## How to test

| # | Test | Expected |
|---|------|----------|
| 1 | Upload the **exact same** audio file twice | 2nd time: snackbar *“already added…”*, opens existing notes, **0 credits** charged |
| 2 | Submit the **same YouTube link** twice | Same as above (Layer 1 video ID) |
| 3 | Re-record the **same lecture** (different file) | 1st: normal charge. 2nd: after Whisper, Layer 2 may reuse notes at **0 credits** (needs first lecture RAG-indexed — Ask AI once on first lecture if unsure) |

**Note:** Layer 1 only works for lectures processed **after** this SQL (hash / video ID are saved on success). Older lectures may still be caught by Layer 2 if their transcripts are in RAG.

### Verify `youtube_video_id` is saved (if same link still regenerates)

In Supabase **SQL Editor**, run:

```sql
select id, title, youtube_video_id, status, duplicate_of_lecture_id, created_at
from lectures
where source_type = 'youtube_link'
order by created_at desc
limit 5;
```

- `youtube_video_id` **NULL** on a `done` row → check backend logs for `stamp_lecture_identity failed` (re-process one video after fix).
- `youtube_video_id` set but re-paste still slow → check uvicorn for `Layer1 YouTube dedupe HIT` vs `MISS`.

---

## Rollback

If something breaks Library list (`duplicate_of_lecture_id` column missing):

1. Re-run `lecture_dedupe_migration.sql`  
2. Or temporarily remove `.isFilter('duplicate_of_lecture_id', null)` from Flutter `getLecturesForUser` (ask CTO before editing)

To stop using dedupe without dropping columns: no code flag — ask CTO to comment out Layer 1/2 calls.

---

## Files

- `lecture_dedupe_migration.sql`
- `app/services/lecture_dedupe.py`
- `app/services/lecture_service.py` (audio + YouTube pipelines)
- Flutter: `processing_screen.dart`, `lecture_service.dart`
