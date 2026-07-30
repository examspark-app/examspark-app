-- ExamSpark — cleanup: one active plan_499 per user
-- Why duplicates? Verify query LEFT JOINs subscriptions.
-- If a user has 2 active plan_499 rows → email appears twice.
-- Credits / plan_tier are still correct (both rows same).
--
-- Run in Supabase SQL Editor (postgres). Safe for smoke testing.

-- Keep the newest active plan_499; expire older duplicates.
WITH ranked AS (
  SELECT
    id,
    user_id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY current_period_end DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM public.user_subscriptions
  WHERE plan_id = 'plan_499'
    AND status = 'active'
)
UPDATE public.user_subscriptions us
SET status = 'expired',
    updated_at = now()
FROM ranked r
WHERE us.id = r.id
  AND r.rn > 1;

-- Verify: one row per email
SELECT
  u.email,
  public.fn_user_plan_tier(u.id) AS plan_tier,
  u.credits_balance,
  us.current_period_end,
  (
    SELECT count(*)
    FROM public.user_subscriptions x
    WHERE x.user_id = u.id
      AND x.plan_id = 'plan_499'
      AND x.status = 'active'
  ) AS active_plan_499_count
FROM public.users u
LEFT JOIN LATERAL (
  SELECT current_period_end
  FROM public.user_subscriptions
  WHERE user_id = u.id
    AND plan_id = 'plan_499'
    AND status = 'active'
  ORDER BY current_period_end DESC
  LIMIT 1
) us ON true
ORDER BY u.email;

-- Expect: each email once, active_plan_499_count = 1, credits >= 3500, plan_tier = plan_499
