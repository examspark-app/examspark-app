-- ExamSpark — Jul 16 pending columns (ONE paste in Supabase SQL Editor)
-- Safe to re-run: all use IF NOT EXISTS.
-- Skip if you already ran the three separate migration files successfully.
--
-- Order inside this file:
--   1) extras.payload_json  (Flashcards / Quiz / Revision / IQ / Mind Map)
--   2) notes short columns  (clean_notes, short_summary, key_points, important_terms)
--   3) notes.visual_payload_json  (Smart Visual Notes)

-- 1) Extras structured JSON
ALTER TABLE extras
ADD COLUMN IF NOT EXISTS payload_json jsonb;

-- 2) Short notes in Supabase
ALTER TABLE notes
ADD COLUMN IF NOT EXISTS clean_notes TEXT,
ADD COLUMN IF NOT EXISTS short_summary TEXT,
ADD COLUMN IF NOT EXISTS key_points JSONB,
ADD COLUMN IF NOT EXISTS important_terms JSONB;

-- 3) Visual Notes payload
ALTER TABLE notes
ADD COLUMN IF NOT EXISTS visual_payload_json JSONB;

-- Verify (expect 1 row each for the new columns)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE (table_name = 'extras' AND column_name = 'payload_json')
   OR (table_name = 'notes' AND column_name IN (
        'clean_notes', 'short_summary', 'key_points',
        'important_terms', 'visual_payload_json'
      ))
ORDER BY table_name, column_name;
