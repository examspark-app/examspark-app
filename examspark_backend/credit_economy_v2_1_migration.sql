-- ExamSpark — Credit Economy v2.1 Migration (Founder-locked Jul 13, 2026)
-- Run this in Supabase SQL Editor AFTER schema.sql + all other migrations.
-- Safe to re-run (idempotent UPDATE/INSERT ... ON CONFLICT).
--
-- What this does:
-- 1. Free plan: 50 -> 75 credits/month (syncs DB to the Jul 12, 2026 doc-locked
--    value — code was out of sync with CREDIT_ECONOMY.md until now)
-- 2. plan_199: 1,300 -> 1,500 credits/month (Ask AI headroom — fee-corrected
--    margin calc showed room while staying ~50% EBITDA even under worst-case
--    Google Play 15% fee assumption)
-- 3. teacher: 20,000 -> 16,000 credits/month (60hr/month max-usage validation —
--    risk-ceiling tighten, NOT a margin change; real teacher AI cost stays
--    tiny either way, see CREDIT_ECONOMY.md)
-- 4. Seeds the credit_packs table (a-la-carte top-ups) — was empty before.
--    No teacher commission applies to these purchases.

UPDATE subscription_plans SET monthly_credits = 75 WHERE id = 'free';
UPDATE subscription_plans SET monthly_credits = 1500 WHERE id = 'plan_199';
UPDATE subscription_plans SET monthly_credits = 16000 WHERE id = 'teacher';

INSERT INTO credit_packs (id, name, credits, price_inr_paise) VALUES
    ('pack_100', '100 Credits', 100, 2500),
    ('pack_500', '500 Credits', 500, 11000),
    ('pack_1000', '1,000 Credits', 1000, 20000),
    ('pack_5000', '5,000 Credits', 5000, 85000),
    ('pack_10000', '10,000 Credits', 10000, 150000)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    credits = EXCLUDED.credits,
    price_inr_paise = EXCLUDED.price_inr_paise;

-- Verify (run after the above):
-- SELECT id, monthly_credits, price_inr_paise FROM subscription_plans ORDER BY price_inr_paise;
-- SELECT id, credits, price_inr_paise FROM credit_packs ORDER BY credits;
