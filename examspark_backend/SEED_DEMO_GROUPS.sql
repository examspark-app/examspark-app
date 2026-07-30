-- Seed 3 REAL public demo groups so students can Join (UUID ids).
-- Required after RLS fix — empty class_folders was showing FAKE mock cards
-- (group_1 / group_2) and Join failed with "Could not join group".
--
-- Run once in Supabase SQL Editor (postgres). Safe to re-run (join_code unique).

DO $$
DECLARE
  v_teacher UUID;
BEGIN
  -- Prefer a teacher role user; else any user.
  SELECT id INTO v_teacher
  FROM public.users
  WHERE role = 'teacher'
  ORDER BY created_at NULLS LAST
  LIMIT 1;

  IF v_teacher IS NULL THEN
    SELECT id INTO v_teacher FROM public.users ORDER BY created_at NULLS LAST LIMIT 1;
  END IF;

  IF v_teacher IS NULL THEN
    RAISE EXCEPTION 'No users row — create / login one account first';
  END IF;

  -- Ensure teacher_profiles row exists (Groups UI uses it).
  INSERT INTO public.teacher_profiles (user_id, full_name, subject)
  VALUES (v_teacher, 'Demo Teacher', 'Mixed')
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.class_folders (
    teacher_id, name, subject, description, join_code, is_public, allow_downloads
  )
  VALUES
    (
      v_teacher,
      'Physics Batch — NEET 2026',
      'Physics',
      'Demo public group for join-limit testing.',
      'PHY001',
      true,
      false
    ),
    (
      v_teacher,
      'Organic Chemistry Mastery',
      'Chemistry',
      'Demo public group for join-limit testing.',
      'CHM001',
      true,
      false
    ),
    (
      v_teacher,
      'JEE Mathematics Sprint',
      'Mathematics',
      'Demo public group for join-limit testing.',
      'MTH001',
      true,
      false
    )
  ON CONFLICT (join_code) DO NOTHING;
END $$;

-- Verify
SELECT id, name, join_code, is_public, teacher_id
FROM public.class_folders
ORDER BY created_at;
