-- GlowGuide isolated sessions and messages. Run once in Supabase SQL editor.
CREATE TABLE IF NOT EXISTS glow_guide_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  category_type text CHECK (category_type IN ('skin', 'body', 'baby', 'cloth')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS glow_guide_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.glow_guide_sessions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user', 'assistant')),
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_glow_guide_sessions_user_updated ON glow_guide_sessions(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_glow_guide_messages_session_created ON glow_guide_messages(session_id, created_at ASC);
ALTER TABLE glow_guide_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE glow_guide_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS glow_guide_sessions_own ON glow_guide_sessions;
CREATE POLICY glow_guide_sessions_own ON glow_guide_sessions FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS glow_guide_messages_own ON glow_guide_messages;
CREATE POLICY glow_guide_messages_own ON glow_guide_messages FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
