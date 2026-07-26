-- ONE-OFF: Delete account by user id (same email can sign up again)
-- User id: 4f618361-0b65-48d4-85db-ec36ef94a3ed
-- Run in Supabase → SQL Editor
-- WARNING: Permanently deletes this user's lectures, groups, credits, profiles.

-- ========== STEP 1 — Preview (safe, read-only) ==========
SELECT id, email, created_at, last_sign_in_at
FROM auth.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';

SELECT id, email, role, credits_balance, created_at
FROM public.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';

-- Agar Step 1 empty → wrong id / already gone. Stop.

-- ========== STEP 2 — Delete app data (cascades related rows) ==========
DELETE FROM public.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';

-- ========== STEP 3 — Delete Auth user (frees email for new signup) ==========
DELETE FROM auth.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';

-- ========== STEP 4 — Verify (both should return 0 rows) ==========
SELECT id, email FROM auth.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';

SELECT id, email FROM public.users
WHERE id = '4f618361-0b65-48d4-85db-ec36ef94a3ed';
