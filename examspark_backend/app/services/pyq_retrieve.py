"""PYQ similarity retrieval — metadata tags only (PROJECT_CORE_RULES §6).

Fast path: ONE embed + local cosine scan (smoke bank). Skip broken IVFFlat RPC
by default. Similarity threshold is internal — never show raw scores to students.

Never return original question text, options, or answer keys.
"""
from __future__ import annotations

import logging
import math
import os
import re
import time
from typing import Any

from app.services.embedding_service import EmbeddingError, embed_query
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

# Floor for verified match. Topic-label vectors rarely hit 0.80 vs student Qs.
PYQ_MATCH_THRESHOLD = 0.45
_LOCAL_SCAN_CAP = 500

_USE_RPC = os.getenv("EXAMSPARK_PYQ_USE_RPC", "").strip().lower() in (
    "1",
    "true",
    "yes",
)

_bank_cache: list[dict[str, Any]] | None = None
_bank_cache_mono: float = 0.0
_BANK_TTL_SEC = 300.0

_QUESTION_PREFIX = re.compile(
    r"^(?:"
    r"what\s+is|what\s+are|what's|whats|"
    r"explain|define|describe|tell\s+me\s+about|"
    r"how\s+does|how\s+do|how\s+many|why\s+is|why\s+do|"
    r"give\s+me|can\s+you\s+explain"
    r")\s+",
    re.IGNORECASE,
)


def _load_bank_rows() -> list[dict[str, Any]]:
    global _bank_cache, _bank_cache_mono
    now = time.monotonic()
    if _bank_cache is not None and (now - _bank_cache_mono) < _BANK_TTL_SEC:
        return _bank_cache
    sb = get_supabase_admin()
    res = (
        sb.table("exam_pyqs")
        .select("id,exam,year,subject,chapter,weightage_stars,embedding")
        .not_.is_("embedding", "null")
        .limit(_LOCAL_SCAN_CAP)
        .execute()
    )
    _bank_cache = list(res.data or [])
    _bank_cache_mono = now
    return _bank_cache


def clear_pyq_bank_cache() -> None:
    """Tests / after seed --force."""
    global _bank_cache, _bank_cache_mono
    _bank_cache = None
    _bank_cache_mono = 0.0


def _topic_focus(query: str) -> str | None:
    """Strip common question wrappers so embedding matches topic_label better."""
    q = (query or "").strip()
    if not q:
        return None
    focused = _QUESTION_PREFIX.sub("", q).strip(" ?!.:;-")
    if not focused or focused.lower() == q.lower():
        return None
    if len(focused) < 3 or len(focused) > 80:
        return None
    return focused


def _embed_text_for_match(query: str) -> str:
    return _topic_focus(query) or (query or "").strip()


def _embedding_as_pgvector(embedding: list[float]) -> str:
    return "[" + ",".join(str(float(x)) for x in embedding) + "]"


def _parse_embedding(raw: Any) -> list[float] | None:
    if isinstance(raw, list) and raw:
        try:
            return [float(x) for x in raw]
        except (TypeError, ValueError):
            return None
    if isinstance(raw, str):
        s = raw.strip()
        if not s.startswith("["):
            return None
        try:
            return [float(x) for x in s.strip("[]").split(",") if x.strip()]
        except ValueError:
            return None
    return None


def _cosine(a: list[float], b: list[float]) -> float:
    if len(a) != len(b) or not a:
        return 0.0
    dot = 0.0
    na = 0.0
    nb = 0.0
    for x, y in zip(a, b):
        dot += x * y
        na += x * x
        nb += y * y
    if na <= 0.0 or nb <= 0.0:
        return 0.0
    return dot / (math.sqrt(na) * math.sqrt(nb))


def _row_to_match(
    r: dict[str, Any], similarity: float | None = None
) -> dict[str, Any] | None:
    exam = (r.get("exam") or "").strip()
    year = r.get("year")
    if not exam or year is None:
        return None
    item: dict[str, Any] = {
        "exam": exam,
        "year": int(year) if not isinstance(year, int) else year,
        "subject": (r.get("subject") or "").strip() or None,
        "chapter": (r.get("chapter") or "").strip() or None,
        "similarity": similarity if similarity is not None else r.get("similarity"),
    }
    stars = r.get("weightage_stars")
    if stars is not None:
        try:
            item["weightage_stars"] = int(stars)
        except (TypeError, ValueError):
            pass
    if r.get("id"):
        item["id"] = str(r["id"])
    return item


def _match_via_rpc(
    embedding: list[float],
    *,
    threshold: float,
    limit: int,
) -> list[dict[str, Any]]:
    try:
        sb = get_supabase_admin()
        res = sb.rpc(
            "match_exam_pyqs",
            {
                "p_query_embedding": _embedding_as_pgvector(embedding),
                "p_match_count": limit,
                "p_match_threshold": float(threshold),
            },
        ).execute()
        rows = list(res.data or [])
    except Exception as e:  # noqa: BLE001
        logger.warning("match_exam_pyqs failed: %s", e)
        return []

    out: list[dict[str, Any]] = []
    for r in rows:
        if not isinstance(r, dict):
            continue
        item = _row_to_match(r)
        if item:
            out.append(item)
    return out


def _match_via_local_scan(
    embedding: list[float],
    *,
    threshold: float,
    limit: int,
) -> list[dict[str, Any]]:
    try:
        rows = _load_bank_rows()
    except Exception as e:  # noqa: BLE001
        logger.warning("PYQ local scan failed: %s", e)
        return []

    scored: list[tuple[float, dict[str, Any]]] = []
    for r in rows:
        if not isinstance(r, dict):
            continue
        stored = _parse_embedding(r.get("embedding"))
        if not stored or len(stored) != len(embedding):
            continue
        sim = _cosine(embedding, stored)
        if sim < threshold:
            continue
        item = _row_to_match(r, similarity=round(sim, 4))
        if item:
            scored.append((sim, item))

    scored.sort(key=lambda t: t[0], reverse=True)
    return [item for _, item in scored[:limit]]


async def match_pyqs_for_query(
    query: str,
    *,
    threshold: float = PYQ_MATCH_THRESHOLD,
    limit: int = 3,
) -> list[dict[str, Any]]:
    """
    Return verified PYQ metadata rows above threshold.

    Each row: {exam, year, subject?, chapter?, weightage_stars?, similarity?, id?}
    Never include question_text / options / answer_key.
    """
    q = (query or "").strip()
    if not q:
        return []

    embed_text = _embed_text_for_match(q)
    try:
        embedding = await embed_query(embed_text)
    except EmbeddingError as e:
        logger.warning("PYQ embed failed: %s", e)
        return []
    except Exception as e:  # noqa: BLE001
        logger.warning("PYQ embed unexpected: %s", e)
        return []

    cap = max(1, min(int(limit or 3), 10))
    thr = float(threshold)

    local = _match_via_local_scan(embedding, threshold=thr, limit=cap)
    if local:
        return local
    if _USE_RPC:
        return _match_via_rpc(embedding, threshold=thr, limit=cap)
    return []


def format_verified_pyq_line(match: dict[str, Any]) -> str:
    """Student-facing metadata only — never show raw similarity scores."""
    exam = (match.get("exam") or "").strip() or "Exam"
    year = match.get("year")
    year_s = str(year) if year is not None else ""
    parts = [f"Related: {exam} {year_s}".strip()]
    subject = (match.get("subject") or "").strip()
    chapter = (match.get("chapter") or "").strip()
    if subject:
        parts.append(subject)
    if chapter:
        parts.append(chapter)
    return " · ".join(parts)


def format_exam_focus_line(match: dict[str, Any]) -> str:
    """Important Qs Focus line — exam/year/subject/chapter (+ stars for model)."""
    exam = (match.get("exam") or "").strip() or "Exam"
    year = match.get("year")
    year_s = str(year) if year is not None else ""
    parts = [f"Focus: {exam} {year_s}".strip()]
    subject = (match.get("subject") or "").strip()
    chapter = (match.get("chapter") or "").strip()
    if subject:
        parts.append(subject)
    if chapter:
        parts.append(chapter)
    stars = match.get("weightage_stars")
    if isinstance(stars, (int, float)) and int(stars) > 0:
        parts.append(f"weightage {int(stars)}/5")
    return " · ".join(parts)


def format_exam_focus_block(matches: list[dict[str, Any]] | None) -> str:
    """Prompt block for Important Qs — metadata only, no paper text."""
    rows = [m for m in (matches or []) if isinstance(m, dict)]
    if not rows:
        return ""
    # High weightage first (chance bias for model + derive).
    rows = sorted(
        rows,
        key=lambda m: int(m.get("weightage_stars") or 0),
        reverse=True,
    )
    lines = [format_exam_focus_line(m) for m in rows]
    body = "\n".join(f"- {line}" for line in lines if line.strip())
    return (
        "EXAM FOCUS (metadata only — weightage 5 = higher chance of covering that chapter):\n"
        f"{body}\n"
        "Bias questions toward high-weightage chapters. "
        "Never quote original exam question text, options, or answer keys."
    )


def format_verified_pyq_block(matches: list[dict[str, Any]] | None) -> str:
    rows = [m for m in (matches or []) if isinstance(m, dict)]
    if not rows:
        return (
            "VERIFIED PYQ: none for this question.\n"
            "Do NOT mention PYQs, invent exam years, or write that no PYQ was found."
        )
    lines = [format_verified_pyq_line(m) for m in rows]
    body = "\n".join(f"- {line}" for line in lines if line.strip())
    return (
        "VERIFIED PYQ MATCHES (from ExamSpark retrieval — use ONLY these tags):\n"
        f"{body}\n"
        "Include a short Related PYQ section using ONLY the lines above. "
        "Do NOT quote original exam question text, options, or answer keys."
    )
