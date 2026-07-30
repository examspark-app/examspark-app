# Founder — Discover fuzzy search (pg_trgm) + Language dropdown

## What changed

1. **Discover search** — typos OK on city / state / subject / name via Postgres `pg_trgm` (threshold **0.35**). No AI.
2. **Teaching language** — dropdown (bounded list), not free-text — on Teacher Profile + Create Group.

City/state autocomplete = later (not this pass).

---

## 1. SQL (required once)

1. Supabase → **SQL Editor** → New query  
2. Open `examspark_backend/teacher_discover_fuzzy_trgm_migration.sql`  
3. Copy all → Paste → **Run**  
4. Verify last queries show `pg_trgm` and `fn_teacher_discover_fuzzy`

---

## 2. App

Flutter hot **restart** (`R`). No new `.env`.

---

## 3. Smoke

| Test | Expected |
|------|----------|
| Discover search `kolkta` | Teachers with city **Kolkata** (if any) |
| Discover `Bangalore` / `Bengaluru` | Match either spelling if profile has one |
| Discover `Physcis` | Teachers with subject Physics (word similarity) |
| Profile → Teaching language | Dropdown list (English, Hindi, …) — no free type |
| Create Group → Language | Same expanded dropdown |

Tune threshold later: edit RPC default `0.35` → `0.3` (more results) or `0.4` (stricter) in SQL.

---

## Rollback (only if founder asks)

```sql
DROP FUNCTION IF EXISTS public.fn_teacher_discover_fuzzy(text, real);
DROP INDEX IF EXISTS idx_teacher_profiles_city_trgm;
DROP INDEX IF EXISTS idx_teacher_profiles_state_trgm;
DROP INDEX IF EXISTS idx_teacher_profiles_subject_trgm;
DROP INDEX IF EXISTS idx_teacher_profiles_full_name_trgm;
-- Keep pg_trgm extension (harmless) unless you want: DROP EXTENSION pg_trgm;
```
