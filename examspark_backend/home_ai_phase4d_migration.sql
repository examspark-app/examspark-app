-- ExamSpark Phase 4D — Home AI Study History (sessions + messages)
-- Founder: Supabase Dashboard → SQL Editor → paste ALL → Run
-- Safe to re-run (IF NOT EXISTS).
-- Requires Phase 4C tables: home_ai_responses (already run).

-- One conversation thread per Home AI chat
CREATE TABLE IF NOT EXISTS home_ai_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Study session',
    conversation_language TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    pinned BOOLEAN NOT NULL DEFAULT FALSE,
    bookmarked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_home_ai_sessions_user_updated
    ON home_ai_sessions (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_home_ai_sessions_user_pinned
    ON home_ai_sessions (user_id, pinned DESC, updated_at DESC);

-- Chat turns inside a session (user + assistant)
CREATE TABLE IF NOT EXISTS home_ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES home_ai_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    message TEXT NOT NULL,
    response_id UUID REFERENCES home_ai_responses(id) ON DELETE SET NULL,
    credits_used INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_home_ai_messages_session_created
    ON home_ai_messages (session_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_home_ai_messages_response
    ON home_ai_messages (response_id)
    WHERE response_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_home_ai_messages_user
    ON home_ai_messages (user_id, created_at DESC);

-- Optional link on master response → session (fast lookup)
ALTER TABLE home_ai_responses
    ADD COLUMN IF NOT EXISTS session_id UUID
        REFERENCES home_ai_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_home_ai_responses_session
    ON home_ai_responses (session_id)
    WHERE session_id IS NOT NULL;

ALTER TABLE home_ai_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE home_ai_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "home_ai_sessions_select_own" ON home_ai_sessions;
CREATE POLICY "home_ai_sessions_select_own" ON home_ai_sessions
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_sessions_insert_own" ON home_ai_sessions;
CREATE POLICY "home_ai_sessions_insert_own" ON home_ai_sessions
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_sessions_update_own" ON home_ai_sessions;
CREATE POLICY "home_ai_sessions_update_own" ON home_ai_sessions
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_sessions_delete_own" ON home_ai_sessions;
CREATE POLICY "home_ai_sessions_delete_own" ON home_ai_sessions
    FOR DELETE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_messages_select_own" ON home_ai_messages;
CREATE POLICY "home_ai_messages_select_own" ON home_ai_messages
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_messages_insert_own" ON home_ai_messages;
CREATE POLICY "home_ai_messages_insert_own" ON home_ai_messages
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_messages_delete_own" ON home_ai_messages;
CREATE POLICY "home_ai_messages_delete_own" ON home_ai_messages
    FOR DELETE USING (user_id = auth.uid());

-- Verify
SELECT 'home_ai_sessions' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'home_ai_sessions'
UNION ALL
SELECT 'home_ai_messages', COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'home_ai_messages';
