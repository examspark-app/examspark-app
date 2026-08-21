-- Keep credit ledger timestamps comparable with English session/message UTC timestamps.
ALTER TABLE credit_transactions
  ALTER COLUMN created_at TYPE timestamptz
  USING created_at AT TIME ZONE 'UTC';

ALTER TABLE credit_transactions
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL;