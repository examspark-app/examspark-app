-- ExamSpark — Teacher Discovery fuzzy search (pg_trgm)
-- Founder Jul 25, 2026. Run ONCE in Supabase SQL Editor. Safe to re-run.
--
-- Typos / spelling variants on city, state, subject, name
-- (e.g. Bangalore↔Bengaluru, kolkta≈Kolkata) — no AI, DB-only.
-- Threshold default 0.35 (tune 0.3–0.4 after smoke).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram indexes (GIN) for fast similarity
CREATE INDEX IF NOT EXISTS idx_teacher_profiles_city_trgm
  ON public.teacher_profiles USING gin (city gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_state_trgm
  ON public.teacher_profiles USING gin (state gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_subject_trgm
  ON public.teacher_profiles USING gin (subject gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_full_name_trgm
  ON public.teacher_profiles USING gin (full_name gin_trgm_ops);

-- Optional teaching language on teacher profile (presets + Custom… in app)
ALTER TABLE public.teacher_profiles
  ADD COLUMN IF NOT EXISTS language TEXT;

COMMENT ON COLUMN public.teacher_profiles.language IS
  'Teaching language: short world starters OR any Custom… free text (global). Fuzzy Discover matches free text.';

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
  CROSS JOIN q
  WHERE length(q.needle) >= 2
    AND (
      similarity(lower(coalesce(tp.city, '')), q.needle) >= p_threshold
      OR similarity(lower(coalesce(tp.state, '')), q.needle) >= p_threshold
      OR similarity(lower(coalesce(tp.full_name, '')), q.needle) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.subject, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.full_name, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.city, ''))) >= p_threshold
      OR word_similarity(q.needle, lower(coalesce(tp.state, ''))) >= p_threshold
      -- Exact / substring still counts (cheap OR)
      OR lower(coalesce(tp.city, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.state, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.subject, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.full_name, '')) LIKE '%' || q.needle || '%'
      OR lower(coalesce(tp.language, '')) LIKE '%' || q.needle || '%'
    )
  ORDER BY sim DESC NULLS LAST;
$$;

COMMENT ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) IS
  'Teacher Discovery fuzzy match on city/state/subject/name via pg_trgm. Default threshold 0.35.';

GRANT EXECUTE ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_teacher_discover_fuzzy(text, real) TO anon;

-- Verify
SELECT extname FROM pg_extension WHERE extname = 'pg_trgm';
SELECT proname FROM pg_proc WHERE proname = 'fn_teacher_discover_fuzzy';
