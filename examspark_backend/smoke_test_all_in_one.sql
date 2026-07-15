-- ============================================================================
-- ExamSpark — SMOKE TEST SETUP (run ONCE in Supabase SQL Editor)
-- Copy ALL of this file → Supabase Dashboard → SQL Editor → New query → Run
--
-- Fixes in one shot:
--   1. Permission denied 42501 (missing table GRANTs)
--   2. Auth user → public.users row (trigger + backfill)
--   3. Test plan plan_499 with required platform + gateway columns
--   4. Realtime not enabled on `lectures` (fixes "Network problem — failed to
--      connect to the server" on the Processing screen — that error is from
--      the Realtime stream, NOT from FastAPI/uvicorn)
--   5. Adds `error_message` column so real backend failure reasons show on
--      screen instead of a generic "network problem" message
--   (Credits: default 75 on signup is enough — do NOT direct UPDATE credits_balance)
--
-- Safe to re-run (idempotent where possible).
-- ============================================================================

-- ── STEP 1: PostgREST table privileges (fixes record/upload 42501 errors) ──
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

GRANT SELECT ON public.subscription_plans TO anon, authenticated;
GRANT SELECT ON public.credit_packs TO anon, authenticated;

-- Future tables get same privileges automatically
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;

-- ── STEP 1B: Enable Realtime for `lectures` ──
-- ProcessingScreen (examspark_frontend/lib/presentation/screens/recording/
-- processing_screen.dart) subscribes with supabase.from('lectures').stream()
-- to auto-advance the progress UI as status changes (splitting → transcribing →
-- done). If Realtime replication isn't ON for this table, that subscription's
-- onError fires immediately and shows "Network problem — failed to connect to
-- the server" — even when the backend is completely healthy. Idempotent: only
-- adds the table if it isn't already in the publication.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'lectures'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.lectures;
    END IF;
END $$;

-- ── STEP 1C: `error_message` column on `lectures` ──
-- FastAPI (lecture_service.py _db_set_status) now writes the real pipeline
-- failure reason here whenever status = 'error' (e.g. "cannot identify image
-- file", "little extractable text — likely a scan"). ProcessingScreen reads
-- this via Realtime and shows it verbatim instead of a generic "network
-- problem" message. Safe to re-run — no-ops if the column already exists.
ALTER TABLE public.lectures ADD COLUMN IF NOT EXISTS error_message TEXT;

-- ── STEP 2: Auto-create public.users when someone signs up ──
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
        75
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

-- Backfill: auth users who signed up BEFORE trigger existed
INSERT INTO public.users (id, email, full_name, role, credits_balance)
SELECT
    au.id,
    COALESCE(au.email, ''),
    COALESCE(
        au.raw_user_meta_data->>'full_name',
        au.raw_user_meta_data->>'name',
        split_part(COALESCE(au.email, ''), '@', 1)
    ),
    'student',
    75
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
WHERE pu.id IS NULL;

-- ── STEP 3: Give every user plan_499 for smoke testing (30 days) ──
-- platform + gateway are REQUIRED (NOT NULL) — old scripts missed these.
UPDATE user_subscriptions
SET
    plan_id = 'plan_499',
    status = 'active',
    platform = 'web',
    gateway = 'razorpay',
    current_period_start = now(),
    current_period_end = now() + interval '30 days',
    updated_at = now()
WHERE status IN ('pending', 'active', 'expired', 'cancelled', 'grace_period');

INSERT INTO user_subscriptions (
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
WHERE NOT EXISTS (
    SELECT 1 FROM user_subscriptions us WHERE us.user_id = u.id
);

-- Credits: DO NOT direct UPDATE — trigger blocks it.
-- Default 75 on signup is enough for smoke test (JPG=25 credits, short record=40).
-- Optional top-up ONLY if balance is low (uses same bypass as fn_deduct_credits):
/*
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT id, credits_balance FROM public.users WHERE credits_balance < 100 LOOP
        PERFORM set_config('app.allow_credit_change', 'true', true);
        UPDATE public.users SET credits_balance = 500 WHERE id = r.id;
        PERFORM set_config('app.allow_credit_change', 'false', true);
        INSERT INTO credit_transactions (user_id, amount, action, description)
        VALUES (r.id, 500 - r.credits_balance, 'admin_topup', 'Smoke test top-up');
    END LOOP;
END $$;
*/

-- ── STEP 4: VERIFY (read results — all should look OK) ──

-- 4a. Grants exist (should show many rows)
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('authenticated', 'service_role')
  AND table_name IN ('lectures', 'group_shared_items', 'user_subscriptions', 'users')
ORDER BY table_name, grantee;

-- 4b. Your users + plan (should show plan_499 active)
SELECT u.email, u.credits_balance, us.plan_id, us.status, us.platform, us.current_period_end
FROM public.users u
LEFT JOIN user_subscriptions us ON us.user_id = u.id
ORDER BY u.created_at DESC
LIMIT 5;

-- 4c. Realtime enabled on lectures? (should return exactly 1 row)
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime' AND tablename = 'lectures';
