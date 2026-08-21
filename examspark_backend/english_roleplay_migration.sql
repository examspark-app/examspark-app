-- English Teaching: persisted, user-scoped Roleplay sessions.
-- Run once in the Supabase SQL editor before enabling the roleplay API.
CREATE TABLE IF NOT EXISTS english_roleplay_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  scenario text NOT NULL,
  native_language text NOT NULL DEFAULT 'English',
  target_language text NOT NULL DEFAULT 'English',
  chat_session_id uuid REFERENCES public.english_practice_sessions(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds integer NOT NULL DEFAULT 0,
  credits_used integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS english_roleplay_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES english_roleplay_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user', 'assistant')),
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE english_roleplay_sessions
  ADD COLUMN IF NOT EXISTS target_language text NOT NULL DEFAULT 'English';
ALTER TABLE english_roleplay_sessions
  ADD COLUMN IF NOT EXISTS chat_session_id uuid REFERENCES public.english_practice_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_english_roleplay_sessions_user_updated ON english_roleplay_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_english_roleplay_sessions_chat_session ON english_roleplay_sessions(chat_session_id);
CREATE INDEX IF NOT EXISTS idx_english_roleplay_messages_session_created ON english_roleplay_messages(session_id, created_at);

ALTER TABLE english_roleplay_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE english_roleplay_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "english_roleplay_sessions_own" ON english_roleplay_sessions;
DROP POLICY IF EXISTS "english_roleplay_messages_own" ON english_roleplay_messages;

CREATE POLICY "english_roleplay_sessions_own" ON english_roleplay_sessions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "english_roleplay_messages_own" ON english_roleplay_messages FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
