-- ============================================================================
-- ExamSpark — Library Favorites (Phase 2 Slice 2)
-- Run ONCE in Supabase SQL Editor, then Flutter hot restart.
--
-- Adds: lectures.is_favorite BOOLEAN DEFAULT false
-- Owner can toggle via RLS (existing lectures UPDATE policy).
-- ============================================================================

ALTER TABLE public.lectures
  ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.lectures.is_favorite IS
  'Library Favorites pin — owner toggle only. Phase 2 Slice 2.';

CREATE INDEX IF NOT EXISTS idx_lectures_user_favorite
  ON public.lectures (user_id)
  WHERE is_favorite = true;
