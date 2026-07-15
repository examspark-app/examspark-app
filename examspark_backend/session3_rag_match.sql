-- Session 3 Part A — match_rag_documents RPC for Ask AI (pgvector).
-- Safe to re-run. Founder: Supabase SQL Editor → paste → Run.
-- See FOUNDER_SQL_ORDER.md step C (after smoke_test_all_in_one.sql).

CREATE OR REPLACE FUNCTION public.match_rag_documents(
    p_user_id UUID,
    p_lecture_id UUID,
    p_query_embedding vector(1536),
    p_source_type TEXT,
    p_match_count INT DEFAULT 5,
    p_match_threshold FLOAT DEFAULT 0.55
)
RETURNS TABLE (
    id UUID,
    source_type TEXT,
    r2_chunk_path TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_source_type NOT IN ('notes', 'clean_transcript', 'teacher_shared') THEN
        RAISE EXCEPTION 'Invalid source_type: %', p_source_type;
    END IF;

    RETURN QUERY
    SELECT
        rd.id,
        rd.source_type,
        rd.r2_chunk_path,
        (1 - (rd.embedding <=> p_query_embedding))::FLOAT AS similarity
    FROM public.rag_documents rd
    WHERE rd.user_id = p_user_id
      AND rd.lecture_id = p_lecture_id
      AND rd.source_type = p_source_type
      AND rd.embedding IS NOT NULL
      AND (1 - (rd.embedding <=> p_query_embedding)) >= p_match_threshold
    ORDER BY rd.embedding <=> p_query_embedding
    LIMIT GREATEST(p_match_count, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_rag_documents(UUID, UUID, vector, TEXT, INT, FLOAT)
    TO service_role, authenticated;

-- Ensure service_role can write embeddings (smoke grants may already cover this).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rag_documents TO service_role;
