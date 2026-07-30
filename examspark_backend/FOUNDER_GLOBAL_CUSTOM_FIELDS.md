# Founder guide — Global Custom fields (Option A)

**Status:** Coded Jul 26, 2026 · Flutter presets + Custom… · **columns already TEXT** (no new columns)

Old SQL *comments* still said India-only (CBSE/Hindi…) — that was **docs only**, not a DB lock. Comments fixed in:

- `create_study_group_v1_migration.sql` (source file)
- `teacher_discover_fuzzy_trgm_migration.sql` / `teacher_suggestion_score_migration.sql`
- **Run once for live DB:** [`global_custom_fields_comments_migration.sql`](global_custom_fields_comments_migration.sql)


## What this is

Short **starter presets** + **Custom…** everywhere that felt India-only, so students/teachers worldwide are not blocked (“mera desh / exam / language nahi”).

Stored value = the **real text** (e.g. `Swahili`, `WAEC`, `Class 5`), never the literal word `Custom…`.

Fuzzy Discover / teacher suggest already match free text — no backend change for Option A.

## Where Custom… appears

| Field | Screens |
|-------|---------|
| **Language** | Teacher setup · Teacher edit · Create Group · Student onboarding · Discover filter |
| **Exam / board** | Create Group · Student onboarding |
| **Class / level** | Create Group (6–12, College, University + Custom…) |
| **Subject** | Create Group · Discover · Recording setup · Recorder · Student onboarding (chips + Add) · Teacher subjects (free text) |

## Presets (short on purpose)

- **Subjects** — expanded STEM / humanities / commerce starters (`subjects.dart`)
- **Languages** — India + world starters + Russian / Turkish / Indonesian (`teaching_languages.dart`)
- **Exams** — India + IGCSE / IB / A-Levels / SAT / ACT / AP (`exam_boards.dart`) — **not** every country board
- **Class** — `6` … `12`, College, University (`class_levels.dart`)

Helper: `examspark_frontend/lib/core/constants/custom_field_option.dart`

## Manual setup (you)

1. Open the Flutter app project (`examspark_frontend`).
2. **Hot restart** (not only hot reload) so new dropdowns load.
3. **Optional but recommended:** Supabase → SQL Editor → run full file  
   `examspark_backend/global_custom_fields_comments_migration.sql`  
   (updates column comments only — safe, no new columns).
4. No `.env` changes.

## Smoke test (copy this)

1. **Create Group** → Subject / Class / Exam / Language → pick **Custom…** → type something unusual → Create.  
   **Expect:** group saves with your custom text (not “Custom…”).
2. **Student onboarding** → Exam + Language Custom…; add a custom subject.  
   **Expect:** profile saves; Discover can still find teachers by fuzzy subject/language.
3. **Discover** → Subject filter Custom… + Language Custom… → Apply.  
   **Expect:** filters apply; empty list shows clear message if no match.
4. **Record / Upload setup** → Subject Custom… → continue.  
   **Expect:** lecture uses your custom subject name.
5. **Teacher profile** language Custom… → Save.  
   **Expect:** language shows on profile / Discover.

## Rollback

Revert the Flutter constants + screen edits from this slice (git). No DB rollback needed.

## Out of scope (do not expand yet)

- Long country-by-country exam lists
- Changing fuzzy SQL thresholds
- New columns for “is_custom” flags

## Recommended next

Founder OK this smoke → then say what to `start …` next (e.g. wireframes 1B or another locked pending item).
