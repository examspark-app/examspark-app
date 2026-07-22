-- ExamSpark Phase 4C — Home AI Smart Study Workspace
-- Founder: Supabase Dashboard → SQL Editor → paste ALL → Run
-- Safe to re-run (IF NOT EXISTS).

-- Master Home AI response (one row per successful answer)
CREATE TABLE IF NOT EXISTS home_ai_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    answer TEXT NOT NULL,
    knowledge_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    visual_payload_json JSONB,
    answer_source TEXT,
    confidence TEXT,
    conversation_language TEXT,
    lecture_id UUID REFERENCES lectures(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_home_ai_responses_user_created
    ON home_ai_responses (user_id, created_at DESC);

-- Per-chip generated tools (generate once, reuse)
CREATE TABLE IF NOT EXISTS home_ai_tools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    response_id UUID NOT NULL REFERENCES home_ai_responses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tool_type TEXT NOT NULL,
    payload_json JSONB,
    status TEXT NOT NULL DEFAULT 'generating'
        CHECK (status IN ('generating', 'generated', 'failed')),
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (response_id, tool_type)
);

CREATE INDEX IF NOT EXISTS idx_home_ai_tools_response
    ON home_ai_tools (response_id);

CREATE INDEX IF NOT EXISTS idx_home_ai_tools_user
    ON home_ai_tools (user_id, updated_at DESC);

ALTER TABLE home_ai_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE home_ai_tools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "home_ai_responses_select_own" ON home_ai_responses;
CREATE POLICY "home_ai_responses_select_own" ON home_ai_responses
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_responses_insert_own" ON home_ai_responses;
CREATE POLICY "home_ai_responses_insert_own" ON home_ai_responses
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_tools_select_own" ON home_ai_tools;
CREATE POLICY "home_ai_tools_select_own" ON home_ai_tools
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_tools_insert_own" ON home_ai_tools;
CREATE POLICY "home_ai_tools_insert_own" ON home_ai_tools
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "home_ai_tools_update_own" ON home_ai_tools;
CREATE POLICY "home_ai_tools_update_own" ON home_ai_tools
    FOR UPDATE USING (user_id = auth.uid());

-- Verify
SELECT 'home_ai_responses' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'home_ai_responses'
UNION ALL
SELECT 'home_ai_tools', COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'home_ai_tools';
