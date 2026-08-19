"""Gemini TTS adapter for Roleplay only.

The Gemini 2.5 Flash Preview TTS GenerateContent API returns 24kHz 16-bit
PCM. This service wraps it as a WAV file so the Flutter client receives a
standard, directly playable ``audio/wav`` payload.
"""
from __future__ import annotations

import base64
import struct

import httpx

from app.config import AIConfig

_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
_TIMEOUT_SECONDS = 45.0
_SAMPLE_RATE = 24000


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


async def synthesize_speech(text: str) -> tuple[bytes, str]:
    """Return Gemini TTS output as ``(wav_bytes, 'audio/wav')``."""
    if not AIConfig.gemini_tts_configured():
        raise GeminiTtsError("GEMINI_API_KEY not configured on the server.")
    text = (text or "").strip()
    if not text:
        raise GeminiTtsError("Cannot create speech from an empty reply.")

    url = f"{_BASE_URL}/{AIConfig.GEMINI_TTS_MODEL}:generateContent"
    payload = {
        "contents": [{"parts": [{"text": text}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "voiceConfig": {
                    "prebuiltVoiceConfig": {"voiceName": AIConfig.GEMINI_TTS_VOICE}
                }
            },
        },
    }
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
            response = await client.post(
                url,
                headers={"x-goog-api-key": AIConfig.GEMINI_API_KEY},
                json=payload,
            )
    except httpx.TimeoutException as e:
        raise GeminiTtsError("Voice generation timed out. Please try again.") from e
    except httpx.HTTPError as e:
        raise GeminiTtsError(f"Voice generation network error: {e}") from e
    if response.status_code != 200:
        raise GeminiTtsError(
            f"Voice generation failed: {response.status_code} {response.text[:200]}"
        )
    try:
        parts = response.json()["candidates"][0]["content"]["parts"]
        encoded = next(
            p["inlineData"]["data"] for p in parts if p.get("inlineData", {}).get("data")
        )
        pcm = base64.b64decode(encoded)
    except (KeyError, IndexError, StopIteration, ValueError) as e:
        raise GeminiTtsError("Voice provider returned no playable audio.") from e
    if not pcm:
        raise GeminiTtsError("Voice provider returned empty audio.")
    return _wav_from_pcm(pcm), "audio/wav"
