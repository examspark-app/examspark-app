-- ExamSpark — PYQ metadata bank (start PYQs)
-- Founder: Supabase SQL Editor → paste ALL → Run
-- Safe to re-run (IF NOT EXISTS / CREATE OR REPLACE).
-- Copyright: metadata tags only — never store original Q/options/answer in Postgres.
-- Embeddings: run Python seed AFTER this SQL (see FOUNDER_START_PYQS.md).

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS exam_pyqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam TEXT NOT NULL CHECK (exam IN ('NEET', 'JEE', 'CBSE', 'UPSC')),
    year INTEGER NOT NULL,
    subject TEXT NOT NULL,
    chapter TEXT NOT NULL,
    weightage_stars INTEGER NOT NULL DEFAULT 3
        CHECK (weightage_stars >= 1 AND weightage_stars <= 5),
    r2_path TEXT,
    -- Text used ONLY to build embeddings (topic cue — not an exam paper quote).
    topic_label TEXT,
    embedding vector(1536),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE exam_pyqs
    ADD COLUMN IF NOT EXISTS topic_label TEXT;

ALTER TABLE exam_pyqs
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_exam_pyqs_exam_year
    ON exam_pyqs (exam, year);

CREATE INDEX IF NOT EXISTS idx_exam_pyqs_subject_chapter
    ON exam_pyqs (subject, chapter);

-- Do NOT create IVFFlat on the smoke bank (<1000 rows). lists >> row count
-- made match_exam_pyqs return ZERO neighbors (founder Jul 18). Sequential
-- scan + Python local-scan fallback are correct until the bank is large.
DROP INDEX IF EXISTS public.idx_exam_pyqs_embedding;

-- Seed metadata rows (no embeddings yet — topic_label only). Idempotent on topic_label.
INSERT INTO exam_pyqs (exam, year, subject, chapter, weightage_stars, topic_label)
SELECT v.exam, v.year, v.subject, v.chapter, v.stars, v.topic
FROM (VALUES
    ('NEET', 2024, 'Biology', 'Body Fluids and Circulation', 5,
     'human heart chambers atria ventricles circulation NEET biology'),
    ('NEET', 2023, 'Biology', 'Photosynthesis in Higher Plants', 5,
     'photosynthesis light reaction Calvin cycle chloroplast NEET biology'),
    ('NEET', 2022, 'Biology', 'Digestion and Absorption', 4,
     'human digestive system stomach enzymes absorption NEET biology'),
    ('JEE', 2024, 'Physics', 'Motion in a Plane', 4,
     'projectile motion kinematics trajectory JEE physics'),
    ('JEE', 2023, 'Chemistry', 'Equilibrium', 4,
     'chemical equilibrium Le Chatelier principle Kc JEE chemistry'),
    ('CBSE', 2023, 'Biology', 'Life Processes', 3,
     'human heart pumping blood double circulation CBSE class 10 biology')
) AS v(exam, year, subject, chapter, stars, topic)
WHERE NOT EXISTS (
    SELECT 1 FROM exam_pyqs e WHERE e.topic_label = v.topic
);

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

GRANT SELECT, INSERT, UPDATE, DELETE ON public.exam_pyqs TO service_role;

-- Verify
SELECT 'exam_pyqs_rows' AS k, COUNT(*)::TEXT AS v FROM exam_pyqs
UNION ALL
SELECT 'with_embedding', COUNT(*)::TEXT FROM exam_pyqs WHERE embedding IS NOT NULL
UNION ALL
SELECT 'match_fn',
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'match_exam_pyqs'
       ) THEN 'ok' ELSE 'missing' END;
