"""Gemini TTS adapter for Roleplay only.

The Gemini 2.5 Flash Preview TTS GenerateContent API returns 24kHz 16-bit
PCM. This service wraps it as a WAV file so the Flutter client receives a
standard, directly playable ``audio/wav`` payload.
"""
from __future__ import annotations

import asyncio
import base64
import binascii
import struct

import httpx

from app.config import AIConfig
from app.services import english_learning_memory_service as learning_memory

_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
_TIMEOUT_SECONDS = 45.0
_SAMPLE_RATE = 24000
_MAX_ATTEMPTS = 2

_DEFAULT_SPEED = 0.85
_SPEED_BY_LEVEL = {
    "beginner": 0.75,
    "elementary": 0.85,
    "intermediate": 0.95,
    "advanced": 1.0,
}


def _resolve_speed(speed: float | None, user_id: str | None) -> float:
    if speed is not None:
        return max(0.5, min(2.0, float(speed)))
    if user_id:
        try:
            level = learning_memory.load_memory(user_id).get("english_level")
            if level and level in _SPEED_BY_LEVEL:
                return _SPEED_BY_LEVEL[level]
        except Exception:
            pass
    return _DEFAULT_SPEED


class GeminiTtsError(Exception):
    pass


def _wav_from_pcm(pcm: bytes) -> bytes:
    """Build a mono, signed 16-bit PCM WAV container."""
    channels, sample_width = 1, 2
    byte_rate = _SAMPLE_RATE * channels * sample_width
    block_align = channels * sample_width
    return b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt " + struct.pack(
        "<IHHIIHH", 16, 1, channels, _SAMPLE_RATE, byte_rate, block_align, 16
    ) + b"data" + struct.pack("<I", len(pcm)) + pcm


async def synthesize_speech(
    text: str,
    *,
    voice: str | None = None,
    speed: float | None = None,
    user_id: str | None = None,
) -> tuple[bytes, str]:
    """Return Gemini TTS output as ``(wav_bytes, 'audio/wav')``.

    ``speakingRate`` is the Gemini-native speech speed parameter (range 0.5–2.0).
    """
    if not AIConfig.gemini_tts_configured():
        raise GeminiTtsError("GEMINI_API_KEY not configured on the server.")
    text = (text or "").strip()
    if not text:
        raise GeminiTtsError("Cannot create speech from an empty reply.")

    resolved_speed = _resolve_speed(speed, user_id)
    url = f"{_BASE_URL}/{AIConfig.GEMINI_TTS_MODEL}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "speakingRate": resolved_speed,
                "voiceConfig": {
                    "prebuiltVoiceConfig": {"voiceName": voice or AIConfig.GEMINI_TTS_VOICE}
                },
            },
        },
    }
    async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
        for attempt in range(_MAX_ATTEMPTS):
            try:
                response = await client.post(url, headers={"x-goog-api-key": AIConfig.GEMINI_API_KEY}, json=payload)
            except (httpx.TimeoutException, httpx.RequestError) as error:
                if attempt + 1 == _MAX_ATTEMPTS:
                    raise GeminiTtsError("Voice generation network error. Please try again.") from error
                await asyncio.sleep(0.5)
                continue
            if response.status_code == 200:
                break
            if (response.status_code == 429 or response.status_code >= 500) and attempt + 1 < _MAX_ATTEMPTS:
                await asyncio.sleep(0.5)
                continue
            raise GeminiTtsError(f"Voice generation failed: {response.status_code} {response.text[:200]}")
        else:  # pragma: no cover - loop always returns or raises
            raise GeminiTtsError("Voice generation failed after retry.")
    try:
        parts = response.json()["candidates"][0]["content"]["parts"]
        inline = next(
            p["inlineData"] for p in parts if p.get("inlineData", {}).get("data")
        )
        mime_type = inline.get("mimeType", "").lower()
        if mime_type and "audio" not in mime_type:
            raise ValueError("response did not contain audio")
        pcm = base64.b64decode(inline["data"], validate=True)
    except (KeyError, IndexError, StopIteration, ValueError, binascii.Error) as e:
        raise GeminiTtsError("Voice provider returned no playable audio.") from e
    if not pcm:
        raise GeminiTtsError("Voice provider returned empty audio.")
    return _wav_from_pcm(pcm), "audio/wav"
