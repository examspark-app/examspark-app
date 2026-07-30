-- ExamSpark: Teacher Profile = master for Discover / Group sync (Option A)
-- Adds class_levels + exams (comma-separated, like subject) on teacher_profiles.
-- Founder: run once in Supabase → SQL Editor → Run.
-- Guide: FOUNDER_DISCOVER_PROFILE_GROUP_SYNC.md

ALTER TABLE public.teacher_profiles
  ADD COLUMN IF NOT EXISTS class_levels text,
  ADD COLUMN IF NOT EXISTS exams text;

COMMENT ON COLUMN public.teacher_profiles.class_levels IS
  'Comma-separated class/levels teacher offers (no max). Group create picks from this list.';
COMMENT ON COLUMN public.teacher_profiles.exams IS
  'Comma-separated boards/exams teacher offers (no max). Group create picks from this list.';
