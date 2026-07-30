-- ExamSpark — Weighted teacher suggestion scores (0–100) for Discovery
-- Founder Jul 25, 2026. Run AFTER teacher_discover_fuzzy_trgm_migration.sql
-- Safe to re-run.
--
-- Weights (when all student fields present):
--   Subject 40 · Exam/Board 30 · City 15 · Language 15
-- Missing student fields → skip that weight and redistribute among available.
-- Matched factors returned for "Matches: Subject, City" UI badges.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE public.student_profiles
  ADD COLUMN IF NOT EXISTS exam_target TEXT,
  ADD COLUMN IF NOT EXISTS preferred_language TEXT;

COMMENT ON COLUMN public.student_profiles.exam_target IS
  'Student exam/board: app starters OR any Custom… free text (global) for Discovery matching.';
COMMENT ON COLUMN public.student_profiles.preferred_language IS
  'Preferred learning language: app starters OR any Custom… free text (global).';

CREATE OR REPLACE FUNCTION public.fn_teacher_suggestion_scores(
  p_student_id uuid,
  p_threshold real DEFAULT 0.35
)
RETURNS TABLE (
  teacher_user_id uuid,
  teacher_profile_id uuid,
  match_score integer,
  matched_factors text[]
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $$
DECLARE
  v_subjects text[];
  v_city text;
  v_exam text;
  v_lang text;
  v_has_sub boolean;
  v_has_exam boolean;
  v_has_city boolean;
  v_has_lang boolean;
  v_total_w numeric;
  v_w_sub numeric := 0;
  v_w_exam numeric := 0;
  v_w_city numeric := 0;
  v_w_lang numeric := 0;
  r record;
  v_score numeric;
  v_factors text[];
  v_sub_hit boolean;
  v_exam_hit boolean;
  v_city_hit boolean;
  v_lang_hit boolean;
  v_subj text;
  v_teacher_exams text;
  v_teacher_langs text;
BEGIN
  -- Only own scores (students). Teachers calling with own id still OK (empty prefs).
  IF auth.uid() IS NOT NULL AND p_student_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'fn_teacher_suggestion_scores: student_id must be auth.uid()';
  END IF;

  SELECT
    coalesce(sp.subjects, '{}'::text[]),
    nullif(trim(coalesce(sp.city, '')), ''),
    nullif(trim(coalesce(sp.exam_target, '')), ''),
    nullif(trim(coalesce(sp.preferred_language, '')), '')
  INTO v_subjects, v_city, v_exam, v_lang
  FROM public.student_profiles sp
  WHERE sp.user_id = p_student_id;

  IF NOT FOUND THEN
    v_subjects := '{}';
    v_city := NULL;
    v_exam := NULL;
    v_lang := NULL;
  END IF;

  v_has_sub := coalesce(cardinality(v_subjects), 0) > 0;
  v_has_exam := v_exam IS NOT NULL;
  v_has_city := v_city IS NOT NULL;
  v_has_lang := v_lang IS NOT NULL;

  v_total_w := 0;
  IF v_has_sub THEN v_total_w := v_total_w + 40; END IF;
  IF v_has_exam THEN v_total_w := v_total_w + 30; END IF;
  IF v_has_city THEN v_total_w := v_total_w + 15; END IF;
  IF v_has_lang THEN v_total_w := v_total_w + 15; END IF;

  IF v_total_w > 0 THEN
    IF v_has_sub THEN v_w_sub := 40.0 / v_total_w * 100; END IF;
    IF v_has_exam THEN v_w_exam := 30.0 / v_total_w * 100; END IF;
    IF v_has_city THEN v_w_city := 15.0 / v_total_w * 100; END IF;
    IF v_has_lang THEN v_w_lang := 15.0 / v_total_w * 100; END IF;
  END IF;

  FOR r IN
    SELECT
      tp.id AS profile_id,
      tp.user_id AS uid,
      coalesce(tp.subject, '') AS subject,
      coalesce(tp.city, '') AS city,
      coalesce(tp.language, '') AS language
    FROM public.teacher_profiles tp
  LOOP
    v_score := 0;
    v_factors := ARRAY[]::text[];
    v_sub_hit := false;
    v_exam_hit := false;
    v_city_hit := false;
    v_lang_hit := false;

    -- Subject (fuzzy / word_similarity against teacher subject blob)
    IF v_has_sub AND v_total_w > 0 THEN
      FOREACH v_subj IN ARRAY v_subjects
      LOOP
        IF length(trim(v_subj)) < 2 THEN
          CONTINUE;
        END IF;
        IF word_similarity(lower(trim(v_subj)), lower(r.subject)) >= p_threshold
           OR similarity(lower(trim(v_subj)), lower(r.subject)) >= p_threshold
           OR lower(r.subject) LIKE '%' || lower(trim(v_subj)) || '%'
        THEN
          v_sub_hit := true;
          EXIT;
        END IF;
      END LOOP;
      IF v_sub_hit THEN
        v_score := v_score + v_w_sub;
        v_factors := array_append(v_factors, 'Subject');
      END IF;
    END IF;

    -- Exam/Board — any of teacher's groups
    IF v_has_exam AND v_total_w > 0 THEN
      SELECT string_agg(DISTINCT lower(trim(cf.exam)), ' | ')
      INTO v_teacher_exams
      FROM public.class_folders cf
      WHERE cf.teacher_id = r.uid
        AND cf.exam IS NOT NULL
        AND trim(cf.exam) <> '';

      IF v_teacher_exams IS NOT NULL AND (
        word_similarity(lower(v_exam), v_teacher_exams) >= p_threshold
        OR similarity(lower(v_exam), v_teacher_exams) >= p_threshold
        OR v_teacher_exams LIKE '%' || lower(v_exam) || '%'
        OR EXISTS (
          SELECT 1
          FROM public.class_folders cf2
          WHERE cf2.teacher_id = r.uid
            AND cf2.exam IS NOT NULL
            AND (
              similarity(lower(trim(cf2.exam)), lower(v_exam)) >= p_threshold
              OR word_similarity(lower(v_exam), lower(trim(cf2.exam))) >= p_threshold
              OR lower(trim(cf2.exam)) = lower(v_exam)
            )
        )
      ) THEN
        v_exam_hit := true;
        v_score := v_score + v_w_exam;
        v_factors := array_append(v_factors, 'Exam');
      END IF;
    END IF;

    -- City (fuzzy)
    IF v_has_city AND v_total_w > 0 THEN
      IF similarity(lower(r.city), lower(v_city)) >= p_threshold
         OR word_similarity(lower(v_city), lower(r.city)) >= p_threshold
         OR lower(r.city) LIKE '%' || lower(v_city) || '%'
      THEN
        v_city_hit := true;
        v_score := v_score + v_w_city;
        v_factors := array_append(v_factors, 'City');
      END IF;
    END IF;

    -- Language — profile language OR any group language
    IF v_has_lang AND v_total_w > 0 THEN
      SELECT string_agg(DISTINCT lower(trim(x)), ' | ')
      INTO v_teacher_langs
      FROM (
        SELECT nullif(trim(r.language), '') AS lang
        UNION
        SELECT nullif(trim(cf.language), '')
        FROM public.class_folders cf
        WHERE cf.teacher_id = r.uid
      ) s(lang)
      WHERE lang IS NOT NULL;

      IF v_teacher_langs IS NOT NULL AND (
        lower(v_lang) = ANY (string_to_array(v_teacher_langs, ' | '))
        OR v_teacher_langs LIKE '%' || lower(v_lang) || '%'
        OR similarity(v_teacher_langs, lower(v_lang)) >= p_threshold
      ) THEN
        v_lang_hit := true;
        v_score := v_score + v_w_lang;
        v_factors := array_append(v_factors, 'Language');
      END IF;
    END IF;

    teacher_user_id := r.uid;
    teacher_profile_id := r.profile_id;
    match_score := least(100, greatest(0, round(v_score)::integer));
    matched_factors := v_factors;
    RETURN NEXT;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.fn_teacher_suggestion_scores(uuid, real) IS
  'Discovery personalization: redistributed Subject40/Exam30/City15/Language15 → 0–100 + matched_factors.';

GRANT EXECUTE ON FUNCTION public.fn_teacher_suggestion_scores(uuid, real) TO authenticated;

-- Verify
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'student_profiles'
  AND column_name IN ('exam_target', 'preferred_language');

SELECT proname FROM pg_proc WHERE proname = 'fn_teacher_suggestion_scores';
