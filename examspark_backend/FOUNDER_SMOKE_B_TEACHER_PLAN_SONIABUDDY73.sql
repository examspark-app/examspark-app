-- SMOKE B — Mock subscription buy (Teacher plan ₹2,999)
-- Email: soniabuddy73@gmail.com
-- Supabase → SQL Editor → Run alone
-- For Create Group / Record / Share smoke (Teacher plan gate).
-- Skips real Razorpay — marks plan active + credits.

-- 0) User
SELECT id, email FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com');

INSERT INTO public.users (id, email, role, onboarding_completed)
SELECT id, email, 'teacher', true
FROM auth.users
WHERE lower(email) = lower('soniabuddy73@gmail.com')
ON CONFLICT (id) DO UPDATE
SET role = 'teacher',
    onboarding_completed = true,
    email = EXCLUDED.email;

-- 1) Ensure teacher plan in catalog
INSERT INTO public.subscription_plans (
  id, name, tier, monthly_credits, price_inr_paise, platform, max_groups
)
VALUES ('teacher', 'Teacher', 'teacher', 16000, 299900, 'both', -1)
ON CONFLICT (id) DO UPDATE
SET monthly_credits = EXCLUDED.monthly_credits,
    price_inr_paise = EXCLUDED.price_inr_paise,
    platform = EXCLUDED.platform,
    max_groups = EXCLUDED.max_groups,
    active = true,
    name = EXCLUDED.name;

-- 2) Expire other active plans for THIS user only
UPDATE public.user_subscriptions us
SET status = 'expired',
    updated_at = now()
FROM public.users u
WHERE us.user_id = u.id
  AND lower(u.email) = lower('soniabuddy73@gmail.com')
  AND us.status IN ('active', 'grace_period')
  AND us.plan_id <> 'teacher';

-- 3) Activate / insert teacher plan (30 days)
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
  AND us.plan_id = 'teacher';

INSERT INTO public.user_subscriptions (
  user_id, plan_id, status, platform, gateway,
  current_period_start, current_period_end
)
SELECT
  u.id,
  'teacher',
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
      AND us.plan_id = 'teacher'
      AND us.status = 'active'
      AND us.current_period_end > now()
  );

-- 4) Credits ≥ 16000 (guard-safe)
DO $$
DECLARE
  r RECORD;
  v_old INTEGER;
  v_new INTEGER := 16000;
BEGIN
  SELECT id, credits_balance INTO r
  FROM public.users
  WHERE lower(email) = lower('soniabuddy73@gmail.com')
  LIMIT 1;

  IF r.id IS NULL THEN
    RAISE EXCEPTION 'public.users missing for soniabuddy73@gmail.com';
  END IF;

  IF r.credits_balance < v_new THEN
    v_old := r.credits_balance;
    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE public.users SET credits_balance = v_new WHERE id = r.id;
    PERFORM set_config('app.allow_credit_change', 'false', true);
    INSERT INTO public.credit_transactions (user_id, amount, action, description)
    VALUES (
      r.id,
      v_new - v_old,
      'admin_topup',
      'Smoke B Teacher plan mock top-up 16000'
    );
  END IF;
END $$;

-- 5) Verify
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan_tier,
  u.credits_balance,
  us.status,
  us.current_period_end
FROM public.users u
LEFT JOIN public.user_subscriptions us
  ON us.user_id = u.id
 AND us.plan_id = 'teacher'
 AND us.status = 'active'
WHERE lower(u.email) = lower('soniabuddy73@gmail.com');
-- Expect: plan_tier=teacher, credits>=16000, status=active
