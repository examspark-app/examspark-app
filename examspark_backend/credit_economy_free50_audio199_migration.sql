-- Credit economy v2.2 — Free 50 + signup default 50 + audio @ plan_199
-- Founder Jul 15, 2026. Safe to re-run.
-- WHY new users still got 75: public.handle_new_user() in the LIVE DB
-- still inserted 75 (from an older smoke/bootstrap run). subscription_plans
-- alone does NOT set the signup grant — this function does.

-- 1) Free plan catalog
UPDATE subscription_plans
SET monthly_credits = 50
WHERE id = 'free';

-- 2) Signup trigger — new auth users get 50 credits (not 75)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, role, credits_balance)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name',
            split_part(COALESCE(NEW.email, ''), '@', 1)
        ),
        'student',
        50
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), users.full_name);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Verify:
-- SELECT monthly_credits FROM subscription_plans WHERE id = 'free';  -- 50
-- SELECT pg_get_functiondef('public.handle_new_user()'::regprocedure);
--   (should show credits_balance ... 50)
