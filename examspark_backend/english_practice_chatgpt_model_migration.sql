-- Allow GPT-4o-mini as an English Practice session model.
-- Run in Supabase after english_practice_model_migration.sql.

ALTER TABLE english_practice_sessions
  DROP CONSTRAINT IF EXISTS english_practice_sessions_text_model_check;

ALTER TABLE english_practice_sessions
  ADD CONSTRAINT english_practice_sessions_text_model_check
    CHECK (text_model IN ('qwen3', 'gemini', 'claude', 'chatgpt'));