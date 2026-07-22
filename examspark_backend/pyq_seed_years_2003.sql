-- ExamSpark — Extra PYQ metadata years (incl. 2003) for smoke / year-related asks
-- Founder: Supabase SQL Editor → paste ALL → Run
-- THEN: python scripts/seed_pyq_embeddings.py  (only NULL embeddings get filled)
--
-- COPYRIGHT LOCK (PROJECT_CORE_RULES §6):
--   Postgres stores ONLY exam / year / subject / chapter / topic_label.
--   NEVER original exam question text, options, or official answers.
--   topic_label = short topic cue for embedding only (not a paper quote).

-- Ensure columns exist (safe if already ran pyq_exam_pyqs_migration.sql)
ALTER TABLE exam_pyqs
    ADD COLUMN IF NOT EXISTS topic_label TEXT;

-- Year-related smoke rows (idempotent on topic_label)
INSERT INTO exam_pyqs (exam, year, subject, chapter, weightage_stars, topic_label)
SELECT v.exam, v.year, v.subject, v.chapter, v.stars, v.topic
FROM (VALUES
    -- 2003 cluster (for "NEET 2003" / year-related asks)
    ('NEET', 2003, 'Biology', 'Human Physiology', 4,
     'NEET 2003 biology human heart chambers circulation physiology'),
    ('NEET', 2003, 'Biology', 'Plant Physiology', 4,
     'NEET 2003 biology photosynthesis light reaction plant physiology'),
    ('NEET', 2003, 'Chemistry', 'Chemical Bonding', 3,
     'NEET 2003 chemistry chemical bonding hybridization VBT'),
    ('JEE', 2003, 'Physics', 'Laws of Motion', 3,
     'JEE 2003 physics laws of motion Newton force friction'),
    -- a few other older years for variety
    ('NEET', 2010, 'Biology', 'Ecology', 3,
     'NEET 2010 biology ecology ecosystem food chain biodiversity'),
    ('NEET', 2015, 'Biology', 'Genetics', 4,
     'NEET 2015 biology genetics Mendel inheritance DNA')
) AS v(exam, year, subject, chapter, stars, topic)
WHERE NOT EXISTS (
    SELECT 1 FROM exam_pyqs e WHERE e.topic_label = v.topic
);

-- Verify
SELECT exam, year, subject, chapter,
       (embedding IS NOT NULL) AS has_embedding,
       left(topic_label, 60) AS topic_preview
FROM exam_pyqs
ORDER BY year ASC, exam, subject;
