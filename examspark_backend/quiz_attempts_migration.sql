-- ExamSpark — Quiz Attempts Slice A (Learning Score)
-- Founder: Supabase Dashboard → SQL Editor → paste ALL → Run
-- Safe to re-run (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- Stores finished Study Workspace quiz scores only (not Home AI chats).

CREATE TABLE IF NOT EXISTS quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lecture_id UUID NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score >= 0),
    total INTEGER NOT NULL CHECK (total > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT quiz_attempts_score_lte_total CHECK (score <= total)
);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_created
    ON quiz_attempts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_lecture_created
    ON quiz_attempts (lecture_id, created_at DESC);

ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "quiz_attempts_select_own" ON quiz_attempts;
CREATE POLICY "quiz_attempts_select_own" ON quiz_attempts
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "quiz_attempts_insert_own" ON quiz_attempts;
CREATE POLICY "quiz_attempts_insert_own" ON quiz_attempts
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM lectures l
            WHERE l.id = lecture_id
              AND l.user_id = auth.uid()
        )
    );

GRANT SELECT, INSERT ON quiz_attempts TO authenticated;

-- Verify
SELECT 'quiz_attempts' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'quiz_attempts';
