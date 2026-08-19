"""Provider selection and safe, user-scoped voice preferences for Roleplay."""
from __future__ import annotations

from typing import Final

from app.services.gemini_tts_service import GeminiTtsError, synthesize_speech as synthesize_gemini
from app.services.qwen_tts_service import QwenTtsError, synthesize_speech as synthesize_qwen
from app.services.supabase_admin import get_supabase_admin


# Flutter receives only these friendly keys/labels. Provider voice IDs remain server-side.
VOICE_OPTIONS: Final[dict[str, tuple[dict[str, str], ...]]] = {
    "qwen": (
        {"key": "female", "label": "Female"},
        {"key": "male", "label": "Male"},
    ),
    "gemini": (
        {"key": "warm", "label": "Warm"},
        {"key": "friendly", "label": "Friendly"},
        {"key": "upbeat", "label": "Upbeat"},
    ),
}

_VOICE_IDS: Final[dict[str, dict[str, str]]] = {
    "qwen": {
        "female": "loongeva_v3.6",
        "male": "loongjohn",
    },
    "gemini": {
        "warm": "Sulafat",
        "friendly": "Achird",
        "upbeat": "Puck",
    },
}
_DEFAULT_PROVIDER = "qwen"
_DEFAULT_VOICE_KEY = "female"


class RoleplayTtsError(Exception):
    """A safe failure that the Roleplay HTTP/SSE routes may expose."""


def _normalise(provider: str | None, voice_key: str | None) -> tuple[str, str]:
    provider = (provider or _DEFAULT_PROVIDER).strip().lower()
    voice_key = (voice_key or "").strip().lower()
    if provider not in VOICE_OPTIONS:
        raise RoleplayTtsError("Unsupported voice provider.")
    if voice_key not in _VOICE_IDS[provider]:
        # Switching provider always gets a valid provider-specific default.
        voice_key = VOICE_OPTIONS[provider][0]["key"]
    return provider, voice_key


def get_voice_preference(user_id: str) -> dict[str, object]:
    row = (
        get_supabase_admin()
        .table("users")
        .select("roleplay_tts_provider,roleplay_tts_voice_key,roleplay_tts_voice_id")
        .eq("id", user_id)
        .limit(1)
        .execute()
        .data
        or [{}]
    )[0]
    provider, voice_key = _normalise(
        row.get("roleplay_tts_provider"), row.get("roleplay_tts_voice_key")
    )
    return {
        "provider": provider,
        "voice_key": voice_key,
        "voice_options": list(VOICE_OPTIONS[provider]),
    }


def set_voice_preference(user_id: str, provider: str, voice_key: str) -> dict[str, object]:
    provider = (provider or "").strip().lower()
    voice_key = (voice_key or "").strip().lower()
    # Reject a mismatched voice rather than silently persisting it.
    if provider not in _VOICE_IDS or voice_key not in _VOICE_IDS[provider]:
        raise RoleplayTtsError("That voice is not available for the selected provider.")
    get_supabase_admin().table("users").update(
        {
            "roleplay_tts_provider": provider,
            "roleplay_tts_voice_key": voice_key,
            "roleplay_tts_voice_id": _VOICE_IDS[provider][voice_key],
        }
    ).eq("id", user_id).execute()
    return get_voice_preference(user_id)


async def synthesize_for_user(user_id: str, text: str) -> tuple[bytes, str]:
    preference = get_voice_preference(user_id)
    provider = preference["provider"]
    voice_id = _VOICE_IDS[provider][preference["voice_key"]]
    try:
        if provider == "qwen":
            return await synthesize_qwen(text, voice=voice_id)
        return await synthesize_gemini(text, voice=voice_id)
    except (QwenTtsError, GeminiTtsError) as error:
        raise RoleplayTtsError(str(error)) from error
