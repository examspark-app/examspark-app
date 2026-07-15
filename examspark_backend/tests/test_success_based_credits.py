"""Success-based credits — Ask AI / Home AI deduct only on SUCCESS."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.constants.ai_response_status import NOT_FOUND, SUCCESS, VALIDATION_ERROR
from app.constants.ai_response_status import http_status_to_ai_status
from app.services.ai_performance_cache import clear_performance_caches_for_tests
from app.services.rag_ask_service import AskAiError, ask_ai


def test_http_status_to_ai_status_mapping():
    assert http_status_to_ai_status(400) == VALIDATION_ERROR
    assert http_status_to_ai_status(402) == VALIDATION_ERROR
    assert http_status_to_ai_status(404) == NOT_FOUND
    assert http_status_to_ai_status(504) == "TIMEOUT"
    assert http_status_to_ai_status(502) == "API_ERROR"


def test_ask_ai_error_carries_result_status():
    err = AskAiError("timed out", status_code=504, result_status="TIMEOUT")
    assert err.result_status == "TIMEOUT"
    assert err.status_code == 504


@pytest.mark.asyncio
@patch("app.services.rag_ask_service.deduct_credits", return_value=95)
@patch(
    "app.services.rag_ask_service._generate_answer",
    new_callable=AsyncMock,
    return_value="I couldn't find this topic in your uploaded notes or exam database.",
)
@patch("app.services.rag_ask_service._fallback_full_notes_context", return_value=[])
@patch("app.services.rag_ask_service._load_chunk_texts", return_value=[])
@patch("app.services.rag_ask_service._fetch_matches_with_fallback", return_value=[])
@patch("app.services.rag_ask_service.embed_query", new_callable=AsyncMock, return_value=[0.1] * 8)
@patch("app.services.rag_ask_service.ensure_lecture_indexed", new_callable=AsyncMock)
@patch("app.services.rag_ask_service.require_feature_unlocked")
@patch("app.services.rag_ask_service.get_supabase_admin")
@patch("app.services.rag_ask_service.R2StorageService")
async def test_ask_ai_empty_context_charges_after_ai_processes(
    mock_r2_cls,
    mock_db,
    _mock_require,
    _mock_index,
    _mock_embed,
    _mock_fetch,
    _mock_load,
    _mock_fallback,
    _mock_generate,
    mock_deduct,
):
    clear_performance_caches_for_tests()
    mock_r2_cls.return_value = MagicMock()
    mock_db.return_value.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value = MagicMock(
        data={"credits_balance": 100}
    )

    result = await ask_ai(
        user_id="user-1",
        lecture_id="lec-1",
        query="What is HOF?",
        mode="normal",
        charge_credits=True,
    )

    assert result["status"] == SUCCESS
    assert result["credits_charged"] == 5
    assert result["new_balance"] == 95
    assert "couldn't find" in result["answer"].lower()
    mock_deduct.assert_called_once()
    _mock_generate.assert_awaited_once()


@pytest.mark.asyncio
@patch("app.services.rag_ask_service.deduct_credits", return_value=95)
@patch("app.services.rag_ask_service._generate_answer", new_callable=AsyncMock, return_value="Hall of Fame is a sports honor.")
@patch("app.services.rag_ask_service._fallback_full_notes_context", return_value=[])
@patch(
    "app.services.rag_ask_service._load_chunk_texts",
    return_value=[
        {
            "source_type": "notes",
            "similarity": 0.9,
            "excerpt": "HOF means Hall of Fame",
            "text": "HOF means Hall of Fame",
        }
    ],
)
@patch(
    "app.services.rag_ask_service._fetch_matches_with_fallback",
    return_value=[{"r2_chunk_path": "Users/u/Library/l/c1.txt", "source_type": "notes", "similarity": 0.9}],
)
@patch("app.services.rag_ask_service.embed_query", new_callable=AsyncMock, return_value=[0.1] * 8)
@patch("app.services.rag_ask_service.ensure_lecture_indexed", new_callable=AsyncMock)
@patch("app.services.rag_ask_service.require_feature_unlocked")
@patch("app.services.rag_ask_service.get_supabase_admin")
@patch("app.services.rag_ask_service.R2StorageService")
async def test_ask_ai_success_charges_credits(
    mock_r2_cls,
    mock_db,
    _mock_require,
    _mock_index,
    _mock_embed,
    _mock_fetch,
    _mock_load,
    _mock_fallback,
    _mock_generate,
    mock_deduct,
):
    clear_performance_caches_for_tests()
    mock_r2_cls.return_value = MagicMock()
    mock_db.return_value.table.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value = MagicMock(
        data={"credits_balance": 100}
    )

    result = await ask_ai(
        user_id="user-1",
        lecture_id="lec-1",
        query="What is HOF?",
        mode="normal",
        charge_credits=True,
    )

    assert result["status"] == SUCCESS
    assert result["credits_charged"] == 5
    assert result["new_balance"] == 95
    mock_deduct.assert_called_once()
