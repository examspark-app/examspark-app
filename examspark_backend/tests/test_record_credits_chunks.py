"""Record per-minute credits + Whisper chunk stitch helpers."""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.constants.credit_costs import (
    RECORD_CREDITS_PER_MINUTE,
    RECORD_MAX_MINUTES,
    record_credits_for_duration_minutes,
)
from app.services.audio_chunk_service import (
    BYTE_THRESHOLD,
    CHUNK_THRESHOLD_SECONDS,
    RECORD_TOO_LONG_USER_MESSAGE,
    AudioChunkError,
    resolve_record_duration_minutes,
    should_chunk_audio,
    stitch_transcript_parts,
)


def test_record_credits_per_minute():
    assert RECORD_CREDITS_PER_MINUTE == 1
    assert record_credits_for_duration_minutes(1) == 1
    assert record_credits_for_duration_minutes(30) == 30
    assert record_credits_for_duration_minutes(60) == 60
    assert record_credits_for_duration_minutes(90) == 90
    assert record_credits_for_duration_minutes(120) == 120
    assert record_credits_for_duration_minutes(180) == 180
    # Clamp at hard max — caller should reject >180, but formula clamps.
    assert record_credits_for_duration_minutes(181) == 180
    assert RECORD_MAX_MINUTES == 180


def test_stitch_transcript_parts():
    assert stitch_transcript_parts(["Hello.", "  World  ", ""]) == "Hello.\n\nWorld"
    assert stitch_transcript_parts([]) == ""
    assert stitch_transcript_parts([" only "]) == "only"


def test_should_chunk_by_duration_or_bytes():
    assert should_chunk_audio(b"x", duration_seconds=CHUNK_THRESHOLD_SECONDS + 1) is True
    assert should_chunk_audio(b"x" * (BYTE_THRESHOLD + 1), duration_seconds=60) is True
    assert should_chunk_audio(b"short", duration_seconds=60) is False


def test_resolve_rejects_over_180_from_client():
    with patch(
        "app.services.audio_chunk_service.probe_duration_minutes",
        return_value=None,
    ):
        with pytest.raises(AudioChunkError) as exc:
            resolve_record_duration_minutes(
                client_minutes=181,
                audio_bytes=b"x",
                filename="a.webm",
            )
    assert RECORD_TOO_LONG_USER_MESSAGE in str(exc.value)


def test_resolve_rejects_over_180_from_probe():
    with patch(
        "app.services.audio_chunk_service.probe_duration_minutes",
        return_value=200,
    ):
        with pytest.raises(AudioChunkError) as exc:
            resolve_record_duration_minutes(
                client_minutes=60,
                audio_bytes=b"x",
                filename="a.webm",
            )
    assert RECORD_TOO_LONG_USER_MESSAGE in str(exc.value)


def test_resolve_prefers_probe():
    with patch(
        "app.services.audio_chunk_service.probe_duration_minutes",
        return_value=120,
    ):
        assert (
            resolve_record_duration_minutes(
                client_minutes=30,
                audio_bytes=b"x",
                filename="a.webm",
            )
            == 120
        )


@pytest.mark.asyncio
async def test_chunked_transcribe_stitches_and_charges_once():
    from app.models.lecture import LectureJobStatus, ProcessLectureRequest
    from app.services.lecture_service import LectureService
    from app.services.whisper_service import TranscriptionResult
    import uuid

    svc = LectureService()
    job_id = uuid.uuid4()
    lecture_id = "11111111-1111-1111-1111-111111111111"
    svc._jobs[str(job_id)] = {"status": LectureJobStatus.QUEUED}

    chunk_results = [
        TranscriptionResult("Part one about Newton.", True, False, []),
        TranscriptionResult("Part two about gravity.", True, False, []),
    ]
    call_i = {"n": 0}

    async def fake_transcribe(audio_bytes, filename, **kwargs):
        i = call_i["n"]
        call_i["n"] += 1
        return chunk_results[i]

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
            return_value=None,
        ),
        patch.object(LectureService, "_precheck_balance", new_callable=AsyncMock),
        patch.object(LectureService, "_db_set_status", new_callable=AsyncMock),
        patch.object(
            LectureService,
            "_persist_notes_supabase_sync",
        ),
        patch(
            "app.services.lecture_service.resolve_record_duration_minutes",
            return_value=120,
        ),
        patch(
            "app.services.lecture_service.should_chunk_audio",
            return_value=True,
        ),
        patch(
            "app.services.lecture_service.split_audio_into_chunks",
            return_value=[(b"a", "c0.mp3"), (b"b", "c1.mp3")],
        ),
        patch(
            "app.services.lecture_service.transcribe_audio",
            side_effect=fake_transcribe,
        ),
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
            return_value={
                "cleanNotes": "N",
                "shortSummary": "S",
                "keyPoints": [],
                "importantTerms": [],
            },
        ),
        patch(
            "app.services.lecture_service.deduct_credits",
            return_value=1000,
        ) as deduct,
        patch(
            "app.services.lecture_service.stamp_lecture_identity",
        ),
        patch(
            "app.services.lecture_service._schedule_r2_then_rag",
        ),
    ):
        resp = await svc._run_audio_pipeline(
            job_id,
            "user-1",
            ProcessLectureRequest(source_type="recording", duration_minutes=120),
            "long.webm",
            b"long-audio-bytes-xxxx",
            lecture_id,
        )

    assert call_i["n"] == 2
    assert "Part one" in (resp.transcript or "")
    assert "Part two" in (resp.transcript or "")
    assert resp.credits_charged == 120  # 120 min × 1 credit/min
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == 120
