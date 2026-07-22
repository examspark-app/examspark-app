"""Strict Tavily gate — last resort after web_deferred + empty RAG/PYQ + classifier.

Never call Tavily unless ALL of:
1. route == web_deferred (only trigger point)
2. Lightweight LLM classifier says genuine current/recent events
3. RAG has no usable match AND PYQ bank has no relevant match
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

import httpx

from app.config import AIConfig
from app.constants.answer_source import CONFIDENCE_MEDIUM_MIN
from app.services.pyq_retrieve import match_pyqs_for_query
from app.services.tavily_service import (
    TavilySearchResult,
    log_tavily_usage,
    tavily_configured,
    tavily_search,
)

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Block Tavily if best RAG chunk similarity is at least this (related lecture hit).
_RAG_BLOCKS_TAVILY_MIN = CONFIDENCE_MEDIUM_MIN  # 0.35

_CLASSIFY_SYSTEM = """You classify student questions for ExamSpark.
Reply with exactly one token: YES or NO.

YES = the question needs up-to-date / recent real-world information
(current affairs, recent news, recent government schemes/policies,
recent appointments, today's results/dates that change over time).

NO = syllabus, textbook concepts, definitions, explanations, formulas,
exam strategy, product/app help, or anything answerable without live web news.

When unsure, answer NO."""


@dataclass
class TavilyGateResult:
    used: bool
    context_blocks: list[str] = field(default_factory=list)
    sources_meta: list[dict] = field(default_factory=list)
    skip_reason: str | None = None
    tavily_api_credits: int = 0
    search: TavilySearchResult | None = None


def rag_usable_blocks_tavily(
    sources_meta: list[dict] | None,
    context_blocks: list[str] | None,
) -> bool:
    """True when lecture RAG (or notes fallback) can answer — do not call Tavily."""
    best: float | None = None
    for s in sources_meta or []:
        sim = s.get("similarity")
        if sim is None:
            continue
        try:
            value = float(sim)
        except (TypeError, ValueError):
            continue
        if best is None or value > best:
            best = value
    if best is not None and best >= _RAG_BLOCKS_TAVILY_MIN:
        return True
    # Notes fallback (no similarity) with real text — treat as usable local answer.
    if context_blocks:
        joined = " ".join(b for b in context_blocks if b).strip()
        if len(joined) >= 80:
            return True
    return False


async def classify_genuine_current_affairs(query: str) -> bool:
    """Lightweight LLM check — not keyword-only."""
    q = (query or "").strip()
    if len(q) < 8:
        return False
    if not AIConfig.openrouter_configured():
        logger.warning("Current-affairs classifier skipped: OpenRouter not configured")
        return False

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                _OPENROUTER_URL,
                headers={
                    "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": AIConfig.AI_CHAT_MODEL,
                    "messages": [
                        {"role": "system", "content": _CLASSIFY_SYSTEM},
                        {"role": "user", "content": q[:800]},
                    ],
                    "max_tokens": 8,
                    "temperature": 0,
                },
            )
    except Exception as e:  # noqa: BLE001
        logger.warning("Current-affairs classifier failed: %s", e)
        return False

    if resp.status_code != 200:
        logger.warning(
            "Current-affairs classifier HTTP %s: %s",
            resp.status_code,
            resp.text[:160],
        )
        return False

    data = resp.json() if resp.content else {}
    choices = data.get("choices") or []
    if not choices:
        return False
    content = ((choices[0].get("message") or {}).get("content") or "").strip()
    # Strip think tags / noise; look for YES as whole word.
    cleaned = re.sub(r"<think>[\s\S]*?</think>", "", content, flags=re.I)
    first = cleaned.strip().split()[0].upper() if cleaned.strip() else ""
    first = first.strip(".,!:;*`\"'")
    return first == "YES"


async def try_tavily_fallback(
    *,
    query: str,
    route: str,
    sources_meta: list[dict] | None,
    context_blocks: list[str] | None,
    feature: str,
) -> TavilyGateResult:
    """Only entry for live Tavily. All gates must pass."""
    if route != "web_deferred":
        return TavilyGateResult(used=False, skip_reason="route_not_web_deferred")

    if not tavily_configured():
        log_tavily_usage(
            feature=feature,
            query=query,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="not_configured",
        )
        return TavilyGateResult(used=False, skip_reason="not_configured")

    if rag_usable_blocks_tavily(sources_meta, context_blocks):
        log_tavily_usage(
            feature=feature,
            query=query,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="rag_usable",
        )
        return TavilyGateResult(used=False, skip_reason="rag_usable")

    pyq_hits = await match_pyqs_for_query(query, limit=3)
    if pyq_hits:
        log_tavily_usage(
            feature=feature,
            query=query,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="pyq_match",
        )
        return TavilyGateResult(used=False, skip_reason="pyq_match")

    is_current = await classify_genuine_current_affairs(query)
    if not is_current:
        log_tavily_usage(
            feature=feature,
            query=query,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="classifier_no",
        )
        return TavilyGateResult(used=False, skip_reason="classifier_no")

    search = await tavily_search(query, feature=feature, search_depth="basic")
    if not search.usable:
        return TavilyGateResult(
            used=False,
            skip_reason="tavily_empty_or_error",
            tavily_api_credits=search.tavily_credits,
            search=search,
        )

    web_blocks = [
        "Trusted Web Search (current events — last resort):\n" + "\n\n---\n\n".join(search.snippets)
    ]
    return TavilyGateResult(
        used=True,
        context_blocks=web_blocks,
        sources_meta=list(search.sources_meta),
        tavily_api_credits=search.tavily_credits,
        search=search,
    )
