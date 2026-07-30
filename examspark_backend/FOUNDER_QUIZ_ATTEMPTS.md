# Founder — Quiz Attempts Slice A (Learning Score)

> Jul 22, 2026 — Study Workspace quiz finish → save score → Progress Learning Score.

## What this does

- When a student taps **See Results** on a **Study Workspace** quiz (lecture quiz), ExamSpark saves `score` / `total` for that lecture.
- Progress **Learning Score** = average % of recent saved finishes.
- Recent Activity can show **Quiz Completed · 16/20**.
- Does **not** save Home AI / Select AI / sample group quizzes (no lecture id).
- Does **not** track Study Time yet.

## Manual SQL (required once)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your ExamSpark project.
2. Left menu → **SQL Editor** → **New query**.
3. Open this file on your PC:  
   `examspark_backend/quiz_attempts_migration.sql`
4. **Select all** → Copy → Paste into SQL Editor.
5. Click **Run**.
6. **Verify:** result table shows `quiz_attempts` and a column count (about 6).  
   If error about `users` / `lectures` missing — stop and tell CTO (schema not ready).

Safe to run again (IF NOT EXISTS).

## App smoke (after SQL + hot restart)

1. Flutter Chrome → hot restart **`R`**.
2. Open a lecture → **Quiz** tab → answer all → **See Results**.
3. Go to **Progress** tab (or pull to refresh).
4. **Expected:** Learning Score shows a % · Recent Activity has **Quiz Completed** with `score/total`.

If Learning Score stays `—` after a finish: SQL not run, or not logged in — re-check step 6.

## Rollback

- App only: revert Flutter files (quiz still works; scores just not saved).
- SQL: do **not** drop the table unless CTO asks (data loss).
