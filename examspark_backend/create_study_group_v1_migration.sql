-- ExamSpark — Create Study Group form v1 fields
-- Run once in Supabase → SQL Editor.
-- Additive columns on class_folders (1 subject already exists).
-- Jul 26, 2026: comments updated for Global Custom fields Option A
-- (presets OR any Custom… free text — not India-only).

ALTER TABLE class_folders
    ADD COLUMN IF NOT EXISTS class_level TEXT,
    ADD COLUMN IF NOT EXISTS exam TEXT,
    ADD COLUMN IF NOT EXISTS language TEXT;

COMMENT ON COLUMN class_folders.class_level IS
    'Class / level: app presets (6–12, College, University) OR any Custom… free text (global).';
COMMENT ON COLUMN class_folders.exam IS
    'Exam / board: short app starters (School, CBSE, NEET, IB, SAT, …) OR any Custom… free text (global).';
COMMENT ON COLUMN class_folders.language IS
    'Teaching language: short world starters OR any Custom… free text (global).';

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'class_folders'
  AND column_name IN ('class_level', 'exam', 'language', 'subject', 'is_public', 'join_code')
ORDER BY column_name;
