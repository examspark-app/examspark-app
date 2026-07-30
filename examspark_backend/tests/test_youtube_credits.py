"""YouTube Link → Notes — credit bands, URL parse, Free gating."""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.constants.credit_costs import (
    YOUTUBE_20_TO_40_MIN,
    YOUTUBE_40_TO_60_MIN,
    YOUTUBE_MAX_MINUTES,
    YOUTUBE_UP_TO_20_MIN,
    youtube_credits_for_duration_minutes,
)
from app.services.plan_tier_service import GatedFeature, _MINIMUM_PLAN, require_feature_unlocked
from app.services.youtube_transcript_service import (
    YoutubeCaptions,
    YoutubeTranscriptError,
    extract_video_id,
)


def test_youtube_credit_bands():
    assert youtube_credits_for_duration_minutes(1) == YOUTUBE_UP_TO_20_MIN
    assert youtube_credits_for_duration_minutes(30) == YOUTUBE_UP_TO_20_MIN
    assert youtube_credits_for_duration_minutes(31) == YOUTUBE_20_TO_40_MIN
    assert youtube_credits_for_duration_minutes(60) == YOUTUBE_20_TO_40_MIN
    assert youtube_credits_for_duration_minutes(61) == YOUTUBE_40_TO_60_MIN
    assert youtube_credits_for_duration_minutes(90) == YOUTUBE_40_TO_60_MIN
    assert YOUTUBE_UP_TO_20_MIN == 10
    assert YOUTUBE_20_TO_40_MIN == 20
    assert YOUTUBE_40_TO_60_MIN == 40
    assert YOUTUBE_MAX_MINUTES == 90


def test_youtube_free_gate():
    assert _MINIMUM_PLAN[GatedFeature.YOUTUBE_LINK] == "free"
    with patch("app.services.plan_tier_service.get_user_plan_tier", return_value="free"):
        assert require_feature_unlocked("u1", GatedFeature.YOUTUBE_LINK) == "free"


def test_extract_video_id_watch_and_short():
    assert extract_video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ"
    assert extract_video_id("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
    assert extract_video_id("https://youtube.com/shorts/abc123XYZ") == "abc123XYZ"
    with pytest.raises(YoutubeTranscriptError):
        extract_video_id("https://example.com/watch")


@pytest.mark.asyncio
async def test_youtube_pipeline_rejects_over_90_no_deduct():
    from app.models.lecture import LectureSourceType, ProcessLectureRequest
    from app.services.lecture_service import LecturePipelineError, LectureService

    service = LectureService()
    captions = YoutubeCaptions(
        video_id="longvid",
        text="x" * 100,
        duration_minutes=95,
    )

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
        patch(
            "app.services.lecture_service.fetch_youtube_captions",
            return_value=captions,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_db_set_status"),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.find_done_by_youtube_video_id",
            return_value=None,
        ),
    ):
        with pytest.raises(LecturePipelineError) as exc:
            await service.create_job(
                user_id="user-1",
                request=ProcessLectureRequest(source_type=LectureSourceType.YOUTUBE_LINK),
                filename=None,
                file_bytes=None,
                lecture_id="lec-1",
                youtube_url="https://youtu.be/longvid",
            )
        assert exc.value.status_code == 400
        assert "90" in str(exc.value)
        deduct.assert_not_called()


@pytest.mark.asyncio
async def test_youtube_pipeline_charges_35_on_success():
    from app.models.lecture import LectureSourceType, ProcessLectureRequest
    from app.services.lecture_service import LectureService

    service = LectureService()
    captions = YoutubeCaptions(
        video_id="shortvid",
        text=("Photosynthesis converts light energy into chemical energy. " * 4),
        duration_minutes=12,
    )
    notes = {
        "cleanNotes": "Notes about photosynthesis. " * 5,
        "keyPoints": ["Light", "Energy"],
        "shortSummary": "Summary of photosynthesis.",
        "importantTerms": ["chlorophyll"],
    }

    with (
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
        patch(
            "app.services.lecture_service.fetch_youtube_captions",
            return_value=captions,
        ),
        patch(
            "app.services.lecture_service.generate_notes",
            new_callable=AsyncMock,
            return_value=notes,
        ),
        patch(
            "app.services.lecture_service.deduct_credits",
            return_value=15,
        ) as deduct,
        patch.object(service, "_precheck_balance"),
        patch.object(service, "_db_set_status"),
        patch.object(service, "_persist_to_r2_and_db", return_value={}),
    ):
        result = await service.create_job(
            user_id="user-1",
            request=ProcessLectureRequest(source_type=LectureSourceType.YOUTUBE_LINK),
            filename=None,
            file_bytes=None,
            lecture_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            youtube_url="https://youtu.be/shortvid",
        )

    assert result.credits_charged == YOUTUBE_UP_TO_20_MIN
    assert result.status.value == "complete"
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == YOUTUBE_UP_TO_20_MIN
    assert deduct.call_args.kwargs["action"] == "youtube_link"
