-- All accounts → Free + auto-leave groups (Free join-lock smoke)
-- Supabase SQL Editor · postgres · Run once
-- Requires: subscription_change_trim_groups_migration.sql (trigger on expire)

UPDATE public.user_subscriptions
SET status = 'expired',
    updated_at = now()
WHERE status IN ('active', 'grace_period', 'pending');

-- Safety if trim trigger not installed yet:
DELETE FROM public.class_memberships;

-- VERIFY
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan,
  u.credits_balance AS credits,
  (
    SELECT count(*) FROM public.class_memberships cm
    WHERE cm.student_id = u.id
  ) AS groups
FROM public.users u
ORDER BY u.email;

-- Expect every row: plan = free, groups = 0
-- App (no logout if live sync ON):
--   Profile → Free Plan
--   Groups → Join Group → Buy Plan / upgrade sheet (NO join)
