-- Fix: TEST Sample Lecture — add diagram (visual_payload_json was NULL)
-- Why diagram missing: seed stored NULL, not a Flutter bug.
-- Supabase → SQL Editor → Run (soniabuddy73 / any user with TEST lecture)

UPDATE public.notes n
SET visual_payload_json = jsonb_build_object(
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
FROM public.lectures l
WHERE n.lecture_id = l.id
  AND l.title = 'TEST — Sample Lecture';

-- Expect: UPDATE 1 (or more if several TEST lectures)
