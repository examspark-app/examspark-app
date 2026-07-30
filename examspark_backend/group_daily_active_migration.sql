-- ExamSpark — Group daily active (last_active_at)
-- Run once in Supabase → SQL Editor after teacher_coupon_migration.sql.
-- Lets teachers see "Active today" from Group opens (not chat).

ALTER TABLE class_memberships
    ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

COMMENT ON COLUMN class_memberships.last_active_at IS
    'Last time this student opened the group channel (heartbeat). Used for teacher Daily Active.';

CREATE INDEX IF NOT EXISTS idx_class_memberships_class_last_active
    ON class_memberships (class_id, last_active_at DESC NULLS LAST);

-- Students may update only their own membership row (heartbeat).
DROP POLICY IF EXISTS "class_memberships_touch_active" ON class_memberships;
CREATE POLICY "class_memberships_touch_active" ON class_memberships
    FOR UPDATE
    USING (student_id = auth.uid())
    WITH CHECK (student_id = auth.uid());

GRANT UPDATE ON class_memberships TO authenticated;
GRANT UPDATE ON class_memberships TO service_role;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'class_memberships'
  AND column_name = 'last_active_at';
