-- ============================================================================
-- ExamSpark — Student Onboarding Migration
-- Run ONCE in the Supabase SQL Editor (schema.sql already ran earlier).
-- Adds: users.username / avatar_color / onboarding_completed, and a new
-- student_profiles table (age, education level, subjects) — mirrors the
-- existing teacher_profiles pattern. Teachers already have their profile
-- flow inside Teacher Dashboard, so they are marked onboarded immediately.
-- ============================================================================

-- ---- users: new profile columns ----
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS avatar_color TEXT,
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT false;

-- Teachers already manage their profile from the Teacher Dashboard — never
-- show them the student onboarding screen.
UPDATE users SET onboarding_completed = true WHERE role = 'teacher';

-- ---- student_profiles (age / education / subjects) ----
-- Metadata only, matches DATABASE STORAGE RULE — no large content here.
CREATE TABLE IF NOT EXISTS student_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    age INTEGER CHECK (age IS NULL OR (age >= 5 AND age <= 100)),
    education_level TEXT,
    subjects TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_student_profiles_user_id ON student_profiles(user_id);

ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_profiles_select_own" ON student_profiles;
CREATE POLICY "student_profiles_select_own" ON student_profiles FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "student_profiles_insert_own" ON student_profiles;
CREATE POLICY "student_profiles_insert_own" ON student_profiles FOR INSERT
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "student_profiles_update_own" ON student_profiles;
CREATE POLICY "student_profiles_update_own" ON student_profiles FOR UPDATE
    USING (user_id = auth.uid());
