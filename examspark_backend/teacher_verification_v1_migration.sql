-- ExamSpark — Teacher Verification v1 (AI Soft + Tavily institution soft-check)
-- Founder lock Jul 23, 2026 — TEACHER_PLATFORM.md §1c
-- Supabase → SQL Editor → Run once

-- Profile-level verification outcome
ALTER TABLE teacher_profiles
    ADD COLUMN IF NOT EXISTS verification_score NUMERIC,
    ADD COLUMN IF NOT EXISTS verification_date TIMESTAMPTZ;

COMMENT ON COLUMN teacher_profiles.verification_score IS
  'AI soft confidence 0-100. Trusted badge when >= 90 and verification_status=verified.';
COMMENT ON COLUMN teacher_profiles.verification_date IS
  'When soft AI verification last completed.';

-- Per-certificate soft verify metadata
ALTER TABLE teacher_certificates
    ADD COLUMN IF NOT EXISTS certificate_type TEXT,
    ADD COLUMN IF NOT EXISTS certificate_subject TEXT,
    ADD COLUMN IF NOT EXISTS certificate_hash TEXT,
    ADD COLUMN IF NOT EXISTS verification_score NUMERIC,
    ADD COLUMN IF NOT EXISTS verification_date TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_teacher_certificates_hash
    ON teacher_certificates (certificate_hash)
    WHERE certificate_hash IS NOT NULL;

COMMENT ON COLUMN teacher_certificates.certificate_hash IS
  'SHA-256 of image bytes — duplicate detection across teachers.';

-- Verify
SELECT column_name
FROM information_schema.columns
WHERE table_name IN ('teacher_profiles', 'teacher_certificates')
  AND column_name IN (
    'verification_score', 'verification_date',
    'certificate_type', 'certificate_subject', 'certificate_hash'
  )
ORDER BY table_name, column_name;
