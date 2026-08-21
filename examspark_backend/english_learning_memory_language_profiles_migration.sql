-- Keep learning facts isolated by target language.
UPDATE english_learning_memory
SET target_language = 'English'
WHERE target_language IS NULL OR btrim(target_language) = '';

ALTER TABLE english_learning_memory
  ALTER COLUMN target_language SET DEFAULT 'English',
  ALTER COLUMN target_language SET NOT NULL;

ALTER TABLE english_learning_memory
  DROP CONSTRAINT IF EXISTS english_learning_memory_pkey;

ALTER TABLE english_learning_memory
  ADD CONSTRAINT english_learning_memory_pkey
  PRIMARY KEY (user_id, target_language);