"""Tavily web search â€” last-resort only (see tavily_gate.py).

Free-tier friendly: search_depth=basic (1 Tavily credit) by default.
Never call from Flutter â€” API key stays on the server.
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field

import httpx

logger = logging.getLogger(__name__)
# Separate channel for cost monitoring (grep: tavily_usage).
usage_logger = logging.getLogger("tavily_usage")

_TAVILY_URL = "https://api.tavily.com/search"
_DEFAULT_MAX_RESULTS = 5


@dataclass
class TavilySearchResult:
    usable: bool
    query: str
    snippets: list[str] = field(default_factory=list)
    sources_meta: list[dict] = field(default_factory=list)
    tavily_credits: int = 0  # API cost units (1=basic, 2=advanced)
    error: str | None = None
    raw_result_count: int = 0


def tavily_api_key() -> str:
    return (os.getenv("TAVILY_API_KEY") or "").strip()


def tavily_configured() -> bool:
    return bool(tavily_api_key())


def log_tavily_usage(
    *,
    feature: str,
    query: str,
    tavily_credits: int,
    usable: bool,
    result_count: int,
    skip_reason: str | None = None,
    error: str | None = None,
) -> None:
    usage_logger.info(
        "tavily_usage feature=%s usable=%s tavily_credits=%s results=%s "
        "skip_reason=%s error=%s query=%s",
        feature,
        usable,
        tavily_credits,
        result_count,
        skip_reason or "-",
        (error or "-")[:120],
        (query or "")[:160].replace("\n", " "),
    )


async def tavily_search(
    query: str,
    *,
    feature: str = "unknown",
    search_depth: str = "basic",
    max_results: int = _DEFAULT_MAX_RESULTS,
) -> TavilySearchResult:
    """Call Tavily Search API. Default depth=basic (cheaper)."""
    q = (query or "").strip()
    depth = (search_depth or "basic").strip().lower()
    if depth not in ("basic", "advanced"):
        depth = "basic"
    tavily_credits = 2 if depth == "advanced" else 1

    if not q:
        log_tavily_usage(
            feature=feature,
            query=q,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="empty_query",
        )
        return TavilySearchResult(usable=False, query=q, error="empty_query")

    key = tavily_api_key()
    if not key:
        log_tavily_usage(
            feature=feature,
            query=q,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="not_configured",
        )
        return TavilySearchResult(
            usable=False, query=q, error="TAVILY_API_KEY not configured"
        )

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                _TAVILY_URL,
                json={
                    "api_key": key,
                    "query": q,
                    "search_depth": depth,
                    "include_answer": False,
                    "include_raw_content": False,
                    "max_results": max(1, min(int(max_results or 5), 8)),
                },
            )
    except Exception as e:  # noqa: BLE001
        logger.warning("Tavily request failed: %s", e)
        log_tavily_usage(
            feature=feature,
            query=q,
            tavily_credits=tavily_credits,
            usable=False,
            result_count=0,
            error=str(e),
        )
        return TavilySearchResult(
            usable=False,
            query=q,
            tavily_credits=tavily_credits,
            error=str(e),
        )

    if resp.status_code != 200:
        err = f"HTTP {resp.status_code}: {resp.text[:200]}"
        logger.warning("Tavily error: %s", err)
        log_tavily_usage(
            feature=feature,
            query=q,
            tavily_credits=tavily_credits,
            usable=False,
            result_count=0,
            error=err,
        )
        return TavilySearchResult(
            usable=False,
            query=q,
            tavily_credits=tavily_credits,
            error=err,
        )

    data = resp.json() if resp.content else {}
    results = data.get("results") or []
    snippets: list[str] = []
    sources_meta: list[dict] = []
    for item in results:
        if not isinstance(item, dict):
            continue
        title = (item.get("title") or "").strip()
        content = (item.get("content") or item.get("snippet") or "").strip()
        url = (item.get("url") or "").strip()
        if not content and not title:
            continue
        block = f"{title}\n{content}".strip() if title else content
        snippets.append(block[:1200])
        sources_meta.append(
            {
                "source_type": "web",
                "similarity": None,
                "excerpt": (content or title)[:400],
                "url": url or None,
                "title": title or None,
            }
        )

    usable = len(snippets) >= 1
    log_tavily_usage(
        feature=feature,
        query=q,
        tavily_credits=tavily_credits,
        usable=usable,
        result_count=len(snippets),
        skip_reason=None if usable else "empty_results",
    )
    return TavilySearchResult(
        usable=usable,
        query=q,
        snippets=snippets,
        sources_meta=sources_meta,
        tavily_credits=tavily_credits,
        raw_result_count=len(results) if isinstance(results, list) else 0,
    )
