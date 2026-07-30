-- ExamSpark — Teacher plan price ₹1,999 → ₹2,999
-- Founder lock Jul 23, 2026 (Teacher Setup Gate save)
-- Supabase → SQL Editor → Run once

UPDATE subscription_plans
SET
  price_inr_paise = 299900,
  name = 'Teacher'
WHERE id = 'teacher';

-- Verify
SELECT id, name, monthly_credits, price_inr_paise, max_groups
FROM subscription_plans
WHERE id = 'teacher';
