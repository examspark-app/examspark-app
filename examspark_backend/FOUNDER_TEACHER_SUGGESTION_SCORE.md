# Founder — Teacher suggestion scores (Discovery)

## Weights (0–100)

| Factor | Points (when student filled that field) |
|--------|-------------------------------------------|
| Subject | 40 (pg_trgm fuzzy) |
| Exam / Board | 30 |
| City | 15 (fuzzy) |
| Language | 15 |

If student **missing** a field (e.g. no exam) → that weight is **skipped** and the rest are **redistributed** to still total 100 when all available factors match. No fake 0 penalty for missing data.

Cards show: **Matches: Subject, City** (only factors that actually matched).

---

## 1. SQL order

1. First (if not done): `teacher_discover_fuzzy_trgm_migration.sql` (needs `pg_trgm`)  
2. Then: **`teacher_suggestion_score_migration.sql`** ← Run this  

Supabase → SQL Editor → paste → Run.

---

## 2. App

Flutter hot **restart** (`R`). No new `.env`.

---

## 3. How students get Exam / Language / City

**New students:** onboarding now asks optional Exam, Language, City (+ subjects).

**Already onboarded:** those columns empty → only Subject (and city if set) score until they update profile later. Discover still works.

Teachers: Exam comes from **Create Group → Board/Exam**; Language from profile / group.

---

## 4. Smoke

1. Student profile with Physics + NEET + Kolkata + Hindi  
2. Teacher with Physics, NEET group, Kolkata, Hindi  
3. Discover → that teacher near top + badge `Matches: Subject, Exam, City, Language`  
4. Student without exam → no Exam in badge; scores still rank by available fields  

---

## Rollback (only if asked)

```sql
DROP FUNCTION IF EXISTS public.fn_teacher_suggestion_scores(uuid, real);
-- Keep student_profiles.exam_target / preferred_language columns (harmless)
```
