-- GlowGuide research cache. Run after glow_guide_migration.sql.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS glow_guide_research_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key text NOT NULL UNIQUE,
  normalized_query text NOT NULL,
  topic_type text NOT NULL CHECK (topic_type IN ('current', 'science_ingredient')),
  title text,
  source_url text,
  content text NOT NULL,
  embedding vector(1536) NOT NULL,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_glow_guide_research_expiry
  ON glow_guide_research_documents (expires_at);

CREATE OR REPLACE FUNCTION match_glow_guide_research(
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id uuid, title text, source_url text, content text,
  similarity float, expires_at timestamptz
)
LANGUAGE sql STABLE AS $$
  SELECT d.id, d.title, d.source_url, d.content,
    1 - (d.embedding <=> query_embedding) AS similarity, d.expires_at
  FROM glow_guide_research_documents d
  WHERE d.expires_at > now()
    AND 1 - (d.embedding <=> query_embedding) >= match_threshold
  ORDER BY d.embedding <=> query_embedding
  LIMIT match_count;
$$;

ALTER TABLE glow_guide_research_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS glow_guide_research_read ON glow_guide_research_documents;
CREATE POLICY glow_guide_research_read ON glow_guide_research_documents
  FOR SELECT USING (true);