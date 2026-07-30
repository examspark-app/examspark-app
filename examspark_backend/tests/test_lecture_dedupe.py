"""Per-student lecture duplicate detection (Layer 1 + Layer 2)."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.lecture_dedupe import (
    DUPLICATE_USER_MESSAGE,
    sha256_bytes,
)


def test_sha256_stable():
    assert sha256_bytes(b"abc") == sha256_bytes(b"abc")
    assert sha256_bytes(b"abc") != sha256_bytes(b"abd")


@pytest.mark.asyncio
async def test_audio_layer1_hash_reuses_zero_credits():
    from app.models.lecture import LectureJobStatus, ProcessLectureRequest, ProcessedNotes
    from app.services.lecture_service import LectureService

    svc = LectureService()
    audio = b"identical-audio-bytes-12345"
    original = {
        "id": "11111111-1111-1111-1111-111111111111",
        "title": "Old",
        "r2_folder_path": "Users/u/Library/111/",
        "status": "done",
    }
    notes = ProcessedNotes(
        cleanNotes="Cached notes",
        shortSummary="Sum",
        keyPoints=["k"],
        importantTerms=[],
    )

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_done_by_content_hash",
            return_value=original,
        ),
        patch.object(
            LectureService,
            "get_lecture_notes",
            return_value=notes,
        ),
        patch.object(
            LectureService,
            "get_lecture_transcript",
            side_effect=Exception("skip"),
        ),
        patch(
            "app.services.lecture_service.mark_lecture_as_duplicate",
        ) as mark,
        patch.object(LectureService, "_mirror_notes_row", lambda *a, **k: None),
        patch.object(LectureService, "_db_set_status", lambda *a, **k: None),
        patch(
            "app.services.lecture_service.transcribe_audio",
            new_callable=AsyncMock,
        ) as whisper,
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
        ) as gen,
        patch(
            "app.services.lecture_service.deduct_credits",
        ) as deduct,
    ):
        import uuid

        job_id = uuid.uuid4()
        svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}
        out = await svc._run_audio_pipeline(
            job_id,
            "user-1",
            ProcessLectureRequest(
                source_type="recording",
                duration_minutes=20,
            ),
            "a.webm",
            audio,
            "22222222-2222-2222-2222-222222222222",
        )

    assert out.is_duplicate is True
    assert out.credits_charged == 0
    assert out.duplicate_layer == "hash"
    assert DUPLICATE_USER_MESSAGE in (out.message or "")
    whisper.assert_not_called()
    gen.assert_not_called()
    deduct.assert_not_called()
    mark.assert_called_once()


@pytest.mark.asyncio
async def test_youtube_layer1_video_id_reuses_zero_credits():
    from app.models.lecture import LectureJobStatus, ProcessedNotes
    from app.services.lecture_service import LectureService

    svc = LectureService()
    original = {
        "id": "33333333-3333-3333-3333-333333333333",
        "title": "YT",
        "status": "done",
    }
    notes = ProcessedNotes(cleanNotes="YT notes", shortSummary="S")

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_done_by_youtube_video_id",
            return_value=original,
        ),
        patch.object(LectureService, "get_lecture_notes", return_value=notes),
        patch.object(
            LectureService,
            "get_lecture_transcript",
            side_effect=Exception("skip"),
        ),
        patch("app.services.lecture_service.mark_lecture_as_duplicate"),
        patch.object(LectureService, "_mirror_notes_row", lambda *a, **k: None),
        patch.object(LectureService, "_db_set_status", lambda *a, **k: None),
        patch(
            "app.services.lecture_service.fetch_youtube_captions",
        ) as caps,
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
        ) as gen,
        patch("app.services.lecture_service.deduct_credits") as deduct,
    ):
        import uuid

        job_id = uuid.uuid4()
        svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}
        out = await svc._run_youtube_pipeline(
            job_id,
            "user-1",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "44444444-4444-4444-4444-444444444444",
        )

    assert out.is_duplicate is True
    assert out.credits_charged == 0
    assert out.duplicate_layer == "youtube"
    caps.assert_not_called()
    gen.assert_not_called()
    deduct.assert_not_called()


@pytest.mark.asyncio
async def test_audio_layer2_transcript_skips_notes():
    from app.models.lecture import LectureJobStatus, ProcessLectureRequest, ProcessedNotes
    from app.services.lecture_service import LectureService
    from app.services.whisper_service import TranscriptionResult

    svc = LectureService()
    audio = b"different-bytes-same-speech"
    near = {
        "id": "55555555-5555-5555-5555-555555555555",
        "title": "Same lecture",
        "status": "done",
        "similarity": 0.97,
    }
    notes = ProcessedNotes(cleanNotes="Reuse", shortSummary="S")
    tr = TranscriptionResult(
        text="Photosynthesis converts light energy into chemical energy. " * 4,
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
            "app.services.lecture_service.find_done_by_content_hash",
            return_value=None,
        ),
        patch(
            "app.services.lecture_service.find_near_duplicate_transcript_lecture",
            new_callable=AsyncMock,
            return_value=near,
        ),
        patch(
            "app.services.lecture_service.transcribe_audio",
            new_callable=AsyncMock,
            return_value=tr,
        ),
        patch.object(LectureService, "_precheck_balance", lambda *a, **k: None),
        patch.object(LectureService, "get_lecture_notes", return_value=notes),
        patch.object(
            LectureService,
            "get_lecture_transcript",
            side_effect=Exception("skip"),
        ),
        patch("app.services.lecture_service.mark_lecture_as_duplicate"),
        patch.object(LectureService, "_mirror_notes_row", lambda *a, **k: None),
        patch.object(LectureService, "_db_set_status", lambda *a, **k: None),
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
        ) as gen,
        patch("app.services.lecture_service.deduct_credits") as deduct,
    ):
        import uuid

        job_id = uuid.uuid4()
        svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}
        out = await svc._run_audio_pipeline(
            job_id,
            "user-1",
            ProcessLectureRequest(source_type="recording", duration_minutes=15),
            "b.webm",
            audio,
            "66666666-6666-6666-6666-666666666666",
        )

    assert out.is_duplicate is True
    assert out.credits_charged == 0
    assert out.duplicate_layer == "transcript"
    gen.assert_not_called()
    deduct.assert_not_called()
