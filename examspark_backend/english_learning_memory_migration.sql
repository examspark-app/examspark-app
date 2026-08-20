-- Compact, user-owned learning facts for English Teaching only.
CREATE TABLE IF NOT EXISTS english_learning_memory (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  native_language text,
  target_language text,
  english_level text CHECK (english_level IN ('beginner', 'elementary', 'intermediate', 'advanced')),
  learner_name text,
  recurring_mistakes jsonb NOT NULL DEFAULT '[]'::jsonb,
  struggle_patterns jsonb NOT NULL DEFAULT '[]'::jsonb,
  practiced_topics jsonb NOT NULL DEFAULT '[]'::jsonb,
  learning_preferences jsonb NOT NULL DEFAULT '[]'::jsonb,
  recent_roleplay_scenarios jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE english_learning_memory ADD COLUMN IF NOT EXISTS learner_name text;
ALTER TABLE english_learning_memory ADD COLUMN IF NOT EXISTS target_language text;

ALTER TABLE english_learning_memory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "english_learning_memory_own" ON english_learning_memory
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
