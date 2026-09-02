"""Fish Audio OpenAI-compatible TTS adapter for English Roleplay."""
from __future__ import annotations

import asyncio

from openai import OpenAI

from app.config import AIConfig
from app.services import english_learning_memory_service as learning_memory

_DEFAULT_SPEED = 0.85
_SPEED_BY_LEVEL = {
    "beginner": 0.75,
    "elementary": 0.85,
    "intermediate": 0.95,
    "advanced": 1.0,
}


class FishTtsError(Exception):
    """A safe, user-facing Fish Audio failure."""


def _resolve_speed(speed: float | None, user_id: str | None) -> float:
    if speed is not None:
        return max(0.25, min(4.0, float(speed)))
    if user_id:
        try:
            level = learning_memory.load_memory(user_id).get("english_level")
            if level in _SPEED_BY_LEVEL:
                return _SPEED_BY_LEVEL[level]
        except Exception:
            pass
    return _DEFAULT_SPEED


def _synthesise_blocking(
    text: str,
    *,
    voice: str,
    speed: float,
) -> bytes:
    client = OpenAI(
        base_url="https://api.fish.audio/compat/v1",
        api_key=AIConfig.FISH_AUDIO_API_KEY,
        timeout=15.0,
    )
    try:
        response = client.audio.speech.create(
            model=AIConfig.FISH_AUDIO_TTS_MODEL,
            input=text,
            voice=voice,
            response_format="mp3",
            speed=speed,
        )
    except Exception:
        response = client.audio.speech.create(
            model=AIConfig.FISH_AUDIO_TTS_MODEL,
            input=text,
            voice=voice,
            response_format="mp3",
        )
    return response.read()


async def synthesize_speech(
    text: str,
    *,
    voice: str | None = None,
    speed: float | None = None,
    user_id: str | None = None,
    language: str | None = None,
) -> tuple[bytes, str]:
    """Return Fish Audio output as ``(mp3_bytes, 'audio/mpeg')``."""
    del user_id, language  # Fish's compatible endpoint has no such fields.
    resolved_speed = _resolve_speed(speed, None)
    input_text = (text or "").strip()
    if not AIConfig.fish_audio_configured():
        raise FishTtsError(
            "FISH_AUDIO_API_KEY and all language/gender Fish Audio voice IDs must be configured."
        )
    if not input_text:
        raise FishTtsError("Cannot create speech from an empty reply.")
    if not voice:
        raise FishTtsError("Fish Audio voice ID is not configured.")
    try:
        audio = await asyncio.to_thread(
            _synthesise_blocking,
            input_text,
            voice=voice,
            speed=resolved_speed,
        )
    except Exception as error:
        raise FishTtsError(
            f"Fish Audio voice generation failed: {error}"
        ) from error
    if not audio:
        raise FishTtsError("Fish Audio returned empty audio.")
    return audio, "audio/mpeg"
