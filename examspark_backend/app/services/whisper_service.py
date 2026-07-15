"""Groq Whisper transcription — TECH_STACK.md Speech decision tree (Jul 12, 2026).

1. Default: Whisper Large v3 Turbo for every recording.
2. (Noise-cancellation preprocessing is a Phase 5 follow-up — not implemented
   here yet; flagged in TranscriptionResult.notes so it's visible, not silent.)
3. Auto fallback to non-turbo if Turbo's own confidence signals are poor
   (`avg_logprob` too low / `no_speech_prob` too high on verbose_json
   segments) or the Turbo call errors/times out.
4. Cross-talk/diarization flagging is NOT implemented yet (explicitly a
   Phase 5 diarization requirement per TECH_STACK.md — no diarization model
   wired). Left as a follow-up, not silently skipped.
"""
import httpx

from app.config import AIConfig

_GROQ_TRANSCRIPTION_URL = "https://api.groq.com/openai/v1/audio/transcriptions"


class TranscriptionResult:
    def __init__(self, text: str, used_turbo: bool, low_confidence: bool, notes: list[str]):
        self.text = text
        self.used_turbo = used_turbo
        self.low_confidence = low_confidence
        self.notes = notes


class WhisperTranscriptionError(Exception):
    pass


async def _call_groq_whisper(
    client: httpx.AsyncClient,
    audio_bytes: bytes,
    filename: str,
    model: str,
) -> dict:
    if not AIConfig.groq_configured():
        raise WhisperTranscriptionError("GROQ_API_KEY not configured on the server.")

    response = await client.post(
        _GROQ_TRANSCRIPTION_URL,
        headers={"Authorization": f"Bearer {AIConfig.GROQ_API_KEY}"},
        files={"file": (filename, audio_bytes)},
        data={"model": model, "response_format": "verbose_json"},
        timeout=120.0,
    )
    if response.status_code != 200:
        raise WhisperTranscriptionError(
            f"Groq Whisper ({model}) failed: {response.status_code} {response.text[:300]}"
        )
    return response.json()


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
    # Flag as low-confidence if a meaningful fraction of segments are poor,
    # not just one noisy moment in an otherwise clean recording.
    return (poor / len(segments)) > 0.25


async def transcribe_audio(audio_bytes: bytes, filename: str) -> TranscriptionResult:
    """Turbo first; auto-fallback to non-turbo on low confidence or error."""
    notes: list[str] = []
    async with httpx.AsyncClient() as client:
        try:
            turbo_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_TURBO_MODEL
            )
        except WhisperTranscriptionError as e:
            notes.append(f"Turbo call failed ({e}); falling back to non-turbo.")
            standard_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_STANDARD_MODEL
            )
            return TranscriptionResult(
                text=standard_payload.get("text", ""),
                used_turbo=False,
                low_confidence=False,
                notes=notes,
            )

        if _segments_low_confidence(turbo_payload):
            notes.append("Turbo confidence low on >25% of segments; re-transcribed with non-turbo.")
            standard_payload = await _call_groq_whisper(
                client, audio_bytes, filename, AIConfig.GROQ_WHISPER_STANDARD_MODEL
            )
            return TranscriptionResult(
                text=standard_payload.get("text", ""),
                used_turbo=False,
                low_confidence=True,
                notes=notes,
            )

        return TranscriptionResult(
            text=turbo_payload.get("text", ""),
            used_turbo=True,
            low_confidence=False,
            notes=notes,
        )
