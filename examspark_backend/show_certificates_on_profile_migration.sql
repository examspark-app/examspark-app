-- ExamSpark — Show certificates on student-facing profile (teacher choice ON/OFF)
-- Founder Jul 25, 2026. Run ONCE in Supabase SQL Editor. Safe to re-run.
--
-- Default OFF — teacher must turn ON to show profile certificates to students.
-- Get Verified (AI) is separate and unchanged.

ALTER TABLE public.teacher_profiles
  ADD COLUMN IF NOT EXISTS show_certificates_on_profile BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.teacher_profiles.show_certificates_on_profile IS
  'Teacher choice: when true, profile certificates visible to students (Group Info etc.). Default false. Not Get Verified.';

-- Students may only read certificates when teacher opted in (or own row).
DROP POLICY IF EXISTS "teacher_certificates_select_all" ON public.teacher_certificates;
DROP POLICY IF EXISTS "teacher_certificates_select" ON public.teacher_certificates;

CREATE POLICY "teacher_certificates_select" ON public.teacher_certificates
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.teacher_profiles tp
      WHERE tp.id = teacher_id
        AND (
          tp.user_id = auth.uid()
          OR tp.show_certificates_on_profile = true
        )
    )
  );

-- Verify
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'teacher_profiles'
  AND column_name = 'show_certificates_on_profile';
