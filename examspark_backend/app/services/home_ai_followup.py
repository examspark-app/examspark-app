"""Follow-up detection + soft semantic query similarity (Phase 4C harden)."""
from __future__ import annotations

import re
from typing import Iterable

_FOLLOW_UP_HINTS = (
    r"\bexplain in hindi\b",
    r"\bhindi mein\b",
    r"\bin hindi\b",
    r"\bclass\s*\d+\b",
    r"\bmore examples?\b",
    r"\bgive examples?\b",
    r"\bsimplify\b",
    r"\beasier\b",
    r"\bwhy\??\s*$",
    r"\bhow\??\s*$",
    r"\bexplain more\b",
    r"\bin detail\b",
    r"\btranslate\b",
    r"\bbinglish\b",
    r"\bbengali\b",
)

_STOP = frozenset(
    "a an the is are was were be to of in on for and or what is meaning explain "
    "please tell me about define".split()
)


def looks_like_knowledge_follow_up(query: str) -> bool:
    q = (query or "").strip().lower()
    if len(q) < 3:
        return True
    if len(q.split()) <= 4 and q.endswith("?"):
        # "Why?" / "How?" / "And then?"
        if re.match(r"^(why|how|what|and|then|ok|yes)\b", q):
            return True
    for pat in _FOLLOW_UP_HINTS:
        if re.search(pat, q):
            return True
    return False


def significant_tokens(text: str) -> set[str]:
    raw = re.findall(r"[a-z0-9\u0900-\u097f]{2,}", (text or "").lower())
    return {t for t in raw if t not in _STOP}


def token_jaccard(a: str, b: str) -> float:
    ta, tb = significant_tokens(a), significant_tokens(b)
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    union = len(ta | tb)
    return inter / union if union else 0.0


def is_semantically_similar(a: str, b: str, *, threshold: float = 0.72) -> bool:
    """Soft similarity for duplicate Ask cost avoidance (not embeddings)."""
    na = re.sub(r"\s+", " ", (a or "").strip().lower())
    nb = re.sub(r"\s+", " ", (b or "").strip().lower())
    if not na or not nb:
        return False
    if na == nb:
        return True
    # Containment for "photosynthesis" vs "what is photosynthesis meaning"
    if na in nb or nb in na:
        shorter, longer = (na, nb) if len(na) <= len(nb) else (nb, na)
        if len(shorter) >= 8 and len(shorter) / max(len(longer), 1) >= 0.45:
            return True
    return token_jaccard(na, nb) >= threshold


def find_similar_in_pairs(
    query: str, candidates: Iterable[tuple[str, dict]], *, threshold: float = 0.72
) -> dict | None:
    """candidates: (stored_query, payload). Returns best payload or None."""
    best: tuple[float, dict] | None = None
    for stored_q, payload in candidates:
        score = token_jaccard(query, stored_q)
        if is_semantically_similar(query, stored_q, threshold=threshold):
            if best is None or score > best[0]:
                best = (score, payload)
    return best[1] if best else None
