-- SMOKE D — Subscription ENDING (expire active plan)
-- Email: soniabuddy73@gmail.com
-- Supabase → SQL Editor → Run alone
-- Use AFTER A/B/C smoke when you want to test “plan expired” locks.
-- Safe: only this email.

-- 0) Preview current plans
SELECT
  u.email,
  us.plan_id,
  us.status,
  us.current_period_start,
  us.current_period_end,
  public.fn_user_plan_tier(u.id) AS plan_tier_now
FROM public.users u
LEFT JOIN public.user_subscriptions us ON us.user_id = u.id
WHERE lower(u.email) = lower('soniabuddy73@gmail.com')
ORDER BY us.current_period_end DESC NULLS LAST;

-- 1) Expire ALL active / grace plans for this user
UPDATE public.user_subscriptions us
SET
  status = 'expired',
  current_period_end = now() - interval '1 hour',
  updated_at = now()
FROM public.users u
WHERE us.user_id = u.id
  AND lower(u.email) = lower('soniabuddy73@gmail.com')
  AND us.status IN ('active', 'grace_period');

-- 2) Optional: leave Free credits as-is (do not wipe balance here)
-- If you want Free feel with 50 credits, uncomment:
/*
DO $$
DECLARE r RECORD;
BEGIN
  SELECT id, credits_balance INTO r FROM public.users
  WHERE lower(email) = lower('soniabuddy73@gmail.com') LIMIT 1;
  IF r.id IS NOT NULL THEN
    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE public.users SET credits_balance = 50 WHERE id = r.id;
    PERFORM set_config('app.allow_credit_change', 'false', true);
  END IF;
END $$;
*/

-- 3) Verify — expect free / no active paid plan
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan_tier,
  u.credits_balance,
  us.plan_id,
  us.status,
  us.current_period_end
FROM public.users u
LEFT JOIN public.user_subscriptions us
  ON us.user_id = u.id
 AND us.status = 'active'
WHERE lower(u.email) = lower('soniabuddy73@gmail.com');
-- Expect: plan_tier ≈ free (or null paid), no active teacher/499 row

-- ROLLBACK tip: re-run FOUNDER_SMOKE_B_TEACHER_PLAN_SONIABUDDY73.sql
-- (or FOUNDER_MOCK_TEST_SONIABUDDY73.sql for plan_499)
