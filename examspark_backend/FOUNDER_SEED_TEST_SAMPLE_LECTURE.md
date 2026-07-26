# Founder — Seed TEST Sample Lecture (no mic)

Use when desktop has **no microphone** but you need to test:
**Share to Group → student opens → real Notes / Quiz / Transcript.**

Does **not** call Whisper or Qwen3. Pure SQL + a tiny backend fallback for Transcript.

---

## 1. Run SQL (required)

1. Open **Supabase → SQL Editor → New query**
2. Open file: `examspark_backend/FOUNDER_SEED_TEST_SAMPLE_LECTURE.sql`
3. Replace **`YOUR_EMAIL@gmail.com`** with the **teacher** login email (same account you use in the app)
4. **Run**
5. Verify query should show one row:
   - `title` = `TEST — Sample Lecture`
   - `status` = `done`
   - `source_type` = `recorded`
   - `has_notes` / `has_quiz` / `has_inline_transcript` = true / 1

---

## 2. Restart backend (for Transcript tab)

Backend now reads `extras.inline_transcript` when R2 has no file.

- If uvicorn runs with `--reload` → wait ~2 seconds after pull/save  
- Else stop + start FastAPI once  
- Flutter: hot **restart** (`R`)

Notes + Quiz work from Supabase even before restart. Transcript needs the updated backend.

---

## 3. How to test group share

1. Login as that **teacher**
2. Teacher Dashboard → **My Library** (or Library tab) → open **TEST — Sample Lecture**
3. Confirm Notes / Summary / Quiz / Transcript show sample text
4. **Share to group** → pick a class (free link, no credits)
5. Login as **student** in that group → open shared item → Notes/Quiz open

---

## 4. Delete later

In SQL Editor (same email):

```sql
DELETE FROM public.lectures
WHERE title = 'TEST — Sample Lecture'
  AND user_id = (
    SELECT id FROM auth.users
    WHERE lower(email) = lower('YOUR_EMAIL@gmail.com')
    LIMIT 1
  );
```

Or delete from Library in the app if delete lecture is wired.

---

## 5. .env

No new `.env` keys.

---

## Notes

| Field | Value |
|-------|--------|
| Title | `TEST — Sample Lecture` |
| Subject | Biology |
| Shareable? | Yes (`source_type = recorded`) |
| Credits charged by seed? | **0** |
| Re-run SQL? | Safe — deletes old TEST lecture for that user, inserts fresh |
