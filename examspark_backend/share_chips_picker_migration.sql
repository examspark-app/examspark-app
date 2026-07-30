-- ExamSpark — Share chips picker (which generated artifacts are visible to students)
-- Founder Jul 25, 2026. Run ONCE in Supabase SQL Editor. Safe to re-run.
--
-- One lecture share per group (existing unique). shared_chips lists which
-- generated pieces students may open (notes, quiz, flashcards, …).
-- NULL = legacy “all tabs” (old rows). Empty array not used by app (use NULL or list).

ALTER TABLE public.group_shared_items
  ADD COLUMN IF NOT EXISTS shared_chips TEXT[];

COMMENT ON COLUMN public.group_shared_items.shared_chips IS
  'Teacher-selected chips shared to group (e.g. notes,quiz,flashcards). NULL = legacy all. Students: read-only, no generate.';

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'group_shared_items'
  AND column_name = 'shared_chips';
