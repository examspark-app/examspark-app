"""Tavily gate + credit costs — unit tests (no live API)."""
from unittest.mock import AsyncMock, patch

import pytest

from app.constants.credit_costs import (
    ASK_AI_DEEP,
    ASK_AI_NORMAL,
    ASK_AI_WEB_SEARCH,
    ASK_AI_WEB_SEARCH_DEEP,
    ask_ai_cost,
)
from app.services.question_router import (
    route_ask_question,
    route_home_question,
    should_run_rag,
)
from app.services.tavily_gate import rag_usable_blocks_tavily, try_tavily_fallback
from app.services.tavily_service import TavilySearchResult


def test_web_search_credits_are_higher():
    assert ASK_AI_WEB_SEARCH == 10
    assert ASK_AI_WEB_SEARCH_DEEP == 20
    assert ASK_AI_WEB_SEARCH >= ASK_AI_NORMAL * 2
    assert ask_ai_cost("normal") == ASK_AI_NORMAL
    assert ask_ai_cost("normal", used_web_search=True) == ASK_AI_WEB_SEARCH
    assert ask_ai_cost("deep", used_web_search=True) == ASK_AI_WEB_SEARCH_DEEP
    assert ask_ai_cost("deep") == ASK_AI_DEEP


def test_web_deferred_still_runs_rag():
    assert route_home_question("today's news about NEET", None) == "web_deferred"
    assert should_run_rag("web_deferred")
    assert route_ask_question("latest news on NEET 2026 result") == "web_deferred"
    assert route_ask_question("Explain photosynthesis") == "rag"
    assert not should_run_rag("direct")


def test_rag_usable_blocks_tavily():
    assert rag_usable_blocks_tavily(
        [{"similarity": 0.5}], ["some context"]
    )
    assert not rag_usable_blocks_tavily(
        [{"similarity": 0.1}], ["short"]
    )
    assert rag_usable_blocks_tavily(
        [{"similarity": None}], ["x" * 100]
    )


@pytest.mark.asyncio
async def test_gate_skips_non_web_deferred():
    out = await try_tavily_fallback(
        query="today's news",
        route="rag",
        sources_meta=[],
        context_blocks=None,
        feature="test",
    )
    assert out.used is False
    assert out.skip_reason == "route_not_web_deferred"


@pytest.mark.asyncio
async def test_gate_skips_when_rag_usable():
    with patch(
        "app.services.tavily_gate.tavily_configured", return_value=True
    ):
        out = await try_tavily_fallback(
            query="current affairs today",
            route="web_deferred",
            sources_meta=[{"similarity": 0.6}],
            context_blocks=["lecture notes hit"],
            feature="test",
        )
    assert out.used is False
    assert out.skip_reason == "rag_usable"


@pytest.mark.asyncio
async def test_gate_skips_syllabus_via_classifier():
    with (
        patch("app.services.tavily_gate.tavily_configured", return_value=True),
        patch(
            "app.services.tavily_gate.match_pyqs_for_query",
            new_callable=AsyncMock,
            return_value=[],
        ),
        patch(
            "app.services.tavily_gate.classify_genuine_current_affairs",
            new_callable=AsyncMock,
            return_value=False,
        ),
        patch(
            "app.services.tavily_gate.tavily_search",
            new_callable=AsyncMock,
        ) as search,
    ):
        out = await try_tavily_fallback(
            query="Explain Newton's laws",
            route="web_deferred",
            sources_meta=[],
            context_blocks=None,
            feature="test",
        )
    assert out.used is False
    assert out.skip_reason == "classifier_no"
    search.assert_not_called()


@pytest.mark.asyncio
async def test_gate_calls_tavily_when_all_pass():
    fake = TavilySearchResult(
        usable=True,
        query="q",
        snippets=["Breaking: scheme announced"],
        sources_meta=[{"source_type": "web", "excerpt": "scheme"}],
        tavily_credits=1,
    )
    with (
        patch("app.services.tavily_gate.tavily_configured", return_value=True),
        patch(
            "app.services.tavily_gate.match_pyqs_for_query",
            new_callable=AsyncMock,
            return_value=[],
        ),
        patch(
            "app.services.tavily_gate.classify_genuine_current_affairs",
            new_callable=AsyncMock,
            return_value=True,
        ),
        patch(
            "app.services.tavily_gate.tavily_search",
            new_callable=AsyncMock,
            return_value=fake,
        ),
    ):
        out = await try_tavily_fallback(
            query="latest news on cabinet appointment",
            route="web_deferred",
            sources_meta=[],
            context_blocks=None,
            feature="test",
        )
    assert out.used is True
    assert out.context_blocks
    assert "Trusted Web Search" in out.context_blocks[0]
