"""OpenRouter Qwen TTS adapter for English Roleplay.

The public contract deliberately matches the previous Roleplay TTS adapter:
``synthesize_speech(text) -> (audio_bytes, mime_type)``.  Flutter therefore
continues to receive its existing Base64 audio response shape.
"""
from __future__ import annotations

import asyncio

import httpx

from app.config import AIConfig

_OPENROUTER_TTS_URL = "https://openrouter.ai/api/v1/audio/speech"
_TIMEOUT_SECONDS = 45.0
_MAX_ATTEMPTS = 2


class QwenTtsError(Exception):
    """A safe, user-facing failure raised by the Roleplay voice provider."""


def _retryable_status(status_code: int) -> bool:
    return status_code == 429 or status_code >= 500


async def synthesize_speech(text: str) -> tuple[bytes, str]:
    """Synthesize one Roleplay reply through OpenRouter Qwen TTS Flash.

    OpenRouter returns raw audio bytes.  MP3 keeps the payload compact and is
    directly playable by the existing Flutter ``just_audio`` integration.
    """
    if not AIConfig.openrouter_configured():
        raise QwenTtsError("OPENROUTER_API_KEY not configured on the server.")

    input_text = (text or "").strip()
    if not input_text:
        raise QwenTtsError("Cannot create speech from an empty reply.")

    payload = {
        "model": AIConfig.QWEN_TTS_MODEL,
        "input": input_text,
        "voice": AIConfig.QWEN_TTS_VOICE,
        "response_format": "mp3",
    }
    headers = {
        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
        for attempt in range(_MAX_ATTEMPTS):
            try:
                response = await client.post(
                    _OPENROUTER_TTS_URL,
                    headers=headers,
                    json=payload,
                )
            except (httpx.TimeoutException, httpx.RequestError) as error:
                if attempt + 1 == _MAX_ATTEMPTS:
                    raise QwenTtsError(
                        "Voice generation network error. Please try again."
                    ) from error
                await asyncio.sleep(0.5)
                continue

            if response.status_code == 200:
                audio = response.content
                if not audio:
                    raise QwenTtsError("Voice provider returned empty audio.")
                mime_type = response.headers.get("content-type", "audio/mpeg")
                return audio, mime_type.split(";", 1)[0].strip() or "audio/mpeg"

            if _retryable_status(response.status_code) and attempt + 1 < _MAX_ATTEMPTS:
                await asyncio.sleep(0.5)
                continue

            raise QwenTtsError(
                "Voice generation failed: "
                f"{response.status_code} {response.text[:200]}"
            )

    raise QwenTtsError("Voice generation failed after retry.")
