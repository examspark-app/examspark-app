-- Allow lectures.source_type = 'youtube_link' (YouTube Link → Notes).
-- Safe to re-run.

ALTER TABLE public.lectures
  DROP CONSTRAINT IF EXISTS lectures_source_type_check;

ALTER TABLE public.lectures
  ADD CONSTRAINT lectures_source_type_check
  CHECK (source_type IN (
    'recorded',
    'uploaded_audio',
    'uploaded_document',
    'youtube_link'
  ));
