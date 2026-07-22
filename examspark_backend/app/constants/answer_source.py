"""Server-derived answer_source + confidence (never trust the LLM text)."""
from __future__ import annotations

from typing import Literal, Optional

AnswerSource = Literal["RAG", "PYQ", "KB", "WEB", "MIXED", "NO_MATCH", "VISION"]
Confidence = Literal["HIGH", "MEDIUM", "LOW"]

RAG: AnswerSource = "RAG"
PYQ: AnswerSource = "PYQ"
KB: AnswerSource = "KB"
WEB: AnswerSource = "WEB"
MIXED: AnswerSource = "MIXED"
NO_MATCH: AnswerSource = "NO_MATCH"
VISION: AnswerSource = "VISION"

HIGH: Confidence = "HIGH"
MEDIUM: Confidence = "MEDIUM"
LOW: Confidence = "LOW"

# Tunable cosine thresholds (best chunk similarity).
CONFIDENCE_HIGH_MIN = 0.55
CONFIDENCE_MEDIUM_MIN = 0.35


def _best_similarity(sources_meta: list[dict] | None) -> float | None:
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
    return best


def derive_confidence(sources_meta: list[dict] | None) -> Confidence:
    """Ask AI confidence from best retrieval similarity; no scores → LOW."""
    best = _best_similarity(sources_meta)
    if best is None:
        return LOW
    if best >= CONFIDENCE_HIGH_MIN:
        return HIGH
    if best >= CONFIDENCE_MEDIUM_MIN:
        return MEDIUM
    return LOW


def derive_ask_ai_source(
    sources_meta: list[dict] | None,
    context_blocks: list[str] | None,
) -> AnswerSource:
    """Lecture Ask AI: RAG when context retrieved; else NO_MATCH."""
    if context_blocks:
        return RAG
    if sources_meta:
        return RAG
    return NO_MATCH


def derive_home_ai_source(
    sources_meta: list[dict] | None,
    context_blocks: list[str] | None,
) -> AnswerSource:
    """Home: RAG if open-lecture hits; else KB (Internal Knowledge stand-in)."""
    if sources_meta or context_blocks:
        return RAG
    return KB


def derive_home_ai_confidence(
    sources_meta: list[dict] | None,
    answer_source: AnswerSource,
) -> Optional[Confidence]:
    """Confidence only when RAG retrieval ran; KB-only → null."""
    if answer_source != RAG:
        return None
    return derive_confidence(sources_meta)
