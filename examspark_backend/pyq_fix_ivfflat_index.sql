-- ExamSpark — FIX empty PYQ matches (Jul 18, 2026)
-- Root cause: IVFFlat on exam_pyqs with only ~12 rows often returns ZERO
-- neighbors (lists >> row count). Cosine in app is fine (~0.55); RPC empty.
--
-- Founder: Supabase → SQL Editor → paste ALL → Run
-- Then: restart backend, ask "photosynthesis" again (Related PYQ should show).

DROP INDEX IF EXISTS public.idx_exam_pyqs_embedding;

-- Optional later when bank is large (thousands of rows): recreate IVFFlat/HNSW.
-- For smoke bank (<1000 rows), sequential scan is correct and reliable.

-- Force match_exam_pyqs to ignore any leftover bad plans (safe re-create).
CREATE OR REPLACE FUNCTION public.match_exam_pyqs(
    p_query_embedding vector(1536),
    p_match_count INT DEFAULT 3,
    p_match_threshold FLOAT DEFAULT 0.45
)
RETURNS TABLE (
    id UUID,
    exam TEXT,
    year INTEGER,
    subject TEXT,
    chapter TEXT,
    weightage_stars INTEGER,
    similarity FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Small table: never use IVFFlat for this path.
    SET LOCAL enable_seqscan = on;
    SET LOCAL enable_indexscan = off;

    RETURN QUERY
    SELECT
        ep.id,
        ep.exam,
        ep.year,
        ep.subject,
        ep.chapter,
        ep.weightage_stars,
        (1 - (ep.embedding <=> p_query_embedding))::FLOAT AS similarity
    FROM public.exam_pyqs ep
    WHERE ep.embedding IS NOT NULL
      AND (1 - (ep.embedding <=> p_query_embedding)) >= p_match_threshold
    ORDER BY ep.embedding <=> p_query_embedding
    LIMIT GREATEST(p_match_count, 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.match_exam_pyqs(vector, INT, FLOAT)
    TO service_role, authenticated;

-- Verify: should return >= 1 row for a photosynthesis-like vector after app retest.
SELECT 'index_gone' AS k,
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_indexes
           WHERE schemaname = 'public' AND indexname = 'idx_exam_pyqs_embedding'
       ) THEN 'still_there' ELSE 'ok_dropped' END AS v;
