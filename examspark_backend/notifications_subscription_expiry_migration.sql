-- ExamSpark — Subscription expiry alert dedupe (Notifications A2)
-- Run ONCE in Supabase SQL Editor.
-- Prevents duplicate 7d / 3d / 1d / expired pushes for the same period.

CREATE TABLE IF NOT EXISTS subscription_expiry_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_id UUID NOT NULL REFERENCES user_subscriptions(id) ON DELETE CASCADE,
    alert_kind TEXT NOT NULL
        CHECK (alert_kind IN ('expiring_7d', 'expiring_3d', 'expiring_1d', 'expired')),
    period_end DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT subscription_expiry_alerts_unique
        UNIQUE (subscription_id, alert_kind, period_end)
);

CREATE INDEX IF NOT EXISTS idx_subscription_expiry_alerts_user
    ON subscription_expiry_alerts (user_id, created_at DESC);

ALTER TABLE subscription_expiry_alerts ENABLE ROW LEVEL SECURITY;

-- App users do not read/write this table directly — FastAPI service_role only.
DROP POLICY IF EXISTS "subscription_expiry_alerts_deny_all" ON subscription_expiry_alerts;
CREATE POLICY "subscription_expiry_alerts_deny_all"
    ON subscription_expiry_alerts
    FOR ALL
    USING (false)
    WITH CHECK (false);

GRANT ALL ON subscription_expiry_alerts TO service_role;

-- Verify
SELECT 'subscription_expiry_alerts' AS tbl, COUNT(*) AS cols
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'subscription_expiry_alerts';
