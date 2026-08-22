-- Chat-only text-generation model selection.
-- Run after the English Practice sessions table exists.
ALTER TABLE english_practice_sessions
  ADD COLUMN IF NOT EXISTS text_model text NOT NULL DEFAULT 'qwen3';

ALTER TABLE english_practice_sessions
  ADD COLUMN IF NOT EXISTS last_mcq_message_count integer NOT NULL DEFAULT 0;

UPDATE english_practice_sessions
SET text_model = 'qwen3'
WHERE text_model IS NULL OR text_model NOT IN ('qwen3', 'gemini');

ALTER TABLE english_practice_sessions
  DROP CONSTRAINT IF EXISTS english_practice_sessions_text_model_check;

ALTER TABLE english_practice_sessions
  ADD CONSTRAINT english_practice_sessions_text_model_check
  CHECK (text_model IN ('qwen3', 'gemini'));