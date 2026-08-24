-- One-time feature selection screen shown after signup or signin.
-- Safe to run against an existing Supabase project.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS has_seen_onboarding BOOLEAN NOT NULL DEFAULT false;

-- Existing profiles that predate this column are first-run users for this flow.
UPDATE users
SET has_seen_onboarding = false
WHERE has_seen_onboarding IS NULL;
