-- ExamSpark — Group join paths architecture lock (Jul 25, 2026)
-- One group, two paths: paid (link/QR) vs coupon. Same class_memberships.
-- Run ONCE in Supabase SQL Editor after teacher_coupon_migration.sql
-- Safe to re-run (IF NOT EXISTS / CREATE OR REPLACE).

-- ---- 1) Explicit join_type (paid | coupon) ----
ALTER TABLE class_memberships
    ADD COLUMN IF NOT EXISTS join_type TEXT;

UPDATE class_memberships
SET join_type = CASE
    WHEN coupon_id IS NOT NULL THEN 'coupon'
    ELSE 'paid'
END
WHERE join_type IS NULL OR join_type NOT IN ('paid', 'coupon');

ALTER TABLE class_memberships
    ALTER COLUMN join_type SET DEFAULT 'paid';

UPDATE class_memberships SET join_type = 'paid' WHERE join_type IS NULL;

DO $$
BEGIN
    ALTER TABLE class_memberships
        ALTER COLUMN join_type SET NOT NULL;
EXCEPTION
    WHEN others THEN NULL;
END $$;

ALTER TABLE class_memberships
    DROP CONSTRAINT IF EXISTS class_memberships_join_type_check;
ALTER TABLE class_memberships
    ADD CONSTRAINT class_memberships_join_type_check
    CHECK (join_type IN ('paid', 'coupon'));

COMMENT ON COLUMN class_memberships.join_type IS
    'paid = Share link / QR (plan slot). coupon = teacher coupon first-month path. Same group.';

COMMENT ON COLUMN class_memberships.coupon_id IS
    'Set when join_type=coupon (teacher coupon). NULL when join_type=paid.';

-- ---- 2) Paid join path inserts join_type=paid ----
CREATE OR REPLACE FUNCTION fn_request_or_join_group(p_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mode TEXT;
  v_uid UUID := auth.uid();
  v_req_id UUID;
  v_plan TEXT;
  v_paid BOOLEAN := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT join_approval_mode INTO v_mode
  FROM class_folders WHERE id = p_class_id;

  IF NOT FOUND OR v_mode IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM class_memberships
    WHERE class_id = p_class_id AND student_id = v_uid
  ) THEN
    RETURN jsonb_build_object('status', 'already_member');
  END IF;

  v_plan := COALESCE(fn_user_plan_tier(v_uid), 'free');
  v_paid := v_plan IN ('plan_199', 'plan_499', 'plan_999', 'teacher');

  IF COALESCE(v_mode, 'auto') = 'auto' OR v_paid THEN
    INSERT INTO class_memberships (class_id, student_id, join_type, coupon_id)
    VALUES (p_class_id, v_uid, 'paid', NULL)
    ON CONFLICT (class_id, student_id) DO NOTHING;
    RETURN jsonb_build_object(
      'status', 'joined',
      'skipped_approval', v_paid AND COALESCE(v_mode, 'auto') = 'approval',
      'plan', v_plan,
      'join_type', 'paid'
    );
  END IF;

  INSERT INTO group_join_requests (class_id, student_id, status)
  VALUES (p_class_id, v_uid, 'pending')
  ON CONFLICT (class_id, student_id) DO UPDATE
    SET status = 'pending',
        resolved_at = NULL,
        created_at = CASE
          WHEN group_join_requests.status = 'pending'
            THEN group_join_requests.created_at
          ELSE now()
        END
  RETURNING id INTO v_req_id;

  RETURN jsonb_build_object(
    'status', 'pending',
    'request_id', v_req_id,
    'plan', v_plan
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fn_request_or_join_group(UUID) TO authenticated;

-- ---- 3) Slot limit: count ONLY paid joins (coupon bypasses + does not consume slots) ----
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
    -- Normalize join_type from coupon_id if missing.
    IF NEW.join_type IS NULL THEN
        NEW.join_type := CASE WHEN NEW.coupon_id IS NOT NULL THEN 'coupon' ELSE 'paid' END;
    END IF;

    IF NEW.coupon_id IS NOT NULL OR NEW.join_type = 'coupon' THEN
        NEW.join_type := 'coupon';
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

    NEW.join_type := 'paid';
    NEW.coupon_id := NULL;

    v_plan_id := fn_user_plan_tier(NEW.student_id);
    SELECT max_groups INTO v_max
    FROM subscription_plans
    WHERE id = v_plan_id;

    v_max := COALESCE(v_max, 0);

    IF v_max < 0 THEN
        RETURN NEW;
    END IF;

    -- Paid slots only — coupon memberships never consume 1/3/6.
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM class_memberships
    WHERE student_id = NEW.student_id
      AND COALESCE(join_type, 'paid') = 'paid'
      AND coupon_id IS NULL;

    IF v_count >= v_max THEN
        RAISE EXCEPTION
            'Group join limit reached (plan %, max %)', v_plan_id, v_max;
    END IF;

    RETURN NEW;
END;
$$;

-- ---- 4) Trim: keep coupon members; trim paid slots only ----
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
        DELETE FROM class_memberships
        WHERE student_id = p_user_id
          AND COALESCE(join_type, 'paid') = 'paid'
          AND coupon_id IS NULL;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        RETURN v_deleted;
    END IF;

    DELETE FROM class_memberships
    WHERE id IN (
        SELECT id
        FROM class_memberships
        WHERE student_id = p_user_id
          AND COALESCE(join_type, 'paid') = 'paid'
          AND coupon_id IS NULL
        ORDER BY joined_at DESC
        OFFSET v_max
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trim_group_memberships(UUID) TO service_role;

-- ---- 5) Content access: coupon expired + no paid plan → read_only/locked (stay in group) ----
CREATE OR REPLACE FUNCTION fn_group_item_access(p_user_id UUID, p_item_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_class_id UUID;
    v_shared_at TIMESTAMP;
    v_joined_at TIMESTAMP;
    v_expired_mode TEXT;
    v_sub_status TEXT;
    v_sub_start TIMESTAMP;
    v_sub_end TIMESTAMP;
    v_join_type TEXT;
    v_coupon_id UUID;
    v_coupon_access_ends TIMESTAMPTZ;
    v_plan TEXT;
    v_has_paid BOOLEAN := false;
BEGIN
    SELECT class_id, shared_at INTO v_class_id, v_shared_at
    FROM group_shared_items WHERE id = p_item_id;

    IF v_class_id IS NULL THEN
        RETURN 'none';
    END IF;

    SELECT joined_at, join_type, coupon_id
    INTO v_joined_at, v_join_type, v_coupon_id
    FROM class_memberships
    WHERE class_id = v_class_id AND student_id = p_user_id;

    IF v_joined_at IS NULL THEN
        RETURN 'none';
    END IF;

    SELECT expired_access_mode INTO v_expired_mode
    FROM class_folders WHERE id = v_class_id;

    v_plan := COALESCE(fn_user_plan_tier(p_user_id), 'free');
    v_has_paid := v_plan IN ('plan_199', 'plan_499', 'plan_999', 'teacher');

    -- Coupon path: after access_ends_at, stay member but lock unless they have paid plan.
    IF COALESCE(v_join_type, 'paid') = 'coupon' OR v_coupon_id IS NOT NULL THEN
        SELECT cr.access_ends_at INTO v_coupon_access_ends
        FROM coupon_redemptions cr
        WHERE cr.student_id = p_user_id
          AND cr.class_id = v_class_id
          AND (v_coupon_id IS NULL OR cr.coupon_id = v_coupon_id)
        ORDER BY cr.redeemed_at DESC
        LIMIT 1;

        IF v_coupon_access_ends IS NOT NULL
           AND v_coupon_access_ends <= now()
           AND NOT v_has_paid THEN
            RETURN COALESCE(v_expired_mode, 'read_only');
        END IF;

        -- Active coupon month (or paid upgrade) → full for items they can see as member.
        IF v_has_paid OR (v_coupon_access_ends IS NOT NULL AND v_coupon_access_ends > now()) THEN
            -- Fall through to shared_at / membership timing rules below.
            NULL;
        END IF;
    END IF;

    SELECT status, current_period_start, current_period_end
    INTO v_sub_status, v_sub_start, v_sub_end
    FROM user_subscriptions
    WHERE user_id = p_user_id
    ORDER BY current_period_end DESC
    LIMIT 1;

    IF v_joined_at <= v_shared_at THEN
        IF v_sub_status IS NULL THEN
            RETURN 'full';
        ELSIF v_sub_status = 'active' AND v_sub_end >= now() THEN
            RETURN 'full';
        ELSE
            RETURN COALESCE(v_expired_mode, 'read_only');
        END IF;
    END IF;

    IF v_sub_start IS NOT NULL AND v_shared_at >= v_sub_start
       AND (v_sub_end IS NULL OR v_shared_at <= v_sub_end) THEN
        IF v_sub_status = 'active' THEN
            RETURN 'full';
        ELSE
            RETURN COALESCE(v_expired_mode, 'read_only');
        END IF;
    END IF;

    RETURN 'none';
END;
$$;

GRANT EXECUTE ON FUNCTION fn_group_item_access(UUID, UUID) TO authenticated;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'class_memberships' AND column_name IN ('join_type', 'coupon_id');
