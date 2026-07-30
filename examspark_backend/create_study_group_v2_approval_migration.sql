-- ExamSpark — Create Study Group v2: join approval + pending requests
-- Run once after create_study_group_v1_migration.sql
-- Supabase → SQL Editor → Run

-- ---- class_folders.join_approval_mode ----
ALTER TABLE class_folders
    ADD COLUMN IF NOT EXISTS join_approval_mode TEXT NOT NULL DEFAULT 'auto';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'class_folders_join_approval_mode_check'
  ) THEN
    ALTER TABLE class_folders
      ADD CONSTRAINT class_folders_join_approval_mode_check
      CHECK (join_approval_mode IN ('auto', 'approval'));
  END IF;
END $$;

COMMENT ON COLUMN class_folders.join_approval_mode IS
  'auto = join instantly; approval = student goes to Pending Requests.';

-- ---- Pending join requests ----
CREATE TABLE IF NOT EXISTS group_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    CONSTRAINT group_join_requests_unique_student UNIQUE (class_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_group_join_requests_class_status
    ON group_join_requests (class_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_group_join_requests_student
    ON group_join_requests (student_id, status);

ALTER TABLE group_join_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "group_join_requests_select" ON group_join_requests;
CREATE POLICY "group_join_requests_select" ON group_join_requests
    FOR SELECT USING (
        student_id = auth.uid()
        OR fn_is_class_teacher(class_id)
    );

DROP POLICY IF EXISTS "group_join_requests_insert_own" ON group_join_requests;
CREATE POLICY "group_join_requests_insert_own" ON group_join_requests
    FOR INSERT WITH CHECK (
        student_id = auth.uid()
        AND status = 'pending'
    );

DROP POLICY IF EXISTS "group_join_requests_update_own_pending" ON group_join_requests;
-- Students may re-open a rejected request to pending (upsert path).
CREATE POLICY "group_join_requests_update_own_pending" ON group_join_requests
    FOR UPDATE USING (student_id = auth.uid())
    WITH CHECK (student_id = auth.uid() AND status = 'pending');

GRANT SELECT, INSERT, UPDATE ON group_join_requests TO authenticated;
GRANT ALL ON group_join_requests TO service_role;

-- ---- Student: request or auto-join ----
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
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT join_approval_mode INTO v_mode
  FROM class_folders WHERE id = p_class_id;

  IF v_mode IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM class_memberships
    WHERE class_id = p_class_id AND student_id = v_uid
  ) THEN
    RETURN jsonb_build_object('status', 'already_member');
  END IF;

  IF COALESCE(v_mode, 'auto') = 'auto' THEN
    INSERT INTO class_memberships (class_id, student_id)
    VALUES (p_class_id, v_uid)
    ON CONFLICT (class_id, student_id) DO NOTHING;
    RETURN jsonb_build_object('status', 'joined');
  END IF;

  -- approval mode → pending request
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

  RETURN jsonb_build_object('status', 'pending', 'request_id', v_req_id);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_request_or_join_group(UUID) TO authenticated;

-- ---- Teacher: accept ----
CREATE OR REPLACE FUNCTION fn_accept_group_join_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT gjr.id, gjr.class_id, gjr.student_id, gjr.status, cf.teacher_id
  INTO r
  FROM group_join_requests gjr
  JOIN class_folders cf ON cf.id = gjr.class_id
  WHERE gjr.id = p_request_id;

  IF r.id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF r.teacher_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the group teacher can accept';
  END IF;
  IF r.status <> 'pending' THEN
    RAISE EXCEPTION 'Request is not pending';
  END IF;

  INSERT INTO class_memberships (class_id, student_id)
  VALUES (r.class_id, r.student_id)
  ON CONFLICT (class_id, student_id) DO NOTHING;

  UPDATE group_join_requests
  SET status = 'accepted', resolved_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'status', 'accepted',
    'class_id', r.class_id,
    'student_id', r.student_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION fn_accept_group_join_request(UUID) TO authenticated;

-- ---- Teacher: reject ----
CREATE OR REPLACE FUNCTION fn_reject_group_join_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT gjr.id, gjr.status, cf.teacher_id
  INTO r
  FROM group_join_requests gjr
  JOIN class_folders cf ON cf.id = gjr.class_id
  WHERE gjr.id = p_request_id;

  IF r.id IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;
  IF r.teacher_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the group teacher can reject';
  END IF;
  IF r.status <> 'pending' THEN
    RAISE EXCEPTION 'Request is not pending';
  END IF;

  UPDATE group_join_requests
  SET status = 'rejected', resolved_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('status', 'rejected');
END;
$$;

GRANT EXECUTE ON FUNCTION fn_reject_group_join_request(UUID) TO authenticated;

-- Verify
SELECT column_name FROM information_schema.columns
WHERE table_name = 'class_folders' AND column_name = 'join_approval_mode';

SELECT 'group_join_requests' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'group_join_requests';
