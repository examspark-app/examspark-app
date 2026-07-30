"""YouTube captions vs Whisper fallback + weighted RAG merge."""
from unittest.mock import AsyncMock, patch

import pytest

from app.constants.credit_costs import (
    YOUTUBE_30_TO_60_MIN,
    YOUTUBE_60_TO_90_MIN,
    YOUTUBE_MAX_MINUTES,
    YOUTUBE_UP_TO_30_MIN,
    youtube_credits_for_duration_minutes,
)
from app.services.rag_ask_service import _merge_open_and_other, _near_duplicate
from app.services.youtube_transcript_service import YoutubeCaptions


def test_youtube_credits_match_bands():
    assert youtube_credits_for_duration_minutes(10) == YOUTUBE_UP_TO_30_MIN
    assert youtube_credits_for_duration_minutes(45) == YOUTUBE_30_TO_60_MIN
    assert youtube_credits_for_duration_minutes(75) == YOUTUBE_60_TO_90_MIN
    assert YOUTUBE_MAX_MINUTES == 90


def test_near_duplicate():
    assert _near_duplicate("hello world", "hello world extra")
    assert not _near_duplicate("photosynthesis", "human heart chambers")


def test_merge_open_and_other_prioritizes_open():
    open_loaded = [
        {
            "text": "Open lecture about heart chambers.",
            "source_type": "notes",
            "similarity": 0.9,
            "excerpt": "Open",
            "lecture_id": "aaa",
        }
    ]
    other = [
        {
            "text": "Other lecture about heart atria ventricles.",
            "source_type": "notes",
            "similarity": 0.7,
            "excerpt": "Other",
            "lecture_id": "bbb",
        },
        {
            "text": "Unrelated low score",
            "source_type": "notes",
            "similarity": 0.4,
            "excerpt": "Low",
            "lecture_id": "ccc",
        },
    ]
    merged = _merge_open_and_other(open_loaded, other)
    assert merged[0]["lecture_id"] == "aaa"
    assert any("other_lecture" in (m.get("source_type") or "") for m in merged)
    assert not any(m.get("lecture_id") == "ccc" for m in merged)


def test_ask_system_has_shape1_complete():
    from app.services.rag_ask_service import _ASK_SYSTEM

    assert "Shape 1" in _ASK_SYSTEM
    assert "OMIT RULE" in _ASK_SYSTEM
    assert "2" in _ASK_SYSTEM and "4 sentences" in _ASK_SYSTEM


@pytest.mark.asyncio
async def test_youtube_pipeline_uses_captions_when_available():
    from app.models.lecture import LectureJobStatus
    from app.services.lecture_service import LectureService

    svc = LectureService()
    caps = YoutubeCaptions(
        video_id="abc123",
        text="The human heart has four chambers. " * 5,
        duration_minutes=12,
    )
    fake_notes = {
        "cleanNotes": "Notes",
        "shortSummary": "Sum",
        "keyPoints": ["a"],
        "formulas": [],
        "examTips": [],
    }

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.fetch_youtube_captions",
            return_value=caps,
        ),
        patch(
            "app.services.lecture_service.download_youtube_audio_bytes",
        ) as dl,
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
            return_value=fake_notes,
        ),
        patch(
            "app.services.lecture_service.deduct_credits",
            return_value=1000,
        ),
        patch.object(
            LectureService,
            "_precheck_balance",
            lambda self, u, a: None,
        ),
        patch.object(
            LectureService,
            "_persist_to_r2_and_db",
            lambda *a, **k: {"ok": True},
        ),
        patch.object(LectureService, "_db_set_status", lambda *a, **k: None),
        patch(
            "app.services.lecture_service.find_done_by_youtube_video_id",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_near_duplicate_transcript_lecture",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.stamp_lecture_identity",
        ),
    ):
        import uuid

        job_id = uuid.uuid4()
        svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}
        out = await svc._run_youtube_pipeline(
            job_id,
            "user-1",
            "https://youtube.com/watch?v=abc123xyz",
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        )

    assert out.credits_charged == YOUTUBE_UP_TO_30_MIN
    assert "captions" in (out.message or "").lower()
    dl.assert_not_called()


@pytest.mark.asyncio
async def test_youtube_pipeline_whisper_when_no_captions():
    from app.models.lecture import LectureJobStatus
    from app.services.lecture_service import LectureService
    from app.services.whisper_service import TranscriptionResult
    from app.services.youtube_transcript_service import YoutubeTranscriptError

    svc = LectureService()
    fake_notes = {
        "cleanNotes": "Notes",
        "shortSummary": "Sum",
        "keyPoints": ["a"],
        "formulas": [],
        "examTips": [],
    }
    tr = TranscriptionResult(
        text="Whisper transcript about photosynthesis. " * 5,
        used_turbo=True,
        low_confidence=False,
        notes=[],
    )

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.fetch_youtube_captions",
            side_effect=YoutubeTranscriptError("No captions"),
        ),
        patch(
            "app.services.lecture_service.download_youtube_audio_bytes",
            return_value=(b"x" * 2000, 25, "vid.mp3"),
        ),
        patch(
            "app.services.lecture_service.transcribe_audio",
            new_callable=AsyncMock,
            return_value=tr,
        ) as transcribe_mock,
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
            return_value=fake_notes,
        ),
        patch(
            "app.services.lecture_service.deduct_credits",
            return_value=900,
        ),
        patch.object(
            LectureService,
            "_precheck_balance",
            lambda self, u, a: None,
        ),
        patch.object(
            LectureService,
            "_persist_to_r2_and_db",
            lambda *a, **k: {"ok": True},
        ),
        patch.object(LectureService, "_db_set_status", lambda *a, **k: None),
        patch(
            "app.services.lecture_service.find_done_by_youtube_video_id",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_near_duplicate_transcript_lecture",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.stamp_lecture_identity",
        ),
    ):
        import uuid

        job_id = uuid.uuid4()
        svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}
        out = await svc._run_youtube_pipeline(
            job_id,
            "user-1",
            "https://youtube.com/watch?v=nocaps123",
            "bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee",
        )

    assert out.credits_charged == YOUTUBE_UP_TO_30_MIN
    assert "whisper" in (out.message or "").lower()
    assert out.usedTurbo is True
    transcribe_mock.assert_awaited_once()
    assert transcribe_mock.await_args.kwargs.get("allow_non_turbo_fallback") is False
