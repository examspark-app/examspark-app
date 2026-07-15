"""Unit tests — vision Flash→Plus escalation + plan-tier gating (Rule 6 / 8)."""
from __future__ import annotations

import base64
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    _MINIMUM_PLAN,
    _rank,
    require_feature_unlocked,
)
from app.services.qwen_vision_service import (
    VisionResult,
    _notes_usable,
    _normalize_notes,
    analyze_image,
)


def test_notes_usable_requires_substance():
    assert not _notes_usable({"cleanNotes": "", "shortSummary": "", "keyPoints": []})
    assert not _notes_usable({"cleanNotes": "too short", "shortSummary": "", "keyPoints": []})
    assert _notes_usable(
        {
            "cleanNotes": "A" * 50,
            "shortSummary": "",
            "keyPoints": [],
        }
    )
    assert _notes_usable(
        {
            "cleanNotes": "",
            "shortSummary": "This is a long enough summary text.",
            "keyPoints": ["point 1"],
        }
    )


def test_normalize_notes_fills_defaults():
    assert _normalize_notes({}) == {
        "cleanNotes": "",
        "keyPoints": [],
        "shortSummary": "",
        "importantTerms": [],
    }


def test_plan_rank_ordering():
    assert _rank("free") < _rank("plan_199")
    assert _rank("plan_199") < _rank("plan_499")
    assert _rank("unknown_plan") == 0


def test_minimum_plans_match_credit_economy():
    assert _MINIMUM_PLAN[GatedFeature.PDF_ANALYSIS] == "free"
    assert _MINIMUM_PLAN[GatedFeature.DIAGRAM_ANALYSIS] == "plan_199"
    assert _MINIMUM_PLAN[GatedFeature.RECORD_LECTURE] == "plan_499"


def test_require_feature_unlocked_blocks_free_for_diagram():
    with patch("app.services.plan_tier_service.get_user_plan_tier", return_value="free"):
        with pytest.raises(FeatureLockedError) as exc:
            require_feature_unlocked("user-1", GatedFeature.DIAGRAM_ANALYSIS)
        assert exc.value.required_plan == "plan_199"
        assert exc.value.current_plan == "free"


def test_require_feature_unlocked_allows_free_for_pdf():
    with patch("app.services.plan_tier_service.get_user_plan_tier", return_value="free"):
        tier = require_feature_unlocked("user-1", GatedFeature.PDF_ANALYSIS)
        assert tier == "free"


def test_require_feature_unlocked_allows_plan199_for_diagram():
    with patch("app.services.plan_tier_service.get_user_plan_tier", return_value="plan_199"):
        tier = require_feature_unlocked("user-1", GatedFeature.DIAGRAM_ANALYSIS)
        assert tier == "plan_199"


def _fake_openrouter_response(notes: dict, status_code: int = 200) -> MagicMock:
    resp = MagicMock()
    resp.status_code = status_code
    resp.text = "error body"
    resp.json.return_value = {
        "choices": [{"message": {"content": json.dumps(notes)}}],
    }
    return resp


@pytest.mark.asyncio
async def test_analyze_image_uses_flash_when_usable():
    good = {
        "cleanNotes": "Detailed notes from a clear diagram about photosynthesis. " * 2,
        "keyPoints": ["light reaction"],
        "shortSummary": "Summary of the diagram.",
        "importantTerms": [{"term": "ATP", "definition": "energy"}],
    }
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value = mock_client
    mock_client.__aexit__.return_value = None
    mock_client.post = AsyncMock(return_value=_fake_openrouter_response(good))

    with (
        patch("app.services.qwen_vision_service.httpx.AsyncClient", return_value=mock_client),
        patch("app.services.qwen_vision_service.AIConfig.openrouter_configured", return_value=True),
        patch("app.services.qwen_vision_service.AIConfig.OPENROUTER_API_KEY", "test-key"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_FLASH_MODEL", "flash-model"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_PLUS_MODEL", "plus-model"),
    ):
        result = await analyze_image(b"fake-image-bytes", filename="diagram.png")

    assert isinstance(result, VisionResult)
    assert result.used_plus is False
    assert "photosynthesis" in result.notes["cleanNotes"].lower() or len(result.notes["cleanNotes"]) > 40
    assert mock_client.post.await_count == 1
    call_json = mock_client.post.await_args.kwargs["json"]
    assert call_json["model"] == "flash-model"


@pytest.mark.asyncio
async def test_analyze_image_escalates_to_plus_when_flash_empty():
    empty = {
        "cleanNotes": "",
        "keyPoints": [],
        "shortSummary": "",
        "importantTerms": [],
    }
    good = {
        "cleanNotes": "Complex multi-step derivation solved carefully. " * 3,
        "keyPoints": ["step 1", "step 2"],
        "shortSummary": "Solved the dense math diagram.",
        "importantTerms": [],
    }
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value = mock_client
    mock_client.__aexit__.return_value = None
    mock_client.post = AsyncMock(
        side_effect=[
            _fake_openrouter_response(empty),
            _fake_openrouter_response(good),
        ]
    )

    with (
        patch("app.services.qwen_vision_service.httpx.AsyncClient", return_value=mock_client),
        patch("app.services.qwen_vision_service.AIConfig.openrouter_configured", return_value=True),
        patch("app.services.qwen_vision_service.AIConfig.OPENROUTER_API_KEY", "test-key"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_FLASH_MODEL", "flash-model"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_PLUS_MODEL", "plus-model"),
    ):
        result = await analyze_image(b"fake-image-bytes", filename="math.png")

    assert result.used_plus is True
    assert mock_client.post.await_count == 2
    models = [c.kwargs["json"]["model"] for c in mock_client.post.await_args_list]
    assert models == ["flash-model", "plus-model"]


@pytest.mark.asyncio
async def test_analyze_image_escalates_when_flash_http_fails():
    good = {
        "cleanNotes": "Recovered notes after Flash API failure path. " * 2,
        "keyPoints": ["a"],
        "shortSummary": "Recovered via Plus.",
        "importantTerms": [],
    }
    mock_client = AsyncMock()
    mock_client.__aenter__.return_value = mock_client
    mock_client.__aexit__.return_value = None
    mock_client.post = AsyncMock(
        side_effect=[
            _fake_openrouter_response({}, status_code=500),
            _fake_openrouter_response(good),
        ]
    )

    with (
        patch("app.services.qwen_vision_service.httpx.AsyncClient", return_value=mock_client),
        patch("app.services.qwen_vision_service.AIConfig.openrouter_configured", return_value=True),
        patch("app.services.qwen_vision_service.AIConfig.OPENROUTER_API_KEY", "test-key"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_FLASH_MODEL", "flash-model"),
        patch("app.services.qwen_vision_service.AIConfig.AI_VISION_PLUS_MODEL", "plus-model"),
    ):
        result = await analyze_image(b"fake-image-bytes", filename="photo.jpg")

    assert result.used_plus is True
    assert mock_client.post.await_count == 2


def test_data_url_includes_base64_payload_shape():
    # Sanity: encoding used by vision service is standard base64.
    raw = b"hello-image"
    assert base64.b64encode(raw).decode("ascii") == "aGVsbG8taW1hZ2U="
