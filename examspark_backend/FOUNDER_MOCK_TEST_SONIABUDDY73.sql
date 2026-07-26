-- ExamSpark — AFTER signup: mock test pack for soniabuddy73@gmail.com ONLY
-- Run AFTER you deleted + signed up again (user must exist in auth.users).
-- Supabase → SQL Editor → Run all.
--
-- Gives: plan_499 (30 days) + credits >= 3500
-- Does NOT touch other accounts.

-- ========== 0) Must find user (1 row) ==========
SELECT id, email, created_at
FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');
-- 0 rows → signup pehle karo, phir ye SQL.

-- ========== 1) Ensure public.users row ==========
INSERT INTO public.users (id, email)
SELECT id, email
FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com')
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email;

-- ========== 2) Ensure plan_499 in catalog ==========
INSERT INTO public.subscription_plans (
  id, name, tier, monthly_credits, price_inr_paise, platform, max_groups
)
VALUES ('plan_499', '₹499', 'mid', 3500, 49900, 'both', 3)
ON CONFLICT (id) DO UPDATE
SET monthly_credits = EXCLUDED.monthly_credits,
    price_inr_paise = EXCLUDED.price_inr_paise,
    platform = EXCLUDED.platform,
    max_groups = EXCLUDED.max_groups,
    active = true;

-- ========== 3) Expire other active plans for THIS user ==========
UPDATE public.user_subscriptions us
SET status = 'expired',
    updated_at = now()
FROM public.users u
WHERE us.user_id = u.id
  AND lower(u.email) = lower('soniabuddy73@gmail.com')
  AND us.status IN ('active', 'grace_period')
  AND us.plan_id <> 'plan_499';

-- ========== 4) Activate / insert plan_499 ==========
UPDATE public.user_subscriptions us
SET status = 'active',
    platform = 'web',
    gateway = 'razorpay',
    current_period_start = now(),
    current_period_end = now() + interval '30 days',
    updated_at = now()
FROM public.users u
WHERE us.user_id = u.id
  AND lower(u.email) = lower('soniabuddy73@gmail.com')
  AND us.plan_id = 'plan_499';

INSERT INTO public.user_subscriptions (
  user_id, plan_id, status, platform, gateway,
  current_period_start, current_period_end
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
WHERE lower(u.email) = lower('soniabuddy73@gmail.com')
  AND NOT EXISTS (
    SELECT 1
    FROM public.user_subscriptions us
    WHERE us.user_id = u.id
      AND us.plan_id = 'plan_499'
      AND us.status = 'active'
      AND us.current_period_end > now()
  );

-- ========== 5) Credits → at least 3500 (guard-safe) ==========
DO $$
DECLARE
  r RECORD;
  v_old INTEGER;
  v_new INTEGER := 3500;
BEGIN
  SELECT id, credits_balance INTO r
  FROM public.users
  WHERE lower(email) = lower('soniabuddy73@gmail.com')
  LIMIT 1;

  IF r.id IS NULL THEN
    RAISE EXCEPTION 'public.users row missing for soniabuddy73@gmail.com';
  END IF;

  IF r.credits_balance < v_new THEN
    v_old := r.credits_balance;
    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE public.users
    SET credits_balance = v_new
    WHERE id = r.id;
    PERFORM set_config('app.allow_credit_change', 'false', true);
    INSERT INTO public.credit_transactions (user_id, amount, action, description)
    VALUES (
      r.id,
      v_new - v_old,
      'admin_topup',
      'Mock test top-up to 3500 (soniabuddy73)'
    );
  END IF;
END $$;

-- ========== 6) Verify (expect plan_499 + credits >= 3500) ==========
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan_tier,
  u.credits_balance,
  us.status,
  us.current_period_end
FROM public.users u
LEFT JOIN public.user_subscriptions us
  ON us.user_id = u.id
 AND us.plan_id = 'plan_499'
 AND us.status = 'active'
WHERE lower(u.email) = lower('soniabuddy73@gmail.com');
