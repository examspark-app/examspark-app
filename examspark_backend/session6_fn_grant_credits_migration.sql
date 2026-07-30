-- Session 6 — grant credits after verified Razorpay payment.
-- Run once in Supabase SQL Editor (same project as schema.sql).
-- Bypasses trg_protect_credits_balance via app.allow_credit_change (same as fn_deduct_credits).

CREATE OR REPLACE FUNCTION fn_grant_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_description TEXT,
    p_action TEXT DEFAULT 'payment_grant'
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Grant amount must be positive';
    END IF;

    SELECT credits_balance INTO v_balance FROM users WHERE id = p_user_id FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'User % not found', p_user_id;
    END IF;

    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE users SET credits_balance = credits_balance + p_amount WHERE id = p_user_id;
    PERFORM set_config('app.allow_credit_change', 'false', true);

    INSERT INTO credit_transactions (user_id, amount, action, description, lecture_id)
    VALUES (p_user_id, p_amount, p_action, p_description, NULL);

    RETURN v_balance + p_amount;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_grant_credits(UUID, INTEGER, TEXT, TEXT) TO service_role;

COMMENT ON FUNCTION fn_grant_credits IS
  'Session 6: add credits after verified payment. Never call from Flutter (service_role / FastAPI only).';
