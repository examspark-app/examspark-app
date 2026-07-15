-- ============================================================
-- SMOKE: All accounts → ₹199  → (app check) → Free → Join lock
-- Supabase SQL Editor · role postgres
--
-- Before this: SEED_DEMO_GROUPS.sql + fix_class_folders_rls_recursion
--              already run once.
-- ============================================================

-- ========== PART A — ALL accounts → plan_199 ==========
UPDATE public.user_subscriptions
SET status = 'expired', updated_at = now()
WHERE status IN ('active', 'grace_period', 'pending');

INSERT INTO public.user_subscriptions (
  user_id, plan_id, status, platform, gateway,
  current_period_start, current_period_end
)
SELECT
  u.id,
  'plan_199',
  'active',
  'web',
  'razorpay',
  now(),
  now() + interval '30 days'
FROM public.users u;

-- VERIFY A (every row = plan_199)
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

-- Expect: plan = plan_199 for all
-- >>> STOP HERE — go to app (no logout needed if live sync ON):
--     Profile → Subscription = ₹199
--     Groups → Join Group on a DEMO group = should JOIN (limit 1)
--     2nd group Join → Buy Plan / limit sheet
-- >>> When done, come back and run PART B only (below).


-- ========== PART B — ALL accounts → Free (for Free join lock smoke) ==========
-- Uncomment / select & run AFTER Part B when ready:

/*
UPDATE public.user_subscriptions
SET status = 'expired', updated_at = now()
WHERE status IN ('active', 'grace_period', 'pending');

-- Optional: leave all groups so Free starts at 0 memberships
DELETE FROM public.class_memberships;

SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan,
  (
    SELECT count(*) FROM public.class_memberships cm
    WHERE cm.student_id = u.id
  ) AS groups
FROM public.users u
ORDER BY u.email;

-- Expect: plan = free, groups = 0
-- >>> App: Profile = Free · Groups → Join Group → Buy Plan sheet (NO join)
*/
