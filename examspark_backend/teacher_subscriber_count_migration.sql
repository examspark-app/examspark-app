-- ============================================================================
-- ExamSpark — Teacher Subscriber Count (Dashboard cards)
-- Run ONCE in Supabase SQL Editor AFTER Flutter hot restart.
-- After: teacher_commission_migration.sql (same attribution rules).
--
-- Adds: fn_teacher_subscriber_count(p_teacher_id)
--   = COUNT of students whose PRIMARY teacher is this teacher
--     AND who have an active paid plan (price_inr_paise > 0).
-- Same base as Est. Commission 30% (CREDIT_ECONOMY.md §Teacher Commission).
-- Free joins count in Students card only — not here.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_teacher_subscriber_count(p_teacher_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    WITH primary_group AS (
        SELECT
            cm.student_id,
            cf.teacher_id,
            ROW_NUMBER() OVER (
                PARTITION BY cm.student_id
                ORDER BY cm.joined_at DESC
            ) AS rn
        FROM class_memberships cm
        JOIN class_folders cf ON cf.id = cm.class_id
    ),
    attributed_students AS (
        SELECT student_id
        FROM primary_group
        WHERE rn = 1 AND teacher_id = p_teacher_id
    ),
    active_paid_subs AS (
        SELECT DISTINCT us.user_id
        FROM user_subscriptions us
        JOIN subscription_plans sp ON sp.id = us.plan_id
        WHERE us.status = 'active'
          AND us.current_period_end >= now()
          AND sp.price_inr_paise > 0
    )
    SELECT COUNT(*)::INTEGER
    INTO v_count
    FROM attributed_students a
    JOIN active_paid_subs aps ON aps.user_id = a.student_id;

    RETURN COALESCE(v_count, 0);
END;
$$;

COMMENT ON FUNCTION fn_teacher_subscriber_count(UUID) IS
    'Teacher Dashboard Subscribers card — paid students attributed via primary '
    'Group (most recent join). Same base as fn_teacher_estimated_commission.';

GRANT EXECUTE ON FUNCTION fn_teacher_subscriber_count(UUID) TO authenticated;
