-- =============================================================
-- English Practice Session History: Delete / Rename / Pin
-- Adds `pinned` column; also target_language user preference column.
-- Run before using the new endpoints.
-- =============================================================

-- 1) english_practice_sessions: pinned column + index for pinned-first sort
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'english_practice_sessions'
          AND column_name = 'pinned'
    ) THEN
        ALTER TABLE english_practice_sessions
            ADD COLUMN pinned BOOLEAN NOT NULL DEFAULT FALSE;

        CREATE INDEX idx_english_practice_sessions_pinned_updated
            ON english_practice_sessions (user_id, pinned DESC, updated_at DESC);
    END IF;
END $$;

-- 2) users: preferred_target_language column (optional — for item #1)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users'
          AND column_name = 'preferred_target_language'
    ) THEN
        ALTER TABLE users
            ADD COLUMN preferred_target_language VARCHAR(60) DEFAULT NULL;
    END IF;
END $$;
