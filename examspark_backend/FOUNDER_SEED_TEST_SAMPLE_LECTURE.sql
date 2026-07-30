-- ExamSpark — Seed one dummy "completed" lecture for group-share smoke
-- (no mic / no Whisper / no Qwen3).
--
-- Supabase → SQL Editor → replace YOUR_EMAIL → Run
--
-- Creates:
--   lectures  status=done, source_type=recorded  (shareable to groups)
--   notes     sample summary + clean notes
--   extras    quiz (5 MCQ) + inline_transcript (Transcript tab without R2)
--
-- Title is always: TEST — Sample Lecture  (easy to find & delete)
--
-- Safe to re-run: deletes prior TEST rows for this user, then inserts fresh.

DO $$
DECLARE
  v_uid UUID;
  v_lecture_id UUID := gen_random_uuid();
  v_title TEXT := 'TEST — Sample Lecture';
BEGIN
  SELECT id INTO v_uid
  FROM auth.users
  WHERE lower(email) = lower('YOUR_EMAIL@gmail.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found — replace YOUR_EMAIL@gmail.com with your login email';
  END IF;

  -- Ensure public.users row exists (FK on lectures.user_id)
  INSERT INTO public.users (id, email)
  VALUES (v_uid, (SELECT email FROM auth.users WHERE id = v_uid))
  ON CONFLICT (id) DO NOTHING;

  -- Remove previous TEST lectures for this user (cascade notes/extras/transcripts)
  DELETE FROM public.lectures
  WHERE user_id = v_uid
    AND title = v_title;

  INSERT INTO public.lectures (
    id,
    user_id,
    title,
    subject,
    topic,
    status,
    error_message,
    source_type,
    created_at,
    updated_at,
    last_opened_at
  ) VALUES (
    v_lecture_id,
    v_uid,
    v_title,
    'Biology',
    'Photosynthesis (TEST DATA)',
    'done',
    NULL,
    'recorded',  -- required for Share to Group
    now(),
    now(),
    now()
  );

  INSERT INTO public.notes (
    lecture_id,
    clean_notes,
    short_summary,
    key_points,
    important_terms,
    visual_payload_json
  ) VALUES (
    v_lecture_id,
    $notes$
# Photosynthesis — TEST Sample Notes

**These notes are founder test data** (not from Whisper/Qwen3).
Safe to delete the lecture titled **TEST — Sample Lecture**.

## Overview
Photosynthesis is how green plants make food using sunlight, water, and carbon dioxide.

## Equation
`6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂` (light + chlorophyll)

## Light reaction
- Happens in thylakoid membranes
- Water splits → O₂ released
- ATP and NADPH formed

## Dark reaction (Calvin cycle)
- Happens in stroma
- CO₂ fixed into glucose using ATP + NADPH

## Why it matters (exam)
NEET / board questions often ask the equation, site of light vs dark reaction, and products.
$notes$,
    'TEST summary: Photosynthesis converts light energy into chemical energy (glucose) and releases oxygen. Light reaction in thylakoids; Calvin cycle in stroma.',
    jsonb_build_array(
      'Light reaction: thylakoid — O₂, ATP, NADPH',
      'Calvin cycle: stroma — glucose from CO₂',
      'Chlorophyll absorbs light',
      'Overall: CO₂ + H₂O → glucose + O₂'
    ),
    jsonb_build_array(
      'Photosynthesis',
      'Thylakoid',
      'Stroma',
      'Calvin cycle',
      'Chlorophyll',
      'ATP',
      'NADPH'
    ),
    jsonb_build_object(
      'graphs', '[]'::jsonb,
      'text_diagrams', jsonb_build_array(
        jsonb_build_object(
          'title', 'Photosynthesis (TEST diagram)',
          'content',
          E'Sunlight\n   ↓\nLeaf / Chlorophyll\n   ↓\nLight reaction (thylakoid) → O₂ + ATP + NADPH\n   ↓\nCalvin cycle (stroma) → Glucose'
        )
      ),
      'timelines', '[]'::jsonb,
      'hierarchy_trees', '[]'::jsonb,
      'process_flows', jsonb_build_array(
        jsonb_build_object(
          'title', 'Flow',
          'content', E'CO₂ + H₂O + light  →  glucose + O₂'
        )
      ),
      'highlight_boxes', jsonb_build_array(
        jsonb_build_object(
          'kind', 'important',
          'content', '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂'
        )
      ),
      'memory_tricks', jsonb_build_array(
        'Light reaction = thylakoid (roof); Calvin = stroma (room inside)'
      ),
      'exam_tips', jsonb_build_array(
        'Often asked: where light vs dark reaction occurs'
      ),
      'examples', '[]'::jsonb,
      'cheat_sheet', NULL
    )
  );

  -- Transcript without R2: backend reads extras.type = inline_transcript
  INSERT INTO public.extras (lecture_id, type, payload_json)
  VALUES (
    v_lecture_id,
    'inline_transcript',
    jsonb_build_object(
      'text',
      $tr$
[TEST TRANSCRIPT — not from Whisper]

Teacher: Today we study photosynthesis. Plants use sunlight, water, and carbon dioxide to make glucose and release oxygen.

Student: Where does the light reaction happen?
Teacher: In the thylakoid membranes of the chloroplast. Water splits and oxygen is released. ATP and NADPH are made.

Student: And the dark reaction?
Teacher: Also called the Calvin cycle, in the stroma. Carbon dioxide is fixed into sugar using ATP and NADPH.

Teacher: Remember the equation: six CO2 plus six H2O gives one glucose and six O2.

[END TEST TRANSCRIPT]
$tr$
    )
  );

  INSERT INTO public.extras (lecture_id, type, payload_json)
  VALUES (
    v_lecture_id,
    'quiz',
    jsonb_build_object(
      'questions',
      jsonb_build_array(
        jsonb_build_object(
          'question', 'Photosynthesis mainly produces which sugar?',
          'options', jsonb_build_array('Glucose', 'Fructose', 'Sucrose only', 'Lactose'),
          'correctAnswer', 'A',
          'explanation', 'TEST: Primary product written as glucose (C6H12O6).'
        ),
        jsonb_build_object(
          'question', 'Light reaction occurs in the:',
          'options', jsonb_build_array('Stroma', 'Thylakoid membrane', 'Cytoplasm', 'Mitochondria'),
          'correctAnswer', 'B',
          'explanation', 'TEST: Thylakoids hold photosystems.'
        ),
        jsonb_build_object(
          'question', 'Calvin cycle (dark reaction) occurs in the:',
          'options', jsonb_build_array('Thylakoid lumen', 'Stroma', 'Nucleus', 'Cell wall'),
          'correctAnswer', 'B',
          'explanation', 'TEST: Stroma is the site of CO2 fixation.'
        ),
        jsonb_build_object(
          'question', 'Which gas is released as a by-product of the light reaction?',
          'options', jsonb_build_array('Nitrogen', 'Carbon dioxide', 'Oxygen', 'Methane'),
          'correctAnswer', 'C',
          'explanation', 'TEST: Splitting of water releases O2.'
        ),
        jsonb_build_object(
          'question', 'Chlorophyll mainly absorbs light for:',
          'options', jsonb_build_array('Respiration only', 'Photosynthesis', 'Protein folding', 'DNA replication'),
          'correctAnswer', 'B',
          'explanation', 'TEST: Pigment that captures light energy.'
        )
      )
    )
  );

  -- Optional empty transcripts row (R2 paths null) — Workspace uses inline_transcript
  INSERT INTO public.transcripts (lecture_id)
  VALUES (v_lecture_id)
  ON CONFLICT (lecture_id) DO NOTHING;

  RAISE NOTICE 'OK — seeded lecture id=% title=% for user=%',
    v_lecture_id, v_title, v_uid;
END $$;

-- Verify
SELECT
  l.id,
  l.title,
  l.subject,
  l.status,
  l.source_type,
  (n.short_summary IS NOT NULL) AS has_notes,
  (SELECT count(*) FROM extras e WHERE e.lecture_id = l.id AND e.type = 'quiz') AS has_quiz,
  (SELECT count(*) FROM extras e WHERE e.lecture_id = l.id AND e.type = 'inline_transcript') AS has_inline_transcript
FROM lectures l
LEFT JOIN notes n ON n.lecture_id = l.id
WHERE l.title = 'TEST — Sample Lecture'
ORDER BY l.created_at DESC;

-- ---------- DELETE later (optional) ----------
-- Replace email, then run:
/*
DELETE FROM public.lectures
WHERE title = 'TEST — Sample Lecture'
  AND user_id = (
    SELECT id FROM auth.users WHERE lower(email) = lower('YOUR_EMAIL@gmail.com') LIMIT 1
  );
*/
