-- ============================================================================
-- ExamSpark — Teacher Commission Migration
-- Run ONCE in the Supabase SQL Editor (schema.sql + teacher_group_features_migration.sql
-- already ran earlier).
--
-- Adds:
--   1. teacher_profiles.commission_rate — founder-locked 30% recurring
--      commission on any Group member's active paid subscription. Kept as a
--      per-teacher column (not a hardcoded constant) for future flexibility,
--      even though every teacher defaults to the same 0.30 today.
--   2. fn_teacher_estimated_commission(p_teacher_id) — display-only estimate
--      for the Teacher Dashboard's "Estimated Commission" card. No real
--      money moves here; actual payout wiring is explicit Phase 5 work.
--
-- Attribution rule (CREDIT_ECONOMY.md §Teacher Commission): a student can be
-- a member of multiple teachers' Groups, but only ONE teacher earns
-- commission on them — their "primary teacher" = whoever owns the Group
-- with the most recent class_memberships.joined_at for that student.
-- ============================================================================

-- ---- teacher_profiles: commission rate ----
ALTER TABLE teacher_profiles
    ADD COLUMN IF NOT EXISTS commission_rate NUMERIC NOT NULL DEFAULT 0.30;

COMMENT ON COLUMN teacher_profiles.commission_rate IS
    'Founder-locked Jul 2026: 30% recurring commission on any Group member''s '
    'active paid-plan subscription, paid to that student''s primary teacher '
    '(most recently joined Group). Display-only today — see fn_teacher_estimated_commission().';

-- ---- estimated commission (display-only) ----
CREATE OR REPLACE FUNCTION fn_teacher_estimated_commission(p_teacher_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rate NUMERIC;
    v_total NUMERIC;
BEGIN
    SELECT commission_rate INTO v_rate
    FROM teacher_profiles
    WHERE user_id = p_teacher_id;

    IF v_rate IS NULL THEN
        v_rate := 0.30;
    END IF;

    WITH primary_group AS (
        -- Most recently joined active Group per student, across ALL teachers.
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
        -- Students whose primary teacher is this teacher.
        SELECT student_id
        FROM primary_group
        WHERE rn = 1 AND teacher_id = p_teacher_id
    ),
    active_paid_subs AS (
        SELECT us.user_id, sp.price_inr_paise
        FROM user_subscriptions us
        JOIN subscription_plans sp ON sp.id = us.plan_id
        WHERE us.status = 'active'
          AND us.current_period_end >= now()
          AND sp.price_inr_paise > 0
    )
    SELECT COALESCE(SUM(aps.price_inr_paise) / 100.0 * v_rate, 0)
    INTO v_total
    FROM attributed_students a
    JOIN active_paid_subs aps ON aps.user_id = a.student_id;

    RETURN ROUND(v_total, 2);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_teacher_estimated_commission(UUID) TO authenticated;
