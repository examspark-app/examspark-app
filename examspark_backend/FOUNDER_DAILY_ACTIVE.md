# Founder — Daily Active (Groups step 5)

**What it does:** When a joined student opens a Group, the app quietly updates `last_active_at`. Teacher Dashboard shows **Active today** count + per-student last active. Still **no chat**.

## 1. Run SQL (once)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project → **SQL Editor**
2. Open file: `examspark_backend/group_daily_active_migration.sql`
3. Copy all → paste → **Run**
4. **Verify:** result shows row `last_active_at` / `timestamp with time zone`

Tell CTO: **SQL daily active done**

## 2. Restart backend

In the terminal where FastAPI runs:

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

(Or stop and start your usual backend command.)

## 3. Flutter

Hot restart (**R**).

## 4. Smoke test

1. Login as **student** → Groups → open a joined group (wait 2 seconds)
2. Login as **teacher** → Profile → Teacher Dashboard
3. Expect: **Active today** card ≥ 1 (if student opened within last 24 hours)
4. Student row shows **Active today** or a short last-seen line

## .env

**None** — no new keys.

## Rollback

```sql
DROP POLICY IF EXISTS "class_memberships_touch_active" ON class_memberships;
ALTER TABLE class_memberships DROP COLUMN IF EXISTS last_active_at;
```
