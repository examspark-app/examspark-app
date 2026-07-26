-- ExamSpark — Teacher Share access + student performance snapshots
-- Founder: paste once in Supabase → SQL Editor → Run
-- Date: Jul 23, 2026
--
-- What this does:
--   1) extras SELECT for group members (real shared Quiz / Flashcards JSON)
--   2) quiz_attempts INSERT when student has group access to that lecture
--   3) quiz_attempts SELECT for teachers on lectures they own
--   4) teacher_student_month_stats (lazy monthly snapshot for dashboard)
--   5) helper fn_user_can_view_shared_lecture (used by FastAPI optional)

-- ---- 1) extras: group members can SELECT (same pattern as notes) ----
DROP POLICY IF EXISTS "extras_select" ON extras;
CREATE POLICY "extras_select" ON extras FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM lectures l
            WHERE l.id = extras.lecture_id AND l.user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM group_shared_items gsi
            WHERE gsi.lecture_id = extras.lecture_id
              AND fn_group_item_access(auth.uid(), gsi.id) <> 'none'
        )
    );

-- ---- 2) quiz_attempts: own rows OR group-shared lecture access ----
DROP POLICY IF EXISTS "quiz_attempts_insert_own" ON quiz_attempts;
CREATE POLICY "quiz_attempts_insert_own" ON quiz_attempts
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND (
            EXISTS (
                SELECT 1 FROM lectures l
                WHERE l.id = lecture_id AND l.user_id = auth.uid()
            )
            OR EXISTS (
                SELECT 1 FROM group_shared_items gsi
                WHERE gsi.lecture_id = lecture_id
                  AND fn_group_item_access(auth.uid(), gsi.id) <> 'none'
            )
        )
    );

DROP POLICY IF EXISTS "quiz_attempts_select_own" ON quiz_attempts;
CREATE POLICY "quiz_attempts_select_own" ON quiz_attempts
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "quiz_attempts_select_teacher_owned" ON quiz_attempts;
CREATE POLICY "quiz_attempts_select_teacher_owned" ON quiz_attempts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM lectures l
            WHERE l.id = quiz_attempts.lecture_id
              AND l.user_id = auth.uid()
        )
    );

-- ---- 3) Monthly performance snapshots (lazy upsert from FastAPI) ----
CREATE TABLE IF NOT EXISTS teacher_student_month_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    year_month TEXT NOT NULL,
    avg_percent NUMERIC(5, 2) NOT NULL DEFAULT 0,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT teacher_student_month_stats_ym_chk
        CHECK (year_month ~ '^[0-9]{4}-[0-9]{2}$'),
    CONSTRAINT teacher_student_month_stats_unique
        UNIQUE (teacher_id, student_id, year_month)
);

CREATE INDEX IF NOT EXISTS idx_teacher_student_month_stats_teacher
    ON teacher_student_month_stats (teacher_id, year_month DESC);

ALTER TABLE teacher_student_month_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tsms_select_teacher" ON teacher_student_month_stats;
CREATE POLICY "tsms_select_teacher" ON teacher_student_month_stats
    FOR SELECT USING (teacher_id = auth.uid());

-- Writes via service_role (FastAPI admin) only — no authenticated INSERT policy.

GRANT SELECT ON teacher_student_month_stats TO authenticated;
GRANT ALL ON teacher_student_month_stats TO service_role;

-- ---- 4) Optional helper for FastAPI (service role / authenticated) ----
CREATE OR REPLACE FUNCTION fn_user_can_view_shared_lecture(
    p_user_id UUID,
    p_lecture_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM lectures l
    WHERE l.id = p_lecture_id AND l.user_id = p_user_id
  )
  OR EXISTS (
    SELECT 1 FROM group_shared_items gsi
    WHERE gsi.lecture_id = p_lecture_id
      AND fn_group_item_access(p_user_id, gsi.id) <> 'none'
  );
$$;

GRANT EXECUTE ON FUNCTION fn_user_can_view_shared_lecture(UUID, UUID)
    TO authenticated, service_role;

-- Verify
SELECT 'extras_select' AS policy_check
WHERE EXISTS (
  SELECT 1 FROM pg_policies
  WHERE tablename = 'extras' AND policyname = 'extras_select'
);

SELECT 'teacher_student_month_stats' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'teacher_student_month_stats';
