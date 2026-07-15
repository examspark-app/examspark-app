"""Smart question routing — skip RAG when safe (Phase 1 performance).

Ask AI (lecture) always uses RAG. Home may go direct for product/general Qs.
Web / current-affairs → log deferred; still direct until Tavily is live.
"""
from __future__ import annotations

import logging
import re
from typing import Literal

logger = logging.getLogger(__name__)

RouteKind = Literal["direct", "rag", "web_deferred"]

_PRODUCT_GENERAL = re.compile(
    r"(?i)\b("
    r"credit|credits|examspark|subscription|plan\s*tier|pricing|"
    r"how\s+do\s+(i|you)|what\s+can\s+you|who\s+are\s+you|"
    r"hello|hi\b|hey\b|namaste|good\s+(morning|evening|afternoon)|"
    r"buy\s+credits|insufficient\s+credits|razorpay|"
    r"teacher\s+dashboard|library\s+tab|study\s+workspace"
    r")\b"
)

_WEB_HINTS = re.compile(
    r"(?i)\b("
    r"today'?s\s+news|current\s+affairs|latest\s+news|"
    r"breaking\s+news|who\s+won\s+(the\s+)?election|"
    r"latest\s+update\s+on|as\s+of\s+202[4-9]"
    r")\b"
)


def route_home_question(query: str, lecture_id: str | None) -> RouteKind:
    """Home: skip embed/vector when no lecture or clearly product/general."""
    q = (query or "").strip()
    if _WEB_HINTS.search(q):
        logger.info("perf_route=web_deferred feature=home_ai (Tavily not live)")
        return "web_deferred"

    lid = (lecture_id or "").strip()
    if not lid:
        return "direct"

    if _PRODUCT_GENERAL.search(q):
        return "direct"

    return "rag"


def route_ask_question(query: str) -> RouteKind:
    """Lecture Ask AI always retrieves notes (never skip RAG)."""
    q = (query or "").strip()
    if _WEB_HINTS.search(q):
        logger.info("perf_route=web_deferred feature=ask_ai (Tavily not live; still RAG)")
    return "rag"


def should_run_rag(route: RouteKind) -> bool:
    return route == "rag"
