-- ExamSpark — Global Custom fields Option A (comments only)
-- Jul 26, 2026. Safe to re-run. NO new columns — wording only.
-- Why: old comments said India-only boards/languages; app now stores
-- short presets OR any Custom… free text in the same TEXT columns.

COMMENT ON COLUMN public.class_folders.class_level IS
  'Class / level: app presets (6–12, College, University) OR any Custom… free text (global).';

COMMENT ON COLUMN public.class_folders.exam IS
  'Exam / board: short app starters (School, CBSE, NEET, IB, SAT, …) OR any Custom… free text (global).';

COMMENT ON COLUMN public.class_folders.language IS
  'Teaching language: short world starters OR any Custom… free text (global).';

COMMENT ON COLUMN public.class_folders.subject IS
  'Subject: short global starters OR any Custom… free text.';

COMMENT ON COLUMN public.teacher_profiles.language IS
  'Teaching language: short world starters OR any Custom… free text (global). Fuzzy Discover matches free text.';

COMMENT ON COLUMN public.student_profiles.exam_target IS
  'Student exam/board: app starters OR any Custom… free text (global) for Discovery matching.';

COMMENT ON COLUMN public.student_profiles.preferred_language IS
  'Preferred learning language: app starters OR any Custom… free text (global).';

-- Verify comments (optional)
SELECT
  c.relname AS table_name,
  a.attname AS column_name,
  d.description
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
LEFT JOIN pg_catalog.pg_description d
  ON d.objoid = a.attrelid AND d.objsubid = a.attnum
WHERE n.nspname = 'public'
  AND c.relname IN ('class_folders', 'teacher_profiles', 'student_profiles')
  AND a.attname IN (
    'class_level', 'exam', 'language', 'subject',
    'exam_target', 'preferred_language'
  )
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY c.relname, a.attname;
