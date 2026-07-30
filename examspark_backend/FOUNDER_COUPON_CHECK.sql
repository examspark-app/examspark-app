-- Quick check: coupon tables ready?
-- Supabase → SQL Editor → Run

SELECT to_regclass('public.teacher_coupons') AS teacher_coupons,
       to_regclass('public.coupon_redemptions') AS coupon_redemptions;

-- Expect: both non-null. If null → run teacher_coupon_migration.sql
-- Then: group_join_paths_architecture_migration.sql
