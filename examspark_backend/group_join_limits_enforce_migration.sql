-- Group join limits — server enforce + trim on refund/plan drop
-- Run once in Supabase SQL Editor (after subscription_plans.max_groups exists).
-- Free=0, plan_199=1, plan_499=3, plan_999=6, teacher=-1 (unlimited).

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
BEGIN
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

DROP TRIGGER IF EXISTS trg_enforce_group_join_limit ON class_memberships;
CREATE TRIGGER trg_enforce_group_join_limit
    BEFORE INSERT ON class_memberships
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_group_join_limit();

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
        DELETE FROM class_memberships WHERE student_id = p_user_id;
        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        RETURN v_deleted;
    END IF;

    -- Keep newest joined_at rows up to v_max; delete older excess.
    DELETE FROM class_memberships
    WHERE id IN (
        SELECT id
        FROM class_memberships
        WHERE student_id = p_user_id
        ORDER BY joined_at DESC
        OFFSET v_max
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_trim_group_memberships(UUID) TO service_role;

COMMENT ON FUNCTION fn_trim_group_memberships IS
  'Leave groups beyond plan max_groups after refund/downgrade. FastAPI / service_role only.';
