-- Chat attachments keep private R2 keys; restore APIs issue fresh signed URLs.
ALTER TABLE home_ai_messages ADD COLUMN IF NOT EXISTS image_path TEXT;
ALTER TABLE english_practice_messages ADD COLUMN IF NOT EXISTS image_path TEXT;
ALTER TABLE glow_guide_messages ADD COLUMN IF NOT EXISTS image_path TEXT;

CREATE INDEX IF NOT EXISTS idx_home_ai_messages_image_path ON home_ai_messages (image_path) WHERE image_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_english_practice_messages_image_path ON english_practice_messages (image_path) WHERE image_path IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_glow_guide_messages_image_path ON glow_guide_messages (image_path) WHERE image_path IS NOT NULL;