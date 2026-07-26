-- Fix Teacher mock buy: balance was +50 only; should be 16,000 monthly.
-- Supabase → SQL Editor → replace YOUR_EMAIL → Run
-- Safe: grants only the missing amount up to 16000 (does not stack forever).

DO $$
DECLARE
  v_uid UUID;
  v_bal INTEGER;
  v_need INTEGER;
BEGIN
  SELECT id INTO v_uid
  FROM auth.users
  WHERE lower(email) = lower('YOUR_EMAIL@gmail.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found — check email';
  END IF;

  SELECT COALESCE(credits_balance, 0) INTO v_bal
  FROM public.users
  WHERE id = v_uid;

  v_need := 16000 - v_bal;
  IF v_need <= 0 THEN
    RAISE NOTICE 'Already >= 16000 (balance=%) — no grant', v_bal;
    RETURN;
  END IF;

  PERFORM public.fn_grant_credits(
    v_uid,
    v_need,
    '[manual] Top-up Teacher plan monthly credits after mock +50 bug',
    'mock_teacher_credit_fix'
  );

  RAISE NOTICE 'Granted % credits. New target balance ~16000 (was %)', v_need, v_bal;
END $$;

-- Verify
SELECT u.email, pu.credits_balance, us.plan_id, us.status
FROM auth.users u
JOIN public.users pu ON pu.id = u.id
LEFT JOIN LATERAL (
  SELECT plan_id, status
  FROM public.user_subscriptions
  WHERE user_id = u.id AND status = 'active'
  ORDER BY current_period_end DESC
  LIMIT 1
) us ON true
WHERE lower(u.email) = lower('YOUR_EMAIL@gmail.com');
