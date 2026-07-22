-- ExamSpark — TEMP TEST SQL: make all current accounts plan_499 active
--
-- Use only for local founder smoke testing.
-- Run manually in Supabase Dashboard -> SQL Editor (role: postgres).
--
-- What this does:
-- 1) Expires currently active non-plan_499 subscriptions
-- 2) Updates existing plan_499 rows to active for 30 days
-- 3) Inserts plan_499 for users who do not have an active plan_499 row
-- 4) Gives every existing user at least 3,500 credits (via credit-guard bypass)
--
-- IMPORTANT: Never do bare `UPDATE users SET credits_balance = ...`
--            Trigger fn_protect_credits_balance blocks it.
--
-- Rollback: expire plan_499 rows manually or restore from backup/test project.

BEGIN;

-- Make sure plan_499 exists in the catalog.
INSERT INTO public.subscription_plans (
  id,
  name,
  tier,
  monthly_credits,
  price_inr_paise,
  platform,
  max_groups
)
VALUES ('plan_499', '₹499', 'mid', 3500, 49900, 'both', 3)
ON CONFLICT (id) DO UPDATE
SET monthly_credits = EXCLUDED.monthly_credits,
    price_inr_paise = EXCLUDED.price_inr_paise,
    platform = EXCLUDED.platform,
    max_groups = EXCLUDED.max_groups,
    active = true;

-- End other active plans so fn_user_plan_tier() sees only plan_499.
UPDATE public.user_subscriptions
SET status = 'expired',
    updated_at = now()
WHERE status IN ('active', 'grace_period')
  AND plan_id <> 'plan_499';

-- Refresh existing plan_499 subscriptions.
UPDATE public.user_subscriptions
SET status = 'active',
    platform = 'web',
    gateway = 'razorpay',
    current_period_start = now(),
    current_period_end = now() + interval '30 days',
    updated_at = now()
WHERE plan_id = 'plan_499';

-- Insert plan_499 for users missing an active plan_499.
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
FROM public.users u
WHERE NOT EXISTS (
  SELECT 1
  FROM public.user_subscriptions us
  WHERE us.user_id = u.id
    AND us.plan_id = 'plan_499'
    AND us.status = 'active'
    AND us.current_period_end > now()
);

-- Ensure enough smoke-test credits (bypass protect trigger — same as fn_grant_credits).
DO $$
DECLARE
  r RECORD;
  v_old INTEGER;
  v_new INTEGER;
BEGIN
  FOR r IN
    SELECT id, credits_balance
    FROM public.users
    WHERE credits_balance < 3500
  LOOP
    v_old := r.credits_balance;
    v_new := 3500;
    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE public.users
    SET credits_balance = v_new
    WHERE id = r.id;
    PERFORM set_config('app.allow_credit_change', 'false', true);
    INSERT INTO public.credit_transactions (user_id, amount, action, description)
    VALUES (r.id, v_new - v_old, 'admin_topup', 'Smoke test top-up to 3500 for plan_499');
  END LOOP;
END $$;

COMMIT;

-- Verify: every user should show plan_499 and >= 3500 credits.
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan_tier,
  u.credits_balance,
  us.current_period_end
FROM public.users u
LEFT JOIN public.user_subscriptions us
  ON us.user_id = u.id
 AND us.plan_id = 'plan_499'
 AND us.status = 'active'
ORDER BY u.email;
