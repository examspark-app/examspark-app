-- Persist a user's Roleplay voice choice on the existing authenticated profile.
-- Apply this in Supabase SQL Editor before deploying the backend that uses it.
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS roleplay_tts_provider TEXT NOT NULL DEFAULT 'qwen',
    ADD COLUMN IF NOT EXISTS roleplay_tts_voice_key TEXT NOT NULL DEFAULT 'female',
    ADD COLUMN IF NOT EXISTS roleplay_tts_voice_id TEXT NOT NULL DEFAULT 'loongeva_v3.6',
    ADD COLUMN IF NOT EXISTS roleplay_tts_language TEXT NOT NULL DEFAULT 'English',
    ADD COLUMN IF NOT EXISTS roleplay_tts_preference_set BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_roleplay_tts_provider_check,
    DROP CONSTRAINT IF EXISTS users_roleplay_tts_voice_key_check;

ALTER TABLE public.users
    ADD CONSTRAINT users_roleplay_tts_provider_check
        CHECK (roleplay_tts_provider IN ('qwen', 'gemini', 'fish')),
    ADD CONSTRAINT users_roleplay_tts_voice_key_check
        CHECK (
            roleplay_tts_voice_key IN (
                'female', 'male', 'warm', 'friendly', 'upbeat'
            )
        );
