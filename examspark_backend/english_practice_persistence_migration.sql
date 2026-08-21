-- English Practice persistence hardening.
-- Run after the English Practice tables exist.

ALTER TABLE english_practice_sessions
  ALTER COLUMN created_at TYPE timestamptz
  USING created_at AT TIME ZONE 'UTC';

ALTER TABLE english_practice_sessions
  ALTER COLUMN updated_at TYPE timestamptz
  USING updated_at AT TIME ZONE 'UTC';

ALTER TABLE english_practice_sessions
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE english_practice_messages
  ALTER COLUMN created_at TYPE timestamptz
  USING created_at AT TIME ZONE 'UTC';

ALTER TABLE english_practice_messages
  ALTER COLUMN created_at SET DEFAULT now();
