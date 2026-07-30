-- Smart Visual Notes Engine (Phase 5) — structured graphs/diagrams/timelines in Supabase.
-- Run in Supabase SQL Editor after notes_short_supabase_migration.sql.

ALTER TABLE notes
ADD COLUMN IF NOT EXISTS visual_payload_json JSONB;
