-- SMOKE C — TEST Sample Lecture (text notes, no mic)
-- Email: soniabuddy73@gmail.com
-- Supabase → SQL Editor → Run alone
-- Creates: TEST — Sample Lecture (done) + notes + quiz + inline transcript

DO $$
DECLARE
  v_uid UUID;
  v_lecture_id UUID := gen_random_uuid();
  v_title TEXT := 'TEST — Sample Lecture';
BEGIN
  SELECT id INTO v_uid
  FROM auth.users
  WHERE lower(email) = lower('soniabuddy73@gmail.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'User not found — signup soniabuddy73@gmail.com first';
  END IF;

  INSERT INTO public.users (id, email)
  VALUES (v_uid, (SELECT email FROM auth.users WHERE id = v_uid))
  ON CONFLICT (id) DO NOTHING;

  DELETE FROM public.lectures
  WHERE user_id = v_uid
    AND title = v_title;

  INSERT INTO public.lectures (
    id, user_id, title, subject, topic, status, error_message,
    source_type, created_at, updated_at, last_opened_at
  ) VALUES (
    v_lecture_id,
    v_uid,
    v_title,
    'Biology',
    'Photosynthesis (TEST DATA)',
    'done',
    NULL,
    'recorded',
    now(),
    now(),
    now()
  );

  INSERT INTO public.notes (
    lecture_id, clean_notes, short_summary, key_points, important_terms, visual_payload_json
  ) VALUES (
    v_lecture_id,
    $notes$
# Photosynthesis — TEST Sample Notes

**Founder test data** (not from Whisper/Qwen3).

## Overview
Photosynthesis is how green plants make food using sunlight, water, and carbon dioxide.

## Equation
`6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂` (light + chlorophyll)

## Light reaction
- Thylakoid membranes
- Water splits → O₂
- ATP and NADPH formed

## Dark reaction (Calvin cycle)
- Stroma
- CO₂ fixed into glucose
$notes$,
    'TEST: Photosynthesis makes glucose + O₂. Light reaction in thylakoids; Calvin in stroma.',
    jsonb_build_array(
      'Light reaction: thylakoid — O₂, ATP, NADPH',
      'Calvin cycle: stroma — glucose',
      'Chlorophyll absorbs light'
    ),
    jsonb_build_array('Photosynthesis', 'Thylakoid', 'Stroma', 'Calvin cycle', 'Chlorophyll'),
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

  INSERT INTO public.extras (lecture_id, type, payload_json)
  VALUES (
    v_lecture_id,
    'inline_transcript',
    jsonb_build_object(
      'text',
      $tr$
[TEST TRANSCRIPT]
Teacher: Photosynthesis uses sunlight, water, and CO2 to make glucose and oxygen.
Light reaction in thylakoids; Calvin cycle in stroma.
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
          'explanation', 'TEST: glucose'
        ),
        jsonb_build_object(
          'question', 'Light reaction occurs in the:',
          'options', jsonb_build_array('Stroma', 'Thylakoid membrane', 'Cytoplasm', 'Mitochondria'),
          'correctAnswer', 'B',
          'explanation', 'TEST: thylakoids'
        )
      )
    )
  );

  RAISE NOTICE 'Created lecture % for soniabuddy73', v_lecture_id;
END $$;

-- Verify
SELECT l.id, l.title, l.status, l.subject, u.email
FROM public.lectures l
JOIN public.users u ON u.id = l.user_id
WHERE lower(u.email) = lower('soniabuddy73@gmail.com')
  AND l.title = 'TEST — Sample Lecture';
-- Expect: 1 row, status=done
