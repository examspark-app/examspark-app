"""YouTube path: Whisper Turbo only — no non-Turbo fallback."""
from unittest.mock import AsyncMock, patch

import pytest

from app.services.whisper_service import WhisperTranscriptionError, transcribe_audio


@pytest.mark.asyncio
async def test_turbo_only_raises_on_turbo_api_error():
    with patch(
        "app.services.whisper_service._call_groq_whisper",
        new_callable=AsyncMock,
        side_effect=WhisperTranscriptionError("turbo down"),
    ) as mock_call:
        with pytest.raises(WhisperTranscriptionError) as exc:
            await transcribe_audio(
                b"audio",
                "v.mp3",
                allow_non_turbo_fallback=False,
            )
        assert mock_call.await_count == 1
        assert "captions" in str(exc.value).lower()


@pytest.mark.asyncio
async def test_turbo_only_raises_on_low_confidence_no_second_model():
    poor_payload = {
        "text": "hello",
        "segments": [
            {"avg_logprob": -5.0, "no_speech_prob": 0.99},
            {"avg_logprob": -5.0, "no_speech_prob": 0.99},
        ],
    }
    with patch(
        "app.services.whisper_service._call_groq_whisper",
        new_callable=AsyncMock,
        return_value=poor_payload,
    ) as mock_call:
        with pytest.raises(WhisperTranscriptionError):
            await transcribe_audio(
                b"audio",
                "v.mp3",
                allow_non_turbo_fallback=False,
            )
        assert mock_call.await_count == 1


@pytest.mark.asyncio
async def test_record_path_still_falls_back_to_standard():
    from app.config import AIConfig

    calls: list[str] = []

    async def _side_effect(client, audio_bytes, filename, model):
        calls.append(model)
        if model == AIConfig.GROQ_WHISPER_TURBO_MODEL:
            raise WhisperTranscriptionError("turbo fail")
        return {"text": "ok", "segments": []}

    with patch(
        "app.services.whisper_service._call_groq_whisper",
        side_effect=_side_effect,
    ):
        result = await transcribe_audio(b"audio", "v.mp3")
    assert result.used_turbo is False
    assert result.text == "ok"
    assert len(calls) == 2
