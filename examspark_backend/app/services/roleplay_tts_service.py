"""Provider selection and safe, user-scoped voice preferences for Roleplay."""
from __future__ import annotations

import logging
import inspect
from typing import Final

from app.config import AIConfig
from app.services.fish_tts_service import FishTtsError, synthesize_speech as synthesize_fish
from app.services.gemini_tts_service import GeminiTtsError, synthesize_speech as synthesize_gemini
from app.services.qwen_tts_service import QwenTtsError, synthesize_speech as synthesize_qwen
from app.services.supabase_admin import get_supabase_admin
from app.services import english_learning_memory_service as learning_memory

logger = logging.getLogger(__name__)


class RoleplayTtsError(Exception):
    """User-facing Roleplay TTS failure; recoverable via JSON fallback turn."""


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
    "fish": (
        {"key": "female", "label": "Female"},
        {"key": "male", "label": "Male"},
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
    "fish": {
        "female": "",
        "male": "",
    },
}
_DEFAULT_PROVIDER = "gemini"
_DEFAULT_VOICE_KEY = "female"
_DEFAULT_LANGUAGE = "English"
SUPPORTED_ROLEPLAY_LANGUAGES = frozenset({
    "English", "Spanish", "French", "Japanese", "German", "Korean",
    "Italian", "Chinese (Mandarin)", "Portuguese", "Hindi", "Arabic",
    "Vietnamese", "Indonesian", "Russian", "Bengali", "Tamil",
})

_SPEED_BY_LEVEL = {
    "beginner": 0.75,
    "elementary": 0.85,
    "intermediate": 0.95,
    "advanced": 1.0,
}
_DEFAULT_SPEED = 0.85


def _normalise(provider: str | None, voice_key: str | None, language: str | None) -> tuple[str, str, str]:
    provider = (provider or _DEFAULT_PROVIDER).strip().lower()
    voice_key = (voice_key or "").strip().lower()
    if provider not in VOICE_OPTIONS:
        raise RoleplayTtsError("Unsupported voice provider.")
    if voice_key not in _VOICE_IDS[provider]:
        # Switching provider always gets a valid provider-specific default.
        voice_key = VOICE_OPTIONS[provider][0]["key"]
    language = (language or _DEFAULT_LANGUAGE).strip()
    if language not in SUPPORTED_ROLEPLAY_LANGUAGES:
        language = _DEFAULT_LANGUAGE
    return provider, voice_key, language


def get_voice_preference(user_id: str) -> dict[str, object]:
    row = (
        get_supabase_admin()
        .table("users")
        .select("roleplay_tts_provider,roleplay_tts_voice_key,roleplay_tts_voice_id,roleplay_tts_language,roleplay_tts_preference_set")
        .eq("id", user_id)
        .limit(1)
        .execute()
        .data
        or [{}]
    )[0]
    provider, voice_key, language = _normalise(
        row.get("roleplay_tts_provider"), row.get("roleplay_tts_voice_key"),
        row.get("roleplay_tts_language"),
    )
    return {
        "provider": provider,
        "voice_key": voice_key,
        "language": language,
        "preference_set": bool(row.get("roleplay_tts_preference_set")),
        "voice_options": list(VOICE_OPTIONS[provider]),
    }


def set_voice_preference(user_id: str, provider: str, voice_key: str, language: str = _DEFAULT_LANGUAGE) -> dict[str, object]:
    provider = (provider or "").strip().lower()
    voice_key = (voice_key or "").strip().lower()
    # Reject a mismatched voice rather than silently persisting it.
    if provider not in _VOICE_IDS or voice_key not in _VOICE_IDS[provider]:
        raise RoleplayTtsError("That voice is not available for the selected provider.")
    language = language.strip() or _DEFAULT_LANGUAGE
    if language not in SUPPORTED_ROLEPLAY_LANGUAGES:
        raise RoleplayTtsError("That roleplay language is not available.")
    voice_id = (
        AIConfig.fish_audio_voice_id(language, voice_key)
        if provider == "fish"
        else _VOICE_IDS[provider][voice_key]
    )
    get_supabase_admin().table("users").update(
        {
            "roleplay_tts_provider": provider,
            "roleplay_tts_voice_key": voice_key,
            "roleplay_tts_voice_id": voice_id,
            "roleplay_tts_language": language.strip() or _DEFAULT_LANGUAGE,
            "roleplay_tts_preference_set": True,
        }
    ).eq("id", user_id).execute()
    return get_voice_preference(user_id)


def _user_speed(user_id: str) -> float:
    try:
        level = learning_memory.load_memory(user_id).get("english_level")
        if level and level in _SPEED_BY_LEVEL:
            return _SPEED_BY_LEVEL[level]
    except Exception:
        pass
    return _DEFAULT_SPEED


def _provider_configured(provider: str) -> bool:
    if provider == "qwen":
        return AIConfig.openrouter_configured()
    if provider == "gemini":
        return AIConfig.gemini_tts_configured()
    if provider == "fish":
        return AIConfig.fish_audio_configured()
    return False


def _voice_id(provider: str, voice_key: str, language: str) -> str:
    if provider == "fish":
        return AIConfig.fish_audio_voice_id(language, voice_key)
    return _VOICE_IDS[provider][voice_key]


async def synthesize_for_user(user_id: str, text: str) -> tuple[bytes, str]:
    preference = get_voice_preference(user_id)
    provider = preference["provider"]
    language = preference.get("language", _DEFAULT_LANGUAGE)
    speed = _user_speed(user_id)    
    # The saved preference remains primary. Fish is included explicitly in
    ...    
    # The saved preference remains primary. Fish is included explicitly in
    # the fallback chain; previously a Qwen preference could only fall back
    # to Gemini, so Fish was never attempted.
    providers = [provider] + [
        candidate
        for candidate in ("qwen", "gemini", "fish")
        if candidate != provider and _provider_configured(candidate)
    ]

    errors: list[str] = []
    for selected_provider in providers:
        selected_voice = _voice_id(
            selected_provider,
            preference["voice_key"] if selected_provider == provider
            else VOICE_OPTIONS[selected_provider][0]["key"],
            language,
        )
        try:
            adapter = {
                "qwen": synthesize_qwen,
                "gemini": synthesize_gemini,
                "fish": synthesize_fish,
            }[selected_provider]
            adapter_parameters = inspect.signature(adapter).parameters
            adapter_kwargs = {"voice": selected_voice}
            if "speed" in adapter_parameters:
                adapter_kwargs["speed"] = speed
            if selected_provider == "fish" and "language" in adapter_parameters:
                adapter_kwargs["language"] = language
            if "user_id" in adapter_parameters:
                adapter_kwargs["user_id"] = user_id
            return await adapter(text, **adapter_kwargs)
        except (QwenTtsError, GeminiTtsError, FishTtsError) as error:
            detail = f"{selected_provider}: {error}"
            errors.append(detail)
            logger.exception(
                "roleplay_tts_provider_failed user=%s provider=%s voice=%s detail=%s",
                user_id,
                selected_provider,
                selected_voice,
                str(error)[:1000],
            )

    raise RoleplayTtsError("Voice generation failed. " + " | ".join(errors))
