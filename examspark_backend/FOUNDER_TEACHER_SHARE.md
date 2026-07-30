# Founder — Teacher Share (Record → Share → Real Open → Performance)

**Date:** Jul 23, 2026  
**Lane:** `start Teacher Share` (implemented)

## What shipped

1. **Teacher = live Record only** — Upload Audio hidden for teachers (Recorder + Home attach). Dashboard has **Record lecture** CTA.
2. **Share to own group** — FastAPI `POST /api/v1/groups/share` enforces: own group + own lecture + `source_type = recorded`.
3. **Student opens real content** — Group feed Notes/Lecture → Study Workspace (read-only); Quiz → real MCQs from that lecture (attempts saved).
4. **Teacher Dashboard students list** — username, coupon badge, overall %, week / prev week, month / prev month.

## Manual setup (you must do)

### 1) Run SQL (required)

1. Open [Supabase](https://supabase.com) → your project → **SQL Editor** → **New query**
2. Open file: `examspark_backend/teacher_share_access_migration.sql`
3. Copy **all** → paste → **Run**
4. Verify bottom of results shows `teacher_student_month_stats` with column count

**What it unlocks:** group members can read Quiz JSON; students can save quiz attempts on shared lectures; monthly snapshot table for dashboard.

### 2) Restart backend

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Verify: browser `http://localhost:8000/` → `"ExamSpark Backend Active"` and `"teacher_share": "group_member_read_and_performance"`.

### 3) Flutter reload

In the Flutter Chrome terminal: press capital **R** (hot restart).

## .env checklist

No new keys. Existing `FASTAPI_BASE_URL` + Supabase keys must already work.

## Smoke (3 checks)

| # | Do this | Expect |
|---|---------|--------|
| 1 | Teacher account → Home Record **or** Teacher Dashboard → Record lecture | **Record** tab only — no **Upload Audio** |
| 2 | Teacher: record → generate Quiz → Share to Group (Quiz) → student opens group card | Real quiz questions (not WWI sample); finish saves score |
| 3 | Teacher Dashboard → Students list | Names for paid + coupon joins; % or — if no attempts yet |

## Rollback

- Revert app code from git if needed.
- SQL policies: re-run old `extras_select` / `quiz_attempts_*` from a previous `schema.sql` backup if you must undo (ask CTO before).

## Files safe to remove

None — ask before delete.
