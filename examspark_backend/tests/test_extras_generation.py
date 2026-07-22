"""Unit tests — Flashcards / Quiz extras on FastAPI."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.constants.credit_costs import (
    FIVE_MIN_REVISION,
    FLASHCARDS,
    IMPORTANT_QUESTIONS,
    MIND_MAP,
    QUIZ_20_MCQ,
    REVISION_NOTES,
)
from app.services.lecture_service import LecturePipelineError, LectureService


@pytest.mark.asyncio
async def test_generate_flashcards_charges_5_after_success():
    service = LectureService()
    generated = {
        "cards": [
            {"front": "What is photosynthesis?", "back": "Light to chemical energy"},
            {"front": "Chlorophyll?", "back": "Green pigment"},
            {"front": "ATP?", "back": "Energy currency"},
        ]
    }

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_flashcards",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_flashcards_for_lecture("user-1", "lec-1")

    assert result.credits_charged == FLASHCARDS
    assert len(result.cards) == 3
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == FLASHCARDS
    upsert.assert_called_once_with(
        "lec-1", "flashcards", payload_json=generated
    )


@pytest.mark.asyncio
async def test_generate_quiz_charges_5_after_success():
    service = LectureService()
    questions = [
        {
            "question": f"Q{i}?",
            "options": ["A1", "B1", "C1", "D1"],
            "correctAnswer": "A",
        }
        for i in range(5)
    ]
    generated = {"questions": questions}

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_quiz_mcq",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_quiz_for_lecture("user-1", "lec-1")

    assert result.credits_charged == QUIZ_20_MCQ
    assert len(result.questions) == 5
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == QUIZ_20_MCQ
    upsert.assert_called_once_with("lec-1", "quiz", payload_json=generated)


@pytest.mark.asyncio
async def test_generate_flashcards_no_deduct_on_ai_fail():
    service = LectureService()

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_flashcards",
            new_callable=AsyncMock,
            side_effect=Exception("AI down"),
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        with pytest.raises(LecturePipelineError):
            await service.generate_flashcards_for_lecture("user-1", "lec-1")

    deduct.assert_not_called()


def test_get_extra_json_prefers_payload_json():
    service = LectureService()
    payload = {"cards": [{"front": "A", "back": "B"}]}

    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.limit.return_value = mock_table
    mock_table.execute.return_value = MagicMock(
        data=[{"id": "row-1", "payload_json": payload, "r2_path": "legacy/path"}]
    )

    with (
        patch.object(service, "_assert_lecture_owner"),
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(service._r2, "download_json") as download,
    ):
        result = service._get_extra_json("user-1", "lec-1", "flashcards")

    assert result == payload
    download.assert_not_called()


def test_get_extra_json_backfills_from_legacy_r2_path():
    service = LectureService()
    payload = {"questions": [{"question": "Q?", "options": ["A"], "correctAnswer": "A"}]}

    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.limit.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.execute.return_value = MagicMock(
        data=[{"id": "row-1", "payload_json": None, "r2_path": "legacy/quiz.json"}]
    )

    with (
        patch.object(service, "_assert_lecture_owner"),
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(service._r2, "download_json", return_value=payload),
    ):
        result = service._get_extra_json("user-1", "lec-1", "quiz")

    assert result == payload
    mock_table.update.assert_called_once_with({"payload_json": payload})


@pytest.mark.asyncio
async def test_generate_revision_charges_5_after_success():
    service = LectureService()
    generated = {
        "revisionSheet": "## Key Concepts\n\n- Photosynthesis converts light energy\n"
        * 3
    }

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_revision_sheet",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_revision_for_lecture("user-1", "lec-1")

    assert result.credits_charged == REVISION_NOTES
    assert len(result.revisionSheet) >= 80
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == REVISION_NOTES
    upsert.assert_called_once_with("lec-1", "revision", payload_json=generated)


@pytest.mark.asyncio
async def test_generate_important_questions_charges_20_after_success():
    service = LectureService()
    generated = {
        "questions": [
            {
                "question": f"Explain concept {i}?",
                "type": "short_answer",
                "marks": 2,
                "hint": "Think about basics",
            }
            for i in range(5)
        ]
    }

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_important_questions",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_important_questions_for_lecture(
            "user-1", "lec-1"
        )

    assert result.credits_charged == IMPORTANT_QUESTIONS
    assert len(result.questions) == 5
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == IMPORTANT_QUESTIONS
    upsert.assert_called_once_with(
        "lec-1", "important_questions", payload_json=generated
    )


@pytest.mark.asyncio
async def test_generate_mind_map_charges_30_after_success():
    service = LectureService()
    generated = {
        "title": "Photosynthesis",
        "root": {
            "label": "Photosynthesis",
            "children": [
                {
                    "label": "Light reactions",
                    "children": [
                        {"label": "Chlorophyll", "children": []},
                        {"label": "ATP", "children": []},
                    ],
                },
                {"label": "Calvin cycle", "children": []},
            ],
        },
    }

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_mind_map",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_mind_map_for_lecture("user-1", "lec-1")

    assert result.credits_charged == MIND_MAP
    assert result.root is not None
    assert result.root.label == "Photosynthesis"
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == MIND_MAP
    upsert.assert_called_once_with("lec-1", "mind_map", payload_json=generated)


@pytest.mark.asyncio
async def test_generate_five_min_revision_charges_5_after_success():
    service = LectureService()
    generated = {
        "revisionSheet": (
            "## Must-know\n- Point A\n- Point B\n"
            "## Formulas\n$$E=mc^2$$\n"
            "## One-line traps\n- Trap 1\n"
            "## 60-second summary\nShort recap for the exam."
        )
    }

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_five_min_revision",
            new_callable=AsyncMock,
            return_value=generated,
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch.object(service, "_upsert_extra") as upsert,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        result = await service.generate_five_min_revision_for_lecture(
            "user-1", "lec-1"
        )

    assert result.credits_charged == FIVE_MIN_REVISION
    assert len(result.revisionSheet) >= 60
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == FIVE_MIN_REVISION
    assert deduct.call_args.kwargs["action"] == "five_min_revision"
    upsert.assert_called_once_with(
        "lec-1", "five_min_revision", payload_json=generated
    )


@pytest.mark.asyncio
async def test_generate_five_min_revision_no_deduct_on_ai_fail():
    service = LectureService()

    with (
        patch.object(service, "_load_lecture_source_text", return_value="x" * 100),
        patch.object(service, "_precheck_balance"),
        patch(
            "app.services.lecture_service.generate_five_min_revision",
            new_callable=AsyncMock,
            side_effect=Exception("AI down"),
        ),
        patch("app.services.lecture_service.deduct_credits") as deduct,
        patch(
            "app.services.lecture_service.require_feature_unlocked",
            return_value="free",
        ),
    ):
        with pytest.raises(LecturePipelineError):
            await service.generate_five_min_revision_for_lecture("user-1", "lec-1")

    deduct.assert_not_called()
