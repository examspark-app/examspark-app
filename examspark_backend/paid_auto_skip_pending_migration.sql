-- ExamSpark — Paid students skip join Pending (Approve groups)
-- Founder lock Jul 23, 2026: Free → Pending if Approve; ₹199/499/999 → always Auto.
-- Run AFTER create_study_group_v2_approval_migration.sql
-- Supabase → SQL Editor → Run

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
    -- join_approval_mode NOT NULL DEFAULT 'auto' — missing row = not found
    RAISE EXCEPTION 'Group not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM class_memberships
    WHERE class_id = p_class_id AND student_id = v_uid
  ) THEN
    RETURN jsonb_build_object('status', 'already_member');
  END IF;

  -- Active plan tier (same helper as join limits).
  v_plan := COALESCE(fn_user_plan_tier(v_uid), 'free');
  v_paid := v_plan IN ('plan_199', 'plan_499', 'plan_999', 'teacher');

  -- Auto mode OR paid student → instant membership (join limits still apply via trigger).
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

  -- Free + approval mode → pending request
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
  'Join or request group. Free+Approve→pending; paid plan_199/499/999 (+teacher) always auto-join.';

-- Verify function body mentions paid skip
SELECT proname, pg_get_functiondef(oid) ILIKE '%plan_199%' AS has_paid_skip
FROM pg_proc
WHERE proname = 'fn_request_or_join_group';
