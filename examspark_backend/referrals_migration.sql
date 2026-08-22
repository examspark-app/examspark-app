-- Refer & Earn: one-time 30-credit reward for the existing referrer.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS referral_code text;

UPDATE public.users
SET referral_code = upper(left(replace(id::text, '-', ''), 8))
WHERE referral_code IS NULL;

CREATE OR REPLACE FUNCTION public.assign_referral_code()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.referral_code IS NULL OR trim(NEW.referral_code) = '' THEN
    NEW.referral_code := upper(left(replace(NEW.id::text, '-', ''), 8));
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS users_assign_referral_code ON public.users;
CREATE TRIGGER users_assign_referral_code
  BEFORE INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.assign_referral_code();

CREATE UNIQUE INDEX IF NOT EXISTS users_referral_code_key
  ON public.users (referral_code)
  WHERE referral_code IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referred_user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  credits_given integer NOT NULL DEFAULT 30 CHECK (credits_given = 30),
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT referrals_not_self CHECK (referrer_id <> referred_user_id)
);

CREATE INDEX IF NOT EXISTS referrals_referrer_created_idx
  ON public.referrals (referrer_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.redeem_referral(p_referred_user_id uuid, p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_referrer uuid;
  v_referral_id uuid;
BEGIN
  SELECT id INTO v_referrer FROM users
  WHERE referral_code = upper(trim(p_code));
  IF v_referrer IS NULL OR v_referrer = p_referred_user_id THEN
    RETURN jsonb_build_object('status', 'rejected');
  END IF;
  INSERT INTO referrals(referrer_id, referred_user_id, referral_code)
  VALUES (v_referrer, p_referred_user_id, upper(trim(p_code)))
  ON CONFLICT (referred_user_id) DO NOTHING
  RETURNING id INTO v_referral_id;
  IF v_referral_id IS NULL THEN
    RETURN jsonb_build_object('status', 'already_processed');
  END IF;
  PERFORM fn_grant_credits(v_referrer, 30, 'Referral reward', 'referral_reward');
  RETURN jsonb_build_object('status', 'completed', 'referral_id', v_referral_id);
END; $$;

GRANT EXECUTE ON FUNCTION public.redeem_referral(uuid, text) TO service_role;