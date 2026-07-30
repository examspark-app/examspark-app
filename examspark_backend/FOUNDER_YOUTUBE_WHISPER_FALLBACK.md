# ExamSpark — YouTube Whisper fallback + full-store RAG (Founder)

**Locked intent Jul 18, 2026** (plan implement).

## YouTube Link → Notes

1. Try **captions** first (fast, free STT).
2. If no captions → **temp audio** via `yt-dlp` → Groq Whisper → **delete temp audio**.
3. Same notes/R2/RAG path as before.
4. Credits = **10 / 20 / 40** (≤30 / 30–60 / 60–90 min). Max **90** min.
5. Whisper fallback = **Turbo only** (no non-Turbo — saves API cost).

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
pip install yt-dlp
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

**Smoke:** video with CC → message says `via captions`. Video without CC → `via whisper` / Whisper Turbo (needs ffmpeg on PATH for mp3 extract).

## Full-store RAG (Workspace Ask + Home when RAG)

1. Supabase → SQL Editor → open `rag_match_user_wide_migration.sql` → **Run**
2. Verify: `match_rag_documents_user` = `ok`
3. Restart backend

Open lecture chunks first; other lectures only if similarity ≥ ~0.62 and not duplicate.

## Tavily

Still **NOT live**. `web_deferred` only logs. Needs founder `start Tavily` to wire API.

## Shape 1/2/3

Already on Workspace `_ASK_SYSTEM` (same as Home). OMIT filler sections.
