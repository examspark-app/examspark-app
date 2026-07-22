"""Tests for PYQ retrieve + metadata formatting (start PYQs)."""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.pyq_retrieve import (
    PYQ_MATCH_THRESHOLD,
    _topic_focus,
    format_verified_pyq_block,
    format_verified_pyq_line,
    match_pyqs_for_query,
)


def test_threshold_constant():
    assert PYQ_MATCH_THRESHOLD == 0.45


def test_topic_focus_strips_what_is():
    assert _topic_focus("What is photosynthesis?") == "photosynthesis"
    assert _topic_focus("explain the human heart") == "the human heart"
    assert _topic_focus("photosynthesis") is None


@pytest.mark.asyncio
async def test_empty_query_returns_empty():
    assert await match_pyqs_for_query("") == []
    assert await match_pyqs_for_query("   ") == []


@pytest.mark.asyncio
async def test_match_soft_fails_on_embed_error():
    with patch(
        "app.services.pyq_retrieve.embed_query",
        new_callable=AsyncMock,
        side_effect=Exception("no key"),
    ):
        assert await match_pyqs_for_query("photosynthesis") == []


@pytest.mark.asyncio
async def test_match_local_scan_maps_metadata_only():
    from app.services.pyq_retrieve import _cosine, clear_pyq_bank_cache

    clear_pyq_bank_cache()
    query_vec = [1.0, 0.0, 0.0, 0.0]
    stored = "[1.0,0.0,0.0,0.0]"
    mock_sb = MagicMock()
    mock_sb.table.return_value.select.return_value.not_.is_.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[
            {
                "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                "exam": "NEET",
                "year": 2024,
                "subject": "Biology",
                "chapter": "Heart",
                "weightage_stars": 5,
                "embedding": stored,
                "question_text": "MUST NOT APPEAR",
            }
        ]
    )

    with (
        patch(
            "app.services.pyq_retrieve.embed_query",
            new_callable=AsyncMock,
            return_value=query_vec,
        ),
        patch(
            "app.services.pyq_retrieve.get_supabase_admin",
            return_value=mock_sb,
        ),
    ):
        out = await match_pyqs_for_query("human heart chambers")

    assert len(out) == 1
    assert out[0]["exam"] == "NEET"
    assert out[0]["year"] == 2024
    assert out[0].get("weightage_stars") == 5
    assert "question_text" not in out[0]
    mock_sb.rpc.assert_not_called()
    assert _cosine(query_vec, [1.0, 0.0, 0.0, 0.0]) == 1.0


@pytest.mark.asyncio
async def test_what_is_query_embeds_focused_topic():
    from app.services.pyq_retrieve import clear_pyq_bank_cache

    clear_pyq_bank_cache()
    mock_sb = MagicMock()
    mock_sb.table.return_value.select.return_value.not_.is_.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[]
    )
    embed = AsyncMock(return_value=[0.1] * 4)

    with (
        patch("app.services.pyq_retrieve.embed_query", embed),
        patch(
            "app.services.pyq_retrieve.get_supabase_admin",
            return_value=mock_sb,
        ),
    ):
        await match_pyqs_for_query("What is photosynthesis?")

    embed.assert_awaited_once_with("photosynthesis")


def test_format_none_block():
    block = format_verified_pyq_block([])
    assert "VERIFIED PYQ: none" in block
    assert "Do NOT mention PYQs" in block


def test_format_verified_metadata_only():
    matches = [
        {
            "exam": "NEET",
            "year": 2024,
            "subject": "Biology",
            "chapter": "Heart",
            "similarity": 0.87,
            "question_text": "MUST NOT APPEAR",
        }
    ]
    line = format_verified_pyq_line(matches[0])
    assert "Related: NEET 2024" in line
    assert "similarity" not in line.lower()
    assert "0.87" not in line
    assert "MUST NOT APPEAR" not in line
    block = format_verified_pyq_block(matches)
    assert "VERIFIED PYQ MATCHES" in block
    assert "MUST NOT APPEAR" not in block
    assert "similarity" not in block.lower()


def test_format_exam_focus_block_weightage():
    from app.services.pyq_retrieve import format_exam_focus_block, format_exam_focus_line

    m = {
        "exam": "NEET",
        "year": 2023,
        "subject": "Biology",
        "chapter": "Photosynthesis",
        "weightage_stars": 5,
        "similarity": 0.55,
    }
    line = format_exam_focus_line(m)
    assert "Focus: NEET 2023" in line
    assert "weightage 5/5" in line
    assert "0.55" not in line
    block = format_exam_focus_block([m])
    assert "EXAM FOCUS" in block
    assert "Photosynthesis" in block


def test_ask_user_content_includes_none_block():
    from app.services.rag_ask_service import _ask_user_content

    msg = _ask_user_content(
        "how many chambers",
        "(context)",
        conversation_language=None,
        pyq_matches=[],
    )
    assert "VERIFIED PYQ: none" in msg


def test_home_user_message_includes_none_block():
    from app.services.home_ai_service import _build_user_message

    msg = _build_user_message("how many chambers", None, pyq_matches=[])
    assert "VERIFIED PYQ: none" in msg
