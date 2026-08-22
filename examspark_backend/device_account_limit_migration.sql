ALTER TABLE public.users ADD COLUMN IF NOT EXISTS device_id text;
CREATE INDEX IF NOT EXISTS users_device_id_idx ON public.users(device_id);