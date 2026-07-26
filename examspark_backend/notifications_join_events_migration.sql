-- ExamSpark — Notifications join-approval events (optional event_type)
-- Run ONCE in Supabase SQL Editor (safe IF NOT EXISTS).
-- Used by: pending / accept / reject in-app + FCM deep links.

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS event_type TEXT;

COMMENT ON COLUMN notifications.event_type IS
  'group_post | join_pending_student | join_pending_teacher | join_accepted | join_rejected';

-- Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
  AND column_name = 'event_type';
