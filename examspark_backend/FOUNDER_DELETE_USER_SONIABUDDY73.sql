-- REUSABLE: Delete account every time for smoke / re-signup
-- Email: soniabuddy73@gmail.com
-- Supabase → SQL Editor → Run STEP 1 first, then STEP 2 (all), then STEP 3, then STEP 4
-- WARNING: Permanently deletes lectures, groups, shares, credits, profiles for this email.
--
-- Fix Jul 26, 2026: group_shared_items.teacher_id has NO ON DELETE CASCADE —
-- must delete shares (and clear pins) BEFORE public.users.

-- ========== STEP 1 — Preview (safe) ==========
SELECT id, email, created_at, last_sign_in_at
FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

SELECT id, email, role, credits_balance, created_at
FROM public.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

-- 0 rows → already deleted / wrong project. STOP.

-- ========== STEP 2 — App data (order matters) ==========
DO $$
DECLARE
  v_uid UUID;
BEGIN
  SELECT id INTO v_uid
  FROM public.users
  WHERE lower(email) = lower('soniabuddy73@gmail.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE NOTICE 'No public.users row — skip app delete';
    RETURN;
  END IF;

  -- 2a) Unpin any feed items owned by this teacher (class_folders.pinned_item_id)
  UPDATE public.class_folders cf
  SET pinned_item_id = NULL
  WHERE cf.pinned_item_id IN (
    SELECT gsi.id
    FROM public.group_shared_items gsi
    WHERE gsi.teacher_id = v_uid
  )
  OR cf.teacher_id = v_uid;

  -- 2b) Shares where this user is teacher (blocks users delete — FK 23503)
  DELETE FROM public.group_shared_items
  WHERE teacher_id = v_uid;

  -- 2c) Groups owned by this teacher (memberships / shares cascade from folders)
  DELETE FROM public.class_folders
  WHERE teacher_id = v_uid;

  -- 2d) Leave other teachers' groups as student
  DELETE FROM public.class_memberships
  WHERE student_id = v_uid;

  -- 2e) Core user row (cascades lectures, profiles, credits logs where ON DELETE CASCADE)
  DELETE FROM public.users
  WHERE id = v_uid;
END $$;

-- ========== STEP 3 — Auth (frees email for new signup) ==========
DELETE FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

-- ========== STEP 4 — Verify (must be 0 rows) ==========
SELECT id, email FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

SELECT id, email FROM public.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

-- After delete: Flutter Logout OR clear site data for localhost:8080,
-- then signup again with soniabuddy73@gmail.com
-- Then run: FOUNDER_MOCK_TEST_SONIABUDDY73.sql
