-- Short notes move from R2 JSON to Supabase columns (locked storage policy).
-- Keep existing r2_* columns for legacy lectures/fallback only.

ALTER TABLE notes
ADD COLUMN IF NOT EXISTS clean_notes TEXT,
ADD COLUMN IF NOT EXISTS short_summary TEXT,
ADD COLUMN IF NOT EXISTS key_points JSONB,
ADD COLUMN IF NOT EXISTS important_terms JSONB;

