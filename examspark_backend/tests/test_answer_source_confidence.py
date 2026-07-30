"""answer_source + confidence derivation + Ask AI SUCCESS fields."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.constants.answer_source import (
    HIGH,
    KB,
    LOW,
    MEDIUM,
    NO_MATCH,
    RAG,
    derive_ask_ai_source,
    derive_confidence,
    derive_home_ai_confidence,
    derive_home_ai_source,
)
from app.constants.ai_response_status import SUCCESS as STATUS_SUCCESS
from app.services.rag_ask_service import ask_ai


def test_derive_confidence_thresholds():
    assert derive_confidence([{"similarity": 0.9}]) == HIGH
    assert derive_confidence([{"similarity": 0.55}]) == HIGH
    assert derive_confidence([{"similarity": 0.40}]) == MEDIUM
    assert derive_confidence([{"similarity": 0.20}]) == LOW
    assert derive_confidence([]) == LOW
    assert derive_confidence([{"similarity": None}]) == LOW


def test_derive_ask_ai_source_rag_vs_no_match():
    assert derive_ask_ai_source([{"similarity": 0.8}], ["chunk text"]) == RAG
    assert derive_ask_ai_source([], []) == NO_MATCH
    assert derive_ask_ai_source(None, None) == NO_MATCH


def test_derive_home_ai_source_and_confidence():
    assert derive_home_ai_source([{"similarity": 0.7}], ["notes"]) == RAG
    assert derive_home_ai_source([], None) == KB
    assert derive_home_ai_confidence([{"similarity": 0.8}], RAG) == HIGH
    assert derive_home_ai_confidence([], KB) is None


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
async def test_ask_ai_empty_context_no_match_charges(
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

    assert result["status"] == STATUS_SUCCESS
    assert result["answer_source"] == NO_MATCH
    assert result["confidence"] == LOW
    assert result["credits_charged"] == 5
    mock_deduct.assert_called_once()


@pytest.mark.asyncio
@patch("app.services.rag_ask_service.deduct_credits", return_value=95)
@patch(
    "app.services.rag_ask_service._generate_answer",
    new_callable=AsyncMock,
    return_value="HOF means Hall of Fame.",
)
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
    return_value=[
        {
            "r2_chunk_path": "Users/u/Library/l/c1.txt",
            "source_type": "notes",
            "similarity": 0.9,
        }
    ],
)
@patch("app.services.rag_ask_service.embed_query", new_callable=AsyncMock, return_value=[0.1] * 8)
@patch("app.services.rag_ask_service.ensure_lecture_indexed", new_callable=AsyncMock)
@patch("app.services.rag_ask_service.require_feature_unlocked")
@patch("app.services.rag_ask_service.get_supabase_admin")
@patch("app.services.rag_ask_service.R2StorageService")
async def test_ask_ai_strong_match_rag_high(
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

    assert result["status"] == STATUS_SUCCESS
    assert result["answer_source"] == RAG
    assert result["confidence"] == HIGH
    assert result["credits_charged"] == 5
    mock_deduct.assert_called_once()
