"""Tests — Select & Ask AI (Phase 6)."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.constants.credit_costs import (
    SELECT_AI_EXPLAIN,
    SELECT_AI_MINI_FLASHCARDS,
    SELECT_AI_MINI_QUIZ,
    select_ai_cost_for_action,
)
from app.constants.select_ai_prompts import STRUCTURED_JSON_DELIMITER
from app.services.select_ai_service import (
    SelectAiError,
    _parse_structured_stream,
    select_ai,
)


def test_select_ai_cost_tiers():
    assert select_ai_cost_for_action("explain") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("simplify") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("translate") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("memory_trick") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("exam_view") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("ask_followup") == SELECT_AI_EXPLAIN
    assert select_ai_cost_for_action("generate_quiz") == SELECT_AI_MINI_QUIZ
    assert select_ai_cost_for_action("generate_flashcards") == SELECT_AI_MINI_FLASHCARDS


def test_parse_structured_quiz_json():
    raw = (
        "Here are 5 questions.\n"
        f"{STRUCTURED_JSON_DELIMITER}\n"
        '{"questions":[{"question":"Q1?","options":["a","b","c","d"],'
        '"correctAnswer":"A","explanation":"e"}]}'
    )
    answer, structured = _parse_structured_stream(raw)
    assert "Here are 5 questions" in answer
    assert structured is not None
    assert len(structured["questions"]) == 1


def test_parse_structured_flashcards_json():
    raw = (
        "Cards ready.\n"
        f"{STRUCTURED_JSON_DELIMITER}\n"
        '{"cards":[{"front":"ATP","back":"Energy currency"}]}'
    )
    answer, structured = _parse_structured_stream(raw)
    assert structured is not None
    assert structured["cards"][0]["front"] == "ATP"


@pytest.mark.asyncio
async def test_select_ai_charges_2_after_explain_success():
    with (
        patch(
            "app.services.select_ai_service.require_feature_unlocked",
            return_value="free",
        ),
        patch("app.services.select_ai_service._credits_balance", return_value=50),
        patch(
            "app.services.select_ai_service._retrieve_selection_context",
            new_callable=AsyncMock,
            return_value=(["tiny context"], [{"source_type": "notes", "similarity": 0.9}]),
        ),
        patch(
            "app.services.select_ai_service._generate_select_answer",
            new_callable=AsyncMock,
            return_value="F = ma means force equals mass times acceleration.",
        ),
        patch("app.services.select_ai_service.deduct_credits", return_value=48) as deduct,
        patch(
            "app.services.select_ai_service.resolve_answer_language",
            return_value="ENGLISH",
        ),
        patch(
            "app.services.select_ai_service.derive_ask_ai_source",
            return_value="NOTES",
        ),
        patch(
            "app.services.select_ai_service.derive_confidence",
            return_value="HIGH",
        ),
    ):
        result = await select_ai(
            "user-1",
            "lec-1",
            "F = ma",
            "explain",
        )

    assert result["credits_charged"] == SELECT_AI_EXPLAIN
    assert result["new_balance"] == 48
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == SELECT_AI_EXPLAIN


@pytest.mark.asyncio
async def test_select_ai_charges_3_for_mini_quiz():
    quiz_body = (
        "Quiz:\n"
        f"{STRUCTURED_JSON_DELIMITER}\n"
        '{"questions":['
        + ",".join(
            [
                '{"question":"Q%d?","options":["a","b","c","d"],"correctAnswer":"A"}'
                % i
                for i in range(5)
            ]
        )
        + "]}"
    )
    with (
        patch(
            "app.services.select_ai_service.require_feature_unlocked",
            return_value="free",
        ),
        patch("app.services.select_ai_service._credits_balance", return_value=50),
        patch(
            "app.services.select_ai_service._retrieve_selection_context",
            new_callable=AsyncMock,
            return_value=([], []),
        ),
        patch(
            "app.services.select_ai_service._generate_select_answer",
            new_callable=AsyncMock,
            return_value=quiz_body,
        ),
        patch("app.services.select_ai_service.deduct_credits", return_value=47) as deduct,
        patch(
            "app.services.select_ai_service.resolve_answer_language",
            return_value="ENGLISH",
        ),
        patch(
            "app.services.select_ai_service.derive_ask_ai_source",
            return_value="INTERNAL",
        ),
        patch(
            "app.services.select_ai_service.derive_confidence",
            return_value="MEDIUM",
        ),
    ):
        result = await select_ai(
            "user-1",
            "lec-1",
            "Photosynthesis converts light to chemical energy.",
            "generate_quiz",
        )

    assert result["credits_charged"] == SELECT_AI_MINI_QUIZ
    assert result["structured_result"] is not None
    assert len(result["structured_result"]["questions"]) == 5
    deduct.assert_called_once()
    assert deduct.call_args.kwargs["amount"] == SELECT_AI_MINI_QUIZ


@pytest.mark.asyncio
async def test_select_ai_no_deduct_on_ai_fail():
    with (
        patch(
            "app.services.select_ai_service.require_feature_unlocked",
            return_value="free",
        ),
        patch("app.services.select_ai_service._credits_balance", return_value=50),
        patch(
            "app.services.select_ai_service._retrieve_selection_context",
            new_callable=AsyncMock,
            return_value=([], []),
        ),
        patch(
            "app.services.select_ai_service._generate_select_answer",
            new_callable=AsyncMock,
            side_effect=SelectAiError("AI down", status_code=502),
        ),
        patch("app.services.select_ai_service.deduct_credits") as deduct,
        patch(
            "app.services.select_ai_service.resolve_answer_language",
            return_value="ENGLISH",
        ),
        patch(
            "app.services.select_ai_service.derive_ask_ai_source",
            return_value="INTERNAL",
        ),
        patch(
            "app.services.select_ai_service.derive_confidence",
            return_value="LOW",
        ),
    ):
        with pytest.raises(SelectAiError):
            await select_ai("user-1", "lec-1", "ATP", "memory_trick")

    deduct.assert_not_called()


@pytest.mark.asyncio
async def test_retrieve_selection_context_limits_to_two_chunks():
    from app.services.select_ai_service import _retrieve_selection_context

    hits = [
        {"r2_chunk_path": f"p{i}", "source_type": "notes", "similarity": 0.9 - i * 0.01}
        for i in range(5)
    ]

    with (
        patch(
            "app.services.select_ai_service.ensure_lecture_indexed",
            new_callable=AsyncMock,
        ),
        patch(
            "app.services.select_ai_service.embed_query",
            new_callable=AsyncMock,
            return_value=[0.1] * 8,
        ),
        patch(
            "app.services.select_ai_service._fetch_matches_with_fallback",
            return_value=hits,
        ),
        patch("app.services.select_ai_service.R2StorageService") as r2_cls,
    ):
        r2 = MagicMock()
        r2.download_text.side_effect = lambda p: f"text for {p}" * 20
        r2_cls.return_value = r2
        blocks, meta = await _retrieve_selection_context(
            "u1", "lec-1", "short", "explain"
        )

    assert len(blocks) <= 2
    assert len(meta) <= 2
