-- New accounts start with 25 credits; completing the full student profile
-- grants the remaining 25 exactly once. Existing balances are unchanged.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS profile_setup_bonus_claimed boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
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
    25
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), users.full_name);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_profile_setup_bonus(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_claimed boolean;
  v_balance integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not allowed';
  END IF;
  SELECT profile_setup_bonus_claimed INTO v_claimed
  FROM users WHERE id = p_user_id FOR UPDATE;
  IF v_claimed IS NULL THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;
  IF v_claimed THEN
    RETURN jsonb_build_object('status', 'already_claimed');
  END IF;
  UPDATE users SET profile_setup_bonus_claimed = true WHERE id = p_user_id;
  v_balance := fn_grant_credits(
    p_user_id, 25, 'Full profile setup bonus', 'profile_setup_bonus'
  );
  RETURN jsonb_build_object('status', 'completed', 'balance', v_balance);
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_profile_setup_bonus(uuid) TO authenticated;