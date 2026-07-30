-- Fix: infinite recursion in RLS between class_folders <-> class_memberships
-- Error: 42P17 "infinite recursion detected in policy for relation class_folders"
-- Symptom: Groups list falls back to MOCK (one group looks pre-joined);
--          canJoinAnotherGroup fails → Buy Plan sheet with plan "Unknown"
--          even when Profile shows ₹499.
--
-- Run once in Supabase SQL Editor (postgres role).

-- SECURITY DEFINER helpers — read tables without re-entering RLS policies.
CREATE OR REPLACE FUNCTION public.fn_is_class_member(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.class_memberships
    WHERE class_id = p_class_id
      AND student_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_is_class_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.class_folders
    WHERE id = p_class_id
      AND teacher_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.fn_is_class_member(UUID) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.fn_is_class_teacher(UUID) TO authenticated, anon;

-- Replace recursive policies
DROP POLICY IF EXISTS "class_folders_select" ON public.class_folders;
CREATE POLICY "class_folders_select" ON public.class_folders FOR SELECT
    USING (
        is_public = true
        OR teacher_id = auth.uid()
        OR public.fn_is_class_member(id)
    );

DROP POLICY IF EXISTS "class_memberships_select" ON public.class_memberships;
CREATE POLICY "class_memberships_select" ON public.class_memberships FOR SELECT
    USING (
        student_id = auth.uid()
        OR public.fn_is_class_teacher(class_id)
    );

COMMENT ON FUNCTION public.fn_is_class_member IS
  'RLS helper — avoids class_folders/class_memberships policy recursion';
COMMENT ON FUNCTION public.fn_is_class_teacher IS
  'RLS helper — avoids class_folders/class_memberships policy recursion';
