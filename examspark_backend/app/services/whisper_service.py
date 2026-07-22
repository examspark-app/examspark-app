"""Groq Whisper transcription — TECH_STACK.md Speech decision tree (Jul 12, 2026).

1. Default: Whisper Large v3 Turbo for every recording.
2. Transient transport / 429 / 5xx: retry same Turbo up to 2× (1s → 2s backoff).
3. Auto fallback to non-turbo if Turbo still fails or confidence is poor.
4. Never retry no-speech / HTTP 400 / invalid audio.
"""
from __future__ import annotations

import asyncio
import logging

import httpx

from app.config import AIConfig

_GROQ_TRANSCRIPTION_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
logger = logging.getLogger(__name__)

# Student-safe — mapped by Flutter lecture_user_message (A101).
NO_SPEECH_USER_MESSAGE = (
    "No speech detected. Kindly check your microphone and try again."
)

# Mirror YouTube short-transcript guard for record/upload silence hallucinations.
MIN_TRANSCRIPT_CHARS = 40

# Initial attempt + up to 2 retries on transient failures (1s → 2s).
_MAX_TRANSIENT_RETRIES = 2
_TRANSIENT_BACKOFF_SEC = (1.0, 2.0)


class TranscriptionResult:
    def __init__(
        self,
        text: str,
        used_turbo: bool,
        low_confidence: bool,
        notes: list[str],
        *,
        likely_no_speech: bool = False,
    ):
        self.text = text
        self.used_turbo = used_turbo
        self.low_confidence = low_confidence
        self.notes = notes
        self.likely_no_speech = likely_no_speech


class WhisperTranscriptionError(Exception):
    def __init__(
        self,
        message: str,
        *,
        status_code: int | None = None,
        retryable: bool = False,
    ):
        super().__init__(message)
        self.status_code = status_code
        self.retryable = retryable


def _is_retryable_http_status(status_code: int) -> bool:
    return status_code == 429 or status_code >= 500


def _is_transient_transport(exc: BaseException) -> bool:
    return isinstance(
        exc,
        (
            httpx.TimeoutException,
            httpx.TransportError,
            httpx.NetworkError,
            httpx.RemoteProtocolError,
        ),
    )


async def _call_groq_whisper_once(
    client: httpx.AsyncClient,
    audio_bytes: bytes,
    filename: str,
    model: str,
) -> dict:
    if not AIConfig.groq_configured():
        raise WhisperTranscriptionError("GROQ_API_KEY not configured on the server.")

    try:
        response = await client.post(
            _GROQ_TRANSCRIPTION_URL,
            headers={"Authorization": f"Bearer {AIConfig.GROQ_API_KEY}"},
            files={"file": (filename, audio_bytes)},
            data={"model": model, "response_format": "verbose_json"},
            timeout=120.0,
        )
    except Exception as e:
        if _is_transient_transport(e):
            logger.warning(
                "Groq Whisper transport error model=%s exc_type=%s: %s",
                model,
                type(e).__name__,
                e,
            )
            raise WhisperTranscriptionError(
                f"Groq Whisper ({model}) network/timeout: {type(e).__name__}: {e}",
                retryable=True,
            ) from e
        raise

    if response.status_code != 200:
        retryable = _is_retryable_http_status(response.status_code)
        logger.warning(
            "Groq Whisper HTTP model=%s status=%s retryable=%s body=%s",
            model,
            response.status_code,
            retryable,
            response.text[:200],
        )
        raise WhisperTranscriptionError(
            f"Groq Whisper ({model}) failed: {response.status_code} {response.text[:300]}",
            status_code=response.status_code,
            retryable=retryable,
        )
    return response.json()


async def _call_groq_whisper(
    client: httpx.AsyncClient,
    audio_bytes: bytes,
    filename: str,
    model: str,
) -> dict:
    """POST to Groq; retry same model up to 2× on transient errors only."""
    last_err: WhisperTranscriptionError | None = None
    for attempt in range(_MAX_TRANSIENT_RETRIES + 1):
        try:
            return await _call_groq_whisper_once(
                client, audio_bytes, filename, model
            )
        except WhisperTranscriptionError as e:
            last_err = e
            if not e.retryable or attempt >= _MAX_TRANSIENT_RETRIES:
                raise
            delay = _TRANSIENT_BACKOFF_SEC[min(attempt, len(_TRANSIENT_BACKOFF_SEC) - 1)]
            logger.info(
                "Groq Whisper retry model=%s attempt=%s/%s backoff=%.0fs status=%s",
                model,
                attempt + 1,
                _MAX_TRANSIENT_RETRIES,
                delay,
                e.status_code,
            )
            await asyncio.sleep(delay)
    assert last_err is not None
    raise last_err


def _segments_low_confidence(payload: dict) -> bool:
    segments = payload.get("segments") or []
    if not segments:
        return False
    poor = 0
    for seg in segments:
        avg_logprob = seg.get("avg_logprob", 0.0)
        no_speech_prob = seg.get("no_speech_prob", 0.0)
        if avg_logprob < AIConfig.LOW_CONFIDENCE_AVG_LOGPROB or no_speech_prob > AIConfig.HIGH_NO_SPEECH_PROB:
            poor += 1
    return (poor / len(segments)) > 0.25


def payload_likely_no_speech(payload: dict) -> bool:
    """True when verbose_json looks like silence / no real speech."""
    segments = payload.get("segments") or []
    text = (payload.get("text") or "").strip()
    if not text and not segments:
        return True
    if not segments:
        return len(text) < MIN_TRANSCRIPT_CHARS
    silent = 0
    for seg in segments:
        if float(seg.get("no_speech_prob") or 0.0) > AIConfig.HIGH_NO_SPEECH_PROB:
            silent += 1
    return (silent / len(segments)) >= 0.70


def transcript_too_short(text: str | None) -> bool:
    return len((text or "").strip()) < MIN_TRANSCRIPT_CHARS


def _result_from_payload(
    payload: dict,
    *,
    used_turbo: bool,
    low_confidence: bool,
    notes: list[str],
) -> TranscriptionResult:
    text = (payload.get("text") or "").strip()
    return TranscriptionResult(
        text=text,
        used_turbo=used_turbo,
        low_confidence=low_confidence,
        notes=notes,
        likely_no_speech=payload_likely_no_speech(payload)
        or transcript_too_short(text),
    )


_YOUTUBE_TURBO_ONLY_MSG = (
    "This video has no captions and Turbo transcription could not complete. "
    "Try a public video with subtitles/CC turned on, or retry in a few minutes."
)


async def transcribe_audio(
    audio_bytes: bytes,
    filename: str,
    *,
    allow_non_turbo_fallback: bool = True,
) -> TranscriptionResult:
    """Turbo first (with transient retries); optional auto-fallback to non-turbo."""
    notes: list[str] = []
    async with httpx.AsyncClient() as client:
        try:
            turbo_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_TURBO_MODEL
            )
        except WhisperTranscriptionError as e:
            if not allow_non_turbo_fallback:
                raise WhisperTranscriptionError(_YOUTUBE_TURBO_ONLY_MSG) from e
            # After Turbo retries exhausted — existing non-turbo fallback.
            notes.append(f"Turbo call failed ({e}); falling back to non-turbo.")
            logger.info(
                "Groq Whisper Turbo exhausted; falling back to standard model status=%s",
                e.status_code,
            )
            standard_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_STANDARD_MODEL
            )
            return _result_from_payload(
                standard_payload,
                used_turbo=False,
                low_confidence=False,
                notes=notes,
            )

        if _segments_low_confidence(turbo_payload):
            if not allow_non_turbo_fallback:
                raise WhisperTranscriptionError(_YOUTUBE_TURBO_ONLY_MSG)
            notes.append("Turbo confidence low on >25% of segments; re-transcribed with non-turbo.")
            standard_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_STANDARD_MODEL
            )
            return _result_from_payload(
                standard_payload,
                used_turbo=False,
                low_confidence=True,
                notes=notes,
            )

        return _result_from_payload(
            turbo_payload,
            used_turbo=True,
            low_confidence=False,
            notes=notes,
        )
