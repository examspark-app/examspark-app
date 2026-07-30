-- ============================================================================
-- ExamSpark — Teacher Dashboard & Groups Refinement Migration
-- Run ONCE in the Supabase SQL Editor (schema.sql already ran earlier).
--
-- Adds:
--   1. lectures.source_type — tracks HOW a lecture's content was captured
--      (real mic recording vs uploaded audio/document), so only real
--      recordings can be shared into a Group (fake-teacher prevention).
--   2. teacher_certificates.status — Pending Review / Verified / Rejected
--      state for the certificate upload UI (real AI check is Phase 5).
--   3. subscription_plans.max_groups — founder-locked group-join limits
--      per plan (₹199→1, ₹499→3, ₹999→6). Enforced client-side for now;
--      real server-side enforcement is Phase 5.
-- ============================================================================

-- ---- lectures: track capture method ----
ALTER TABLE lectures
    ADD COLUMN IF NOT EXISTS source_type TEXT NOT NULL DEFAULT 'recorded'
        CHECK (source_type IN ('recorded', 'uploaded_audio', 'uploaded_document'));

COMMENT ON COLUMN lectures.source_type IS
    'How this lecture''s audio/content was captured. Only source_type = ''recorded'' '
    'lectures can be shared into a Group — prevents a teacher account from '
    'uploading arbitrary PDFs/audio and passing it off as their own live teaching.';

-- ---- teacher_certificates: review status ----
ALTER TABLE teacher_certificates
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'verified', 'rejected'));

COMMENT ON COLUMN teacher_certificates.status IS
    'pending = awaiting review; verified/rejected will be set by the Phase 5 '
    'AI real/fake document check. Rejected certs show a "Contact Support" '
    'action in the Flutter UI instead of blocking the teacher outright.';

-- ---- subscription_plans: group-join limits (founder-locked) ----
ALTER TABLE subscription_plans
    ADD COLUMN IF NOT EXISTS max_groups INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN subscription_plans.max_groups IS
    'How many Groups a student on this plan may join at once. -1 = unlimited. '
    'Founder-locked Jul 2026: free=0, plan_199=1, plan_499=3, plan_999=6, teacher=-1.';

UPDATE subscription_plans SET max_groups = 0  WHERE id = 'free';
UPDATE subscription_plans SET max_groups = 1  WHERE id = 'plan_199';
UPDATE subscription_plans SET max_groups = 3  WHERE id = 'plan_499';
UPDATE subscription_plans SET max_groups = 6  WHERE id = 'plan_999';
UPDATE subscription_plans SET max_groups = -1 WHERE id = 'teacher';
