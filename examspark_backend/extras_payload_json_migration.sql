-- Flashcards / Quiz / other extras structured payload storage
-- Founder-locked Storage Policy (Jul 2026): structured JSON lives in Supabase (Postgres),
-- R2 is for large files/exports and temporary audio staging only.
--
-- This migration keeps legacy `r2_path` for backward compatibility (older rows)
-- and adds `payload_json` for the structured JSON itself.

ALTER TABLE extras
ADD COLUMN IF NOT EXISTS payload_json jsonb;

