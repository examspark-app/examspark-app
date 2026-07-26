-- ExamSpark — Teacher Coupon (first-month free group access)
-- Run ONCE in Supabase SQL Editor after group_join_limits + teacher_commission migrations.
-- Safe to re-run (IF NOT EXISTS / CREATE OR REPLACE).

-- ---- class_memberships: coupon attribution ----
ALTER TABLE class_memberships
    ADD COLUMN IF NOT EXISTS coupon_id UUID;

COMMENT ON COLUMN class_memberships.coupon_id IS
    'Set when student joined via teacher coupon (first-month free path). NULL = normal join.';

-- ---- teacher_coupons (one coupon = one group, max 100) ----
CREATE TABLE IF NOT EXISTS teacher_coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    max_redemptions INTEGER NOT NULL DEFAULT 100 CHECK (max_redemptions > 0 AND max_redemptions <= 100),
    redeemed_count INTEGER NOT NULL DEFAULT 0 CHECK (redeemed_count >= 0),
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT teacher_coupons_code_unique UNIQUE (code),
    CONSTRAINT teacher_coupons_redeemed_lte_max CHECK (redeemed_count <= max_redemptions)
);

CREATE INDEX IF NOT EXISTS idx_teacher_coupons_teacher ON teacher_coupons(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_coupons_class ON teacher_coupons(class_id);
CREATE INDEX IF NOT EXISTS idx_teacher_coupons_code ON teacher_coupons(code);

-- ---- coupon_redemptions ----
CREATE TABLE IF NOT EXISTS coupon_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id UUID NOT NULL REFERENCES teacher_coupons(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    access_ends_at TIMESTAMPTZ NOT NULL,
    urgency_ends_at TIMESTAMPTZ NOT NULL,
    credits_granted INTEGER NOT NULL DEFAULT 50,
    CONSTRAINT coupon_redemptions_one_per_student UNIQUE (coupon_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_student ON coupon_redemptions(student_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_class ON coupon_redemptions(class_id);

ALTER TABLE class_memberships
    DROP CONSTRAINT IF EXISTS class_memberships_coupon_id_fkey;
ALTER TABLE class_memberships
    ADD CONSTRAINT class_memberships_coupon_id_fkey
    FOREIGN KEY (coupon_id) REFERENCES teacher_coupons(id) ON DELETE SET NULL;

-- ---- Join limit: allow coupon path; unpaid paid-tier rules unchanged ----
CREATE OR REPLACE FUNCTION fn_enforce_group_join_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan_id TEXT;
    v_max INTEGER;
    v_count INTEGER;
    v_coupon_ok BOOLEAN := false;
BEGIN
    -- Coupon join: membership carries coupon_id validated by FastAPI redeem.
    IF NEW.coupon_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM teacher_coupons tc
            WHERE tc.id = NEW.coupon_id
              AND tc.class_id = NEW.class_id
              AND tc.active = true
              AND tc.redeemed_count < tc.max_redemptions
        ) INTO v_coupon_ok;

        IF v_coupon_ok THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Invalid or exhausted teacher coupon for this group';
    END IF;

    v_plan_id := fn_user_plan_tier(NEW.student_id);
    SELECT max_groups INTO v_max
    FROM subscription_plans
    WHERE id = v_plan_id;

    v_max := COALESCE(v_max, 0);

    IF v_max < 0 THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_count
    FROM class_memberships
    WHERE student_id = NEW.student_id;

    IF v_count >= v_max THEN
        RAISE EXCEPTION
            'Group join limit reached (plan %, max %)', v_plan_id, v_max;
    END IF;

    RETURN NEW;
END;
$$;

-- ---- Trim: keep active coupon memberships (lock-in-place, do not remove) ----
CREATE OR REPLACE FUNCTION fn_trim_group_memberships(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan_id TEXT;
    v_max INTEGER;
    v_deleted INTEGER := 0;
BEGIN
    v_plan_id := fn_user_plan_tier(p_user_id);
    SELECT max_groups INTO v_max
    FROM subscription_plans
    WHERE id = v_plan_id;

    v_max := COALESCE(v_max, 0);

    IF v_max < 0 THEN
        RETURN 0;
    END IF;

    IF v_max = 0 THEN
        -- Keep coupon memberships (lock-in-place after trial); remove only normal joins.
        DELETE FROM class_memberships
        WHERE student_id = p_user_id
          AND coupon_id IS NULL;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        RETURN v_deleted;
    END IF;

    DELETE FROM class_memberships
    WHERE id IN (
        SELECT id
        FROM class_memberships
        WHERE student_id = p_user_id
          AND coupon_id IS NULL
        ORDER BY joined_at DESC
        OFFSET v_max
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trim_group_memberships(UUID) TO service_role;

-- ---- Commission: exclude coupon-attributed primary memberships ----
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
        SELECT
            cm.student_id,
            cf.teacher_id,
            cm.coupon_id,
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
        WHERE rn = 1
          AND teacher_id = p_teacher_id
          AND coupon_id IS NULL
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

-- ---- Access helper for Flutter lock / urgency UI ----
CREATE OR REPLACE FUNCTION fn_coupon_membership_status(
    p_student_id UUID,
    p_class_id UUID
)
RETURNS TABLE (
    joined_via_coupon BOOLEAN,
    access_active BOOLEAN,
    in_urgency_window BOOLEAN,
    access_ends_at TIMESTAMPTZ,
    urgency_ends_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (cm.coupon_id IS NOT NULL) AS joined_via_coupon,
        CASE
            WHEN cm.coupon_id IS NULL THEN true
            WHEN cr.access_ends_at IS NULL THEN false
            WHEN cr.access_ends_at > now() THEN true
            ELSE false
        END AS access_active,
        CASE
            WHEN cm.coupon_id IS NULL THEN false
            WHEN cr.access_ends_at IS NULL THEN false
            WHEN cr.access_ends_at <= now()
                 AND cr.urgency_ends_at > now() THEN true
            ELSE false
        END AS in_urgency_window,
        cr.access_ends_at,
        cr.urgency_ends_at
    FROM class_memberships cm
    LEFT JOIN coupon_redemptions cr
        ON cr.coupon_id = cm.coupon_id
       AND cr.student_id = cm.student_id
       AND cr.class_id = cm.class_id
    WHERE cm.student_id = p_student_id
      AND cm.class_id = p_class_id
    LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_coupon_membership_status(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_coupon_membership_status(UUID, UUID) TO service_role;

-- ---- teacher city/state for Discovery (additive) ----
ALTER TABLE teacher_profiles
    ADD COLUMN IF NOT EXISTS city TEXT,
    ADD COLUMN IF NOT EXISTS state TEXT;

ALTER TABLE student_profiles
    ADD COLUMN IF NOT EXISTS city TEXT,
    ADD COLUMN IF NOT EXISTS state TEXT;

-- ---- notifications (Slice 3A) ----
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    class_id UUID REFERENCES class_folders(id) ON DELETE CASCADE,
    shared_item_id UUID,
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON notifications(user_id, created_at DESC);

-- ---- device tokens (Slice 3B FCM) ----
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android'
        CHECK (platform IN ('android', 'ios', 'web')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT device_tokens_token_unique UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

-- ---- RLS ----
ALTER TABLE teacher_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS teacher_coupons_select_own ON teacher_coupons;
CREATE POLICY teacher_coupons_select_own ON teacher_coupons FOR SELECT
    USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS teacher_coupons_insert_own ON teacher_coupons;
CREATE POLICY teacher_coupons_insert_own ON teacher_coupons FOR INSERT
    WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS coupon_redemptions_select_own ON coupon_redemptions;
CREATE POLICY coupon_redemptions_select_own ON coupon_redemptions FOR SELECT
    USING (
        student_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM teacher_coupons tc
            WHERE tc.id = coupon_id AND tc.teacher_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS notifications_select_own ON notifications;
CREATE POLICY notifications_select_own ON notifications FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own ON notifications;
CREATE POLICY notifications_update_own ON notifications FOR UPDATE
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS device_tokens_own ON device_tokens;
CREATE POLICY device_tokens_own ON device_tokens FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Verify
SELECT 'teacher_coupons' AS tbl, COUNT(*) AS cols
FROM information_schema.columns WHERE table_name = 'teacher_coupons'
UNION ALL
SELECT 'coupon_redemptions', COUNT(*)
FROM information_schema.columns WHERE table_name = 'coupon_redemptions'
UNION ALL
SELECT 'notifications', COUNT(*)
FROM information_schema.columns WHERE table_name = 'notifications';
