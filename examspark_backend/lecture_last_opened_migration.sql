-- ExamSpark: Library "last opened" timestamp
-- Run once in Supabase SQL Editor (safe to re-run).
-- After run: Library cards show time like 3:45pm; updates when you open a lecture.

ALTER TABLE lectures
    ADD COLUMN IF NOT EXISTS last_opened_at TIMESTAMPTZ;

-- Existing done lectures: treat create time as last opened so Recent still sorts.
UPDATE lectures
SET last_opened_at = COALESCE(last_opened_at, created_at)
WHERE last_opened_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lectures_user_last_opened
    ON lectures (user_id, last_opened_at DESC NULLS LAST);
