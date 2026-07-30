"""In-process TTL caches for embeddings + SUCCESS answers (Phase 1).

Redis later. Cache hit → no second LLM call and no second credit deduct.
"""
from __future__ import annotations

import hashlib
import re
import time
from typing import Any


_EMBED_TTL_SEC = 3600.0
_ANSWER_TTL_SEC = 1800.0
_MAX_EMBED_ENTRIES = 256
_MAX_ANSWER_ENTRIES = 128

_embed_cache: dict[str, tuple[float, list[float]]] = {}
_answer_cache: dict[str, tuple[float, dict[str, Any]]] = {}
# Soft semantic index: user_id -> list of (expires, query, payload)
_answer_by_user: dict[str, list[tuple[float, str, dict[str, Any]]]] = {}
_MAX_USER_ANSWER_ROWS = 24

_WS = re.compile(r"\s+")


def normalize_query(text: str) -> str:
    return _WS.sub(" ", (text or "").strip().lower())


def _hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def embedding_cache_key(text: str) -> str:
    return _hash_text(normalize_query(text))


def answer_cache_key(
    *,
    user_id: str,
    mode: str,
    query: str,
    lecture_id: str | None,
    conversation_language: str | None,
    feature: str,
    study_chip: str | None = None,
) -> str:
    raw = "|".join(
        [
            feature,
            user_id,
            mode,
            lecture_id or "",
            conversation_language or "",
            study_chip or "",
            normalize_query(query),
        ]
    )
    return _hash_text(raw)


def get_cached_embedding(text: str) -> list[float] | None:
    key = embedding_cache_key(text)
    entry = _embed_cache.get(key)
    if not entry:
        return None
    expires, vec = entry
    if time.time() > expires:
        _embed_cache.pop(key, None)
        return None
    return vec


def set_cached_embedding(text: str, vector: list[float]) -> None:
    if len(_embed_cache) >= _MAX_EMBED_ENTRIES:
        # Drop oldest ~half by expiry
        for k, _ in sorted(_embed_cache.items(), key=lambda kv: kv[1][0])[
            : max(1, _MAX_EMBED_ENTRIES // 4)
        ]:
            _embed_cache.pop(k, None)
    _embed_cache[embedding_cache_key(text)] = (
        time.time() + _EMBED_TTL_SEC,
        vector,
    )


def get_cached_answer(key: str) -> dict[str, Any] | None:
    entry = _answer_cache.get(key)
    if not entry:
        return None
    expires, payload = entry
    if time.time() > expires:
        _answer_cache.pop(key, None)
        return None
    return dict(payload)


def find_semantic_cached_answer(
    *,
    user_id: str,
    query: str,
    feature: str = "home_ai",
    threshold: float = 0.72,
) -> dict[str, Any] | None:
    """Reuse a prior SUCCESS answer when the new question is near-duplicate."""
    from app.services.home_ai_followup import find_similar_in_pairs

    rows = _answer_by_user.get(user_id) or []
    now = time.time()
    alive: list[tuple[float, str, dict[str, Any]]] = []
    candidates: list[tuple[str, dict]] = []
    for exp, q, payload in rows:
        if now > exp:
            continue
        if (payload.get("_feature") or "home_ai") != feature:
            alive.append((exp, q, payload))
            continue
        alive.append((exp, q, payload))
        candidates.append((q, payload))
    _answer_by_user[user_id] = alive[-_MAX_USER_ANSWER_ROWS:]
    hit = find_similar_in_pairs(query, candidates, threshold=threshold)
    if not hit:
        return None
    return {k: v for k, v in hit.items() if not str(k).startswith("_")}


def set_cached_answer(key: str, payload: dict[str, Any]) -> None:
    if len(_answer_cache) >= _MAX_ANSWER_ENTRIES:
        for k, _ in sorted(_answer_cache.items(), key=lambda kv: kv[1][0])[
            : max(1, _MAX_ANSWER_ENTRIES // 4)
        ]:
            _answer_cache.pop(k, None)
    # Never store credit fields — replay uses credits_charged=0
    clean = {
        k: v
        for k, v in payload.items()
        if k not in ("credits_charged", "new_balance")
    }
    _answer_cache[key] = (time.time() + _ANSWER_TTL_SEC, clean)

    user_id = str(clean.get("_user_id") or "")
    query = str(clean.get("_query") or "")
    if user_id and query:
        bucket = _answer_by_user.setdefault(user_id, [])
        bucket.append((time.time() + _ANSWER_TTL_SEC, query, dict(clean)))
        if len(bucket) > _MAX_USER_ANSWER_ROWS:
            _answer_by_user[user_id] = bucket[-_MAX_USER_ANSWER_ROWS:]


def clear_performance_caches_for_tests() -> None:
    _embed_cache.clear()
    _answer_cache.clear()
    _answer_by_user.clear()
