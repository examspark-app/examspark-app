"""Silent / no-mic audio must not produce notes or charge credits."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.whisper_service import (
    NO_SPEECH_USER_MESSAGE,
    TranscriptionResult,
    payload_likely_no_speech,
    transcript_too_short,
)


def test_transcript_too_short():
    assert transcript_too_short("") is True
    assert transcript_too_short("   hi  ") is True
    assert transcript_too_short("x" * 39) is True
    assert transcript_too_short("x" * 40) is False


def test_payload_likely_no_speech_empty():
    assert payload_likely_no_speech({"text": "", "segments": []}) is True


def test_payload_likely_no_speech_high_no_speech_prob():
    segs = [{"no_speech_prob": 0.95, "avg_logprob": -0.2} for _ in range(10)]
    assert payload_likely_no_speech({"text": "Newton's laws of motion…", "segments": segs}) is True


def test_payload_likely_no_speech_real_voice():
    segs = [{"no_speech_prob": 0.1, "avg_logprob": -0.2} for _ in range(10)]
    text = "Today we study Newton's second law carefully."
    assert payload_likely_no_speech({"text": text, "segments": segs}) is False


@pytest.mark.asyncio
async def test_audio_pipeline_rejects_no_speech_before_credits():
    from app.models.lecture import LectureJobStatus, ProcessLectureRequest
    from app.services.lecture_service import LecturePipelineError, LectureService

    svc = LectureService()
    import uuid

    job_id = uuid.uuid4()
    lecture_id = "lec-silence-1"
    svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}

    silent = TranscriptionResult(
        text="Newton",
        used_turbo=True,
        low_confidence=False,
        notes=[],
        likely_no_speech=True,
    )

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_done_by_content_hash",
            return_value=None,
        ),
        patch.object(LectureService, "_precheck_balance", new_callable=AsyncMock),
        patch.object(LectureService, "_db_set_status", new_callable=AsyncMock),
        patch(
            "app.services.lecture_service.transcribe_audio",
            new_callable=AsyncMock,
            return_value=silent,
        ),
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
        ) as gen,
        patch(
            "app.services.lecture_service.deduct_credits",
        ) as deduct,
    ):
        with pytest.raises(LecturePipelineError) as exc:
            await svc._run_audio_pipeline(
                job_id,
                "user-1",
                ProcessLectureRequest(
                    source_type="recording",
                    duration_minutes=5,
                ),
                "silence.webm",
                b"silent-but-not-empty-bytes-xxxx",
                lecture_id,
            )

    assert NO_SPEECH_USER_MESSAGE in str(exc.value)
    assert exc.value.status_code == 400
    gen.assert_not_called()
    deduct.assert_not_called()


@pytest.mark.asyncio
async def test_audio_pipeline_rejects_short_transcript_before_credits():
    from app.models.lecture import LectureJobStatus, ProcessLectureRequest
    from app.services.lecture_service import LecturePipelineError, LectureService

    svc = LectureService()
    import uuid

    job_id = uuid.uuid4()
    svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}

    short = TranscriptionResult(
        text="hi",
        used_turbo=True,
        low_confidence=False,
        notes=[],
        likely_no_speech=False,
    )

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_done_by_content_hash",
            return_value=None,
        ),
        patch.object(LectureService, "_precheck_balance", new_callable=AsyncMock),
        patch.object(LectureService, "_db_set_status", new_callable=AsyncMock),
        patch(
            "app.services.lecture_service.transcribe_audio",
            new_callable=AsyncMock,
            return_value=short,
        ),
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
        ) as gen,
        patch(
            "app.services.lecture_service.deduct_credits",
        ) as deduct,
    ):
        with pytest.raises(LecturePipelineError) as exc:
            await svc._run_audio_pipeline(
                job_id,
                "user-1",
                ProcessLectureRequest(
                    source_type="recording",
                    duration_minutes=5,
                ),
                "tiny.webm",
                b"tiny-audio-bytes-here",
                "lec-short",
            )

    assert NO_SPEECH_USER_MESSAGE in str(exc.value)
    gen.assert_not_called()
    deduct.assert_not_called()
