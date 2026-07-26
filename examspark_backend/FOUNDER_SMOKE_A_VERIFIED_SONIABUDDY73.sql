-- SMOKE A — Force Trusted / AI Verified (mock)
-- Email: soniabuddy73@gmail.com
-- Supabase → SQL Editor → Run alone (do not mix with other files)
-- Use when AI verify is slow/fail but you need Create Group / plan gate smoke.
-- Does NOT run real AI.

-- 0) User must exist
SELECT id, email FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');
-- 0 rows → signup first as Teacher, then re-run.

-- 1) Ensure teacher role + teacher_profiles row
UPDATE public.users
SET role = 'teacher',
    onboarding_completed = true
WHERE lower(email) = lower('soniabuddy73@gmail.com');

INSERT INTO public.teacher_profiles (user_id, full_name, subject, city, state, qualification)
SELECT
  u.id,
  COALESCE(NULLIF(trim(u.full_name), ''), 'Sonia Buddy'),
  'Mathematics',
  'Pune',
  'Maharashtra',
  'M.Sc'
FROM public.users u
WHERE lower(u.email) = lower('soniabuddy73@gmail.com')
ON CONFLICT (user_id) DO UPDATE
SET
  full_name = COALESCE(NULLIF(trim(teacher_profiles.full_name), ''), EXCLUDED.full_name),
  subject = COALESCE(NULLIF(trim(teacher_profiles.subject), ''), EXCLUDED.subject),
  city = COALESCE(NULLIF(trim(teacher_profiles.city), ''), EXCLUDED.city),
  state = COALESCE(NULLIF(trim(teacher_profiles.state), ''), EXCLUDED.state),
  qualification = COALESCE(
    NULLIF(trim(teacher_profiles.qualification), ''),
    EXCLUDED.qualification
  );

-- 2) Mark verified (Trusted badge)
UPDATE public.teacher_profiles tp
SET
  verification_status = 'verified',
  verification_score = 95,
  verification_date = now()
FROM public.users u
WHERE tp.user_id = u.id
  AND lower(u.email) = lower('soniabuddy73@gmail.com');

-- 3) Verify
SELECT
  u.email,
  u.role,
  tp.verification_status,
  tp.verification_score,
  tp.verification_date,
  tp.full_name,
  tp.subject
FROM public.users u
JOIN public.teacher_profiles tp ON tp.user_id = u.id
WHERE lower(u.email) = lower('soniabuddy73@gmail.com');
-- Expect: role=teacher, verification_status=verified, score=95
