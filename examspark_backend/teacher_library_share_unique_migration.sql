-- ExamSpark — Teacher Library: one lecture share per group (anti-duplicate)
-- Founder Jul 25, 2026. Run ONCE in Supabase SQL Editor.
-- Safe to re-run.

-- Deduplicate existing rows before unique index (keep oldest share per class+lecture).
DELETE FROM group_shared_items a
USING group_shared_items b
WHERE a.lecture_id IS NOT NULL
  AND b.lecture_id IS NOT NULL
  AND a.class_id = b.class_id
  AND a.lecture_id = b.lecture_id
  AND a.id > b.id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_group_shared_items_class_lecture
ON group_shared_items (class_id, lecture_id)
WHERE lecture_id IS NOT NULL;

COMMENT ON INDEX uq_group_shared_items_class_lecture IS
  'Teacher Library: same lecture linked once per group. Re-share to other groups OK; duplicate to same group blocked.';

-- Verify
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'group_shared_items'
  AND indexname = 'uq_group_shared_items_class_lecture';
