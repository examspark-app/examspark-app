-- ExamSpark — Lecture duplicate detection (per-student)
-- Founder: Supabase → SQL Editor → paste ALL → Run
-- Layer 1: youtube_video_id / content_hash lookup
-- Layer 2: uses existing rag_documents (no new vectors table)

ALTER TABLE lectures
    ADD COLUMN IF NOT EXISTS content_hash TEXT;

ALTER TABLE lectures
    ADD COLUMN IF NOT EXISTS youtube_video_id TEXT;

ALTER TABLE lectures
    ADD COLUMN IF NOT EXISTS duplicate_of_lecture_id UUID
        REFERENCES lectures(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_lectures_user_content_hash
    ON lectures (user_id, content_hash)
    WHERE content_hash IS NOT NULL AND status = 'done';

CREATE INDEX IF NOT EXISTS idx_lectures_user_youtube_video
    ON lectures (user_id, youtube_video_id)
    WHERE youtube_video_id IS NOT NULL AND status = 'done';

CREATE INDEX IF NOT EXISTS idx_lectures_duplicate_of
    ON lectures (duplicate_of_lecture_id)
    WHERE duplicate_of_lecture_id IS NOT NULL;

-- Optional: near-duplicate transcript match helper (Layer 2)
CREATE OR REPLACE FUNCTION public.match_own_transcript_near_dup(
    p_user_id UUID,
    p_query_embedding vector(1536),
    p_exclude_lecture_id UUID DEFAULT NULL,
    p_match_threshold FLOAT DEFAULT 0.95,
    p_match_count INT DEFAULT 3
)
RETURNS TABLE (
    lecture_id UUID,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SET LOCAL enable_seqscan = on;
    RETURN QUERY
    SELECT
        rd.lecture_id,
        (1 - (rd.embedding <=> p_query_embedding))::FLOAT AS similarity
    FROM public.rag_documents rd
    WHERE rd.user_id = p_user_id
      AND rd.source_type = 'clean_transcript'
      AND rd.embedding IS NOT NULL
      AND rd.lecture_id IS NOT NULL
      AND (p_exclude_lecture_id IS NULL OR rd.lecture_id IS DISTINCT FROM p_exclude_lecture_id)
      AND (1 - (rd.embedding <=> p_query_embedding)) >= p_match_threshold
    ORDER BY rd.embedding <=> p_query_embedding
    LIMIT GREATEST(p_match_count, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_own_transcript_near_dup(
    UUID, vector, UUID, FLOAT, INT
) TO service_role, authenticated;

SELECT 'lectures_dedupe_cols' AS k,
       CASE WHEN EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'lectures'
             AND column_name = 'content_hash'
       ) THEN 'ok' ELSE 'missing' END AS v
UNION ALL
SELECT 'match_own_transcript_near_dup',
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'match_own_transcript_near_dup'
       ) THEN 'ok' ELSE 'missing' END;
