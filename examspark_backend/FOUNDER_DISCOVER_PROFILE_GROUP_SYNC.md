# Discover ↔ Profile ↔ Group sync (Option A)

**Locked Jul 26, 2026** — founder: *save and start discover profile group sync*

## Product rule (locked)

| Rule | Meaning |
|------|---------|
| **Profile = master** | Teacher Profile holds subjects, languages, city, class levels, boards/exams — **as many as they want** (no max-3) |
| **Group picks from profile only** | Create / Edit Study Group cannot invent a random subject/class/board/language outside Profile |
| **Discover filters (4)** | **City · Subject · Class · Board** (realtime refresh when teachers/groups change) |
| **Why** | Empty Discover happened when Profile said Math/Pune but Group said Physical Education / Indonesian |

## What you must run (once)

1. Open **Supabase** → **SQL Editor**
2. Open file: `examspark_backend/teacher_profile_class_exam_migration.sql`
3. Copy all → paste → **Run**
4. Verify: `teacher_profiles` table has columns `class_levels` and `exams`

### Optional: Realtime (for live Discover refresh)

1. Supabase → **Database** → **Replication** (or **Realtime**)
2. Enable realtime for tables: `teacher_profiles`, `class_folders`
3. If you skip this, Discover still works — student taps Apply / pull-to-refresh; live auto-refresh needs Realtime on.

## Teacher checklist (after SQL)

1. Hot restart Flutter app
2. Teacher Dashboard → **Edit / Complete Profile**
3. Add: Subjects (e.g. Mathematics), City (Pune), Class levels (e.g. 11, 12), Board/Exam (e.g. NEET), Languages
4. **Save**
5. **Create / Edit Group** → Subject / Class / Board / Language dropdowns should list **only** what is on Profile
6. Student → Groups → **Discover** → filter City + Subject (+ Class / Board) → teacher should appear

## Fix for existing mismatch (your screenshots)

If Group still says Physical Education / Indonesian but Profile says Math / Hindi:

1. Update Profile first (add every subject/class/board/language you teach)
2. Open **Edit Study Group** → pick Subject/Class/Board/Language from Profile lists
3. Save → Discover filters matching Profile + Group will show you

## .env

No new `.env` keys.

## Rollback

- App: git revert the Flutter + docs commit for this feature
- SQL: columns can stay (harmless); or `ALTER TABLE … DROP COLUMN class_levels, DROP COLUMN exams;` only if you are sure no data needed
