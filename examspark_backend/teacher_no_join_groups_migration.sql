-- Teacher ₹2,999 cannot JOIN another teacher's Group as a student.
-- Own Groups (create / dashboard) stay unlimited — separate from max_groups.
-- Founder lock Jul 26, 2026.
-- Supabase → SQL Editor → Run once.

-- 1) Join cap: teacher max_groups = 0 (was -1 unlimited join)
UPDATE public.subscription_plans
SET max_groups = 0
WHERE id = 'teacher';

-- 2) Join RPC: hard-block teacher plan (clear error)
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

  -- Teacher plan = own Groups / dashboard only — never join as student.
  IF v_plan = 'teacher' THEN
    RAISE EXCEPTION
      'Teacher plan cannot join Groups as a student — manage your own Groups only';
  END IF;

  -- Paid students only (not teacher)
  v_paid := v_plan IN ('plan_199', 'plan_499', 'plan_999');

  IF COALESCE(v_mode, 'auto') = 'auto' OR v_paid THEN
    INSERT INTO class_memberships (class_id, student_id, join_type, coupon_id)
    VALUES (p_class_id, v_uid, 'paid', NULL)
    ON CONFLICT (class_id, student_id) DO NOTHING;
    RETURN jsonb_build_object(
      'status', 'joined',
      'skipped_approval', v_paid AND COALESCE(v_mode, 'auto') = 'approval',
      'plan', v_plan
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

COMMENT ON FUNCTION fn_request_or_join_group(UUID) IS
  'Join/request group. Teacher plan blocked. Free+Approve→pending; plan_199/499/999 auto.';

-- Verify
SELECT id, name, max_groups
FROM public.subscription_plans
WHERE id = 'teacher';
-- Expect: max_groups = 0
