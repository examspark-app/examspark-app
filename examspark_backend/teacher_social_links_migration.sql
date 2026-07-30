-- ExamSpark — Teacher social / trust links (optional)
-- Founder Jul 23, 2026: Teacher Dashboard pe edit; student profile pe show.
-- Supabase → SQL Editor → Run once

ALTER TABLE teacher_profiles
    ADD COLUMN IF NOT EXISTS link_website TEXT,
    ADD COLUMN IF NOT EXISTS link_youtube TEXT,
    ADD COLUMN IF NOT EXISTS link_instagram TEXT,
    ADD COLUMN IF NOT EXISTS link_facebook TEXT,
    ADD COLUMN IF NOT EXISTS link_linkedin TEXT,
    ADD COLUMN IF NOT EXISTS link_whatsapp TEXT,
    ADD COLUMN IF NOT EXISTS link_telegram TEXT,
    ADD COLUMN IF NOT EXISTS link_x TEXT;

COMMENT ON COLUMN teacher_profiles.link_website IS 'Optional public website URL for student trust';
COMMENT ON COLUMN teacher_profiles.link_youtube IS 'Optional YouTube URL';
COMMENT ON COLUMN teacher_profiles.link_instagram IS 'Optional Instagram URL';
COMMENT ON COLUMN teacher_profiles.link_facebook IS 'Optional Facebook URL';
COMMENT ON COLUMN teacher_profiles.link_linkedin IS 'Optional LinkedIn URL';
COMMENT ON COLUMN teacher_profiles.link_whatsapp IS 'Optional WhatsApp (wa.me or phone)';
COMMENT ON COLUMN teacher_profiles.link_telegram IS 'Optional Telegram URL';
COMMENT ON COLUMN teacher_profiles.link_x IS 'Optional X / Twitter URL';

-- Verify
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'teacher_profiles'
  AND column_name LIKE 'link_%'
ORDER BY column_name;
