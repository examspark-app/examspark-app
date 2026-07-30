-- ExamSpark — User-wide RAG match (weighted cross-lecture Ask AI)
-- Founder: Supabase → SQL Editor → paste ALL → Run
-- Safe to re-run. Does NOT drop match_rag_documents (single-lecture still used).

CREATE OR REPLACE FUNCTION public.match_rag_documents_user(
    p_user_id UUID,
    p_query_embedding vector(1536),
    p_source_type TEXT,
    p_only_lecture_id UUID DEFAULT NULL,
    p_exclude_lecture_id UUID DEFAULT NULL,
    p_match_count INT DEFAULT 5,
    p_match_threshold FLOAT DEFAULT 0.55
)
RETURNS TABLE (
    id UUID,
    lecture_id UUID,
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

    -- Small bank / updates: prefer sequential over broken IVFFlat probes.
    SET LOCAL enable_seqscan = on;

    RETURN QUERY
    SELECT
        rd.id,
        rd.lecture_id,
        rd.source_type,
        rd.r2_chunk_path,
        (1 - (rd.embedding <=> p_query_embedding))::FLOAT AS similarity
    FROM public.rag_documents rd
    WHERE rd.user_id = p_user_id
      AND rd.source_type = p_source_type
      AND rd.embedding IS NOT NULL
      AND (p_only_lecture_id IS NULL OR rd.lecture_id = p_only_lecture_id)
      AND (p_exclude_lecture_id IS NULL OR rd.lecture_id IS DISTINCT FROM p_exclude_lecture_id)
      AND (1 - (rd.embedding <=> p_query_embedding)) >= p_match_threshold
    ORDER BY rd.embedding <=> p_query_embedding
    LIMIT GREATEST(p_match_count, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_rag_documents_user(
    UUID, vector, TEXT, UUID, UUID, INT, FLOAT
) TO service_role, authenticated;

GRANT SELECT ON public.rag_documents TO service_role;

SELECT 'match_rag_documents_user' AS k,
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'match_rag_documents_user'
       ) THEN 'ok' ELSE 'missing' END AS v;
