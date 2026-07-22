"""Smart question routing — skip RAG when safe (Phase 1 performance).

Ask AI (lecture): default RAG. web_deferred only for current-affairs hints —
then RAG still runs; Tavily only if gate passes (tavily_gate.py).

Home: direct / rag / web_deferred.

Tavily (live):
- ONLY via route web_deferred (no other trigger points)
- ONLY after RAG + PYQ empty AND LLM current-affairs classifier = YES
- Higher ExamSpark credits + tavily_usage logs
- Never for syllabus / conceptual questions
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

# Soft hint only — routes to web_deferred. Live Tavily still needs classifier + empty RAG/PYQ.
_WEB_HINTS = re.compile(
    r"(?i)\b("
    r"today'?s\s+news|current\s+affairs|latest\s+news|"
    r"breaking\s+news|who\s+won\s+(the\s+)?election|"
    r"latest\s+update\s+on|as\s+of\s+202[4-9]|"
    r"official\s+notification|admit\s+card\s+date|"
    r"neet\s+202[5-9]\s+(result|date|notification)|"
    r"recent\s+(scheme|policy|appointment|cabinet)|"
    r"current\s+(scheme|policy|affairs)"
    r")\b"
)


def route_home_question(query: str, lecture_id: str | None) -> RouteKind:
    """Home: skip embed/vector when no lecture or clearly product/general."""
    q = (query or "").strip()
    if _WEB_HINTS.search(q):
        logger.info(
            "perf_route=web_deferred feature=home_ai "
            "(candidate for Tavily gate — RAG+PYQ+classifier still required)"
        )
        return "web_deferred"

    lid = (lecture_id or "").strip()
    if not lid:
        return "direct"

    if _PRODUCT_GENERAL.search(q):
        return "direct"

    return "rag"


def route_ask_question(query: str) -> RouteKind:
    """Lecture Ask AI: RAG by default; web_deferred only for current-affairs hints."""
    q = (query or "").strip()
    if _WEB_HINTS.search(q):
        logger.info(
            "perf_route=web_deferred feature=ask_ai "
            "(candidate for Tavily gate — RAG runs first; no web for syllabus)"
        )
        return "web_deferred"
    return "rag"


def should_run_rag(route: RouteKind) -> bool:
    """RAG runs for study doubts AND web_deferred (must prove empty before Tavily)."""
    return route in ("rag", "web_deferred")
