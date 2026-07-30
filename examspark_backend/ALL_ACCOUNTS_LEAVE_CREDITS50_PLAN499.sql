-- ONE script: ALL accounts
-- 1) Leave ALL groups (every student)
-- 2) Credits = 50 (every user in public.users)
-- 3) Expire old subs + give plan_499 (every user)
--
-- Supabase SQL Editor → role postgres → Run once.
-- Then: Profile should show ₹499 · Groups all Join · Home credits 50
-- (App needs SessionLiveSync + Realtime ON, or tab switch Home/Groups/Profile)

-- ========== 1) LEAVE ALL GROUPS ==========
DELETE FROM public.class_memberships;

-- ========== 2) CREDITS = 50 (all users) ==========
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.users LOOP
    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE public.users SET credits_balance = 50 WHERE id = r.id;
    PERFORM set_config('app.allow_credit_change', 'false', true);
  END LOOP;
END $$;

-- ========== 3) PLAN → ₹499 (all users) ==========
UPDATE public.user_subscriptions
SET status = 'expired',
    updated_at = now()
WHERE status IN ('active', 'grace_period', 'pending');

INSERT INTO public.user_subscriptions (
  user_id,
  plan_id,
  status,
  platform,
  gateway,
  current_period_start,
  current_period_end
)
SELECT
  u.id,
  'plan_499',
  'active',
  'web',
  'razorpay',
  now(),
  now() + interval '30 days'
FROM public.users u;

-- ========== 4) VERIFY ==========
SELECT
  u.email,
  u.credits_balance AS credits,
  public.fn_user_plan_tier(u.id) AS plan,
  (
    SELECT count(*) FROM public.class_memberships cm
    WHERE cm.student_id = u.id
  ) AS groups
FROM public.users u
ORDER BY u.email;

-- Expect every row: credits=50, plan=plan_499, groups=0
