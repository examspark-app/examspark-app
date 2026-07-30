-- Phase 4C harden v2 — Knowledge versioning + stale tools
-- Safe to re-run. Run AFTER smoke if first Phase 4C SQL already done.

-- Parent link + version on master responses
ALTER TABLE home_ai_responses
    ADD COLUMN IF NOT EXISTS parent_response_id UUID
        REFERENCES home_ai_responses(id) ON DELETE SET NULL;

ALTER TABLE home_ai_responses
    ADD COLUMN IF NOT EXISTS knowledge_version INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_home_ai_responses_parent
    ON home_ai_responses (parent_response_id);

-- Allow stale status on tools (follow-up invalidated chips)
ALTER TABLE home_ai_tools DROP CONSTRAINT IF EXISTS home_ai_tools_status_check;
ALTER TABLE home_ai_tools
    ADD CONSTRAINT home_ai_tools_status_check
    CHECK (status IN ('generating', 'generated', 'failed', 'stale'));

SELECT 'phase4c_v2_ok' AS status;
