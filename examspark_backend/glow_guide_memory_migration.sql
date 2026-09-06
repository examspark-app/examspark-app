-- Additive GlowGuide memory and structured product-result persistence.
-- Run once in Supabase SQL Editor after glow_guide_migration.sql.

CREATE TABLE IF NOT EXISTS glow_guide_user_profiles (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  profile_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE glow_guide_messages
  ADD COLUMN IF NOT EXISTS analysis_json jsonb;

CREATE INDEX IF NOT EXISTS idx_glow_guide_user_profiles_updated
  ON glow_guide_user_profiles(updated_at DESC);

ALTER TABLE glow_guide_user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS glow_guide_user_profiles_own ON glow_guide_user_profiles;
CREATE POLICY glow_guide_user_profiles_own
  ON glow_guide_user_profiles
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
