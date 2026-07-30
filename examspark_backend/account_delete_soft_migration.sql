-- ExamSpark — Soft account delete + 30-day Library recovery
-- Founder Jul 26, 2026. Run ONCE in Supabase SQL Editor. Safe to re-run.
-- Applies to ALL roles (student + teacher).
--
-- Flow:
--   1) App calls fn_request_account_delete() → soft delete (Library kept)
--   2) Login / session → recover via fn_recover_account() within 30 days
--   3) After purge_after: founder runs fn_purge_expired_deleted_accounts()
--      (or schedule later) → hard delete public + auth

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS purge_after TIMESTAMPTZ;

COMMENT ON COLUMN public.users.deleted_at IS
  'Soft account delete requested. App shows recovery until purge_after.';
COMMENT ON COLUMN public.users.purge_after IS
  'Hard-delete eligible after this time (deleted_at + 30 days).';

CREATE INDEX IF NOT EXISTS idx_users_purge_after
  ON public.users (purge_after)
  WHERE deleted_at IS NOT NULL;

-- ========== Request soft delete (authenticated self) ==========
CREATE OR REPLACE FUNCTION public.fn_request_account_delete()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_deleted timestamptz;
  v_purge timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  UPDATE public.users
  SET
    deleted_at = COALESCE(deleted_at, now()),
    purge_after = COALESCE(purge_after, now() + interval '30 days')
  WHERE id = v_uid
  RETURNING deleted_at, purge_after INTO v_deleted, v_purge;

  IF v_deleted IS NULL THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'deleted_at', v_deleted,
    'purge_after', v_purge
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_request_account_delete() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_request_account_delete() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_request_account_delete() TO service_role;

-- ========== Recover within 30 days ==========
CREATE OR REPLACE FUNCTION public.fn_recover_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_deleted timestamptz;
  v_purge timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT deleted_at, purge_after
  INTO v_deleted, v_purge
  FROM public.users
  WHERE id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  IF v_deleted IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'already_active', true);
  END IF;

  IF v_purge IS NOT NULL AND v_purge <= now() THEN
    RAISE EXCEPTION 'recovery_window_closed';
  END IF;

  UPDATE public.users
  SET deleted_at = NULL,
      purge_after = NULL
  WHERE id = v_uid;

  RETURN jsonb_build_object('ok', true, 'recovered', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_recover_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_recover_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_recover_account() TO service_role;

-- ========== Hard purge expired soft-deletes (founder / cron) ==========
CREATE OR REPLACE FUNCTION public.fn_purge_expired_deleted_accounts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  r RECORD;
  v_count integer := 0;
BEGIN
  FOR r IN
    SELECT id
    FROM public.users
    WHERE deleted_at IS NOT NULL
      AND purge_after IS NOT NULL
      AND purge_after <= now()
  LOOP
    -- Clear pins pointing at this teacher's shares
    UPDATE public.class_folders cf
    SET pinned_item_id = NULL
    WHERE cf.pinned_item_id IN (
      SELECT gsi.id FROM public.group_shared_items gsi
      WHERE gsi.teacher_id = r.id
    )
    OR cf.teacher_id = r.id;

    DELETE FROM public.group_shared_items WHERE teacher_id = r.id;
    DELETE FROM public.class_folders WHERE teacher_id = r.id;
    DELETE FROM public.class_memberships WHERE student_id = r.id;

    DELETE FROM public.users WHERE id = r.id;
    DELETE FROM auth.users WHERE id = r.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_purge_expired_deleted_accounts() FROM PUBLIC;
-- Founder runs in SQL Editor as postgres. Also allow service_role for future cron.
GRANT EXECUTE ON FUNCTION public.fn_purge_expired_deleted_accounts() TO service_role;

-- ========== Hide soft-deleted teachers from Discover fuzzy ==========
CREATE OR REPLACE FUNCTION public.fn_teacher_discover_fuzzy(
  p_query text,
  p_threshold real DEFAULT 0.35
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  full_name text,
  photo_url text,
  subject text,
  city text,
  state text,
  language text,
  verification_status text,
  is_suggested boolean,
  sim real
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  WITH q AS (
    SELECT lower(trim(p_query)) AS needle
  )
  SELECT
    tp.id,
    tp.user_id,
    tp.full_name,
    tp.photo_url,
    tp.subject,
    tp.city,
    tp.state,
    tp.language,
    tp.verification_status,
    tp.is_suggested,
    GREATEST(
      similarity(lower(coalesce(tp.city, '')), q.needle),
      similarity(lower(coalesce(tp.state, '')), q.needle),
      similarity(lower(coalesce(tp.full_name, '')), q.needle),
      word_similarity(q.needle, lower(coalesce(tp.subject, ''))),
      word_similarity(q.needle, lower(coalesce(tp.full_name, ''))),
      word_similarity(q.needle, lower(coalesce(tp.city, ''))),
      word_similarity(q.needle, lower(coalesce(tp.state, '')))
    )::real AS sim
  FROM public.teacher_profiles tp
  JOIN public.users u ON u.id = tp.user_id
  CROSS JOIN q
  WHERE u.deleted_at IS NULL
    AND length(q.needle) >= 2
    AND (
      similarity(lower(coalesce(tp.city, '')), q.needle) >= p_threshold
      OR similarity(lower(coalesce(tp.state, '')), q.needle) >= p_threshold
      OR similarity(lower(coalesce(tp.full_name, '')), q.needle) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.subject, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.full_name, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.city, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.state, ''))) >= p_threshold
      OR lower(coalesce(tp.city, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.state, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.subject, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.full_name, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.language, '')) LIKE '%' || q.needle || '%'
    )
  ORDER BY sim DESC NULLS LAST;
$$;

COMMENT ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) IS
  'Teacher Discovery fuzzy match; excludes soft-deleted users (deleted_at).';

GRANT EXECUTE ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) TO anon;

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name IN ('deleted_at', 'purge_after')
ORDER BY column_name;

SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'fn_request_account_delete',
    'fn_recover_account',
    'fn_purge_expired_deleted_accounts'
  )
ORDER BY proname;
