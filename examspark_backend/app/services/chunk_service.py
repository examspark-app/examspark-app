"""Plain-text chunking for RAG index — no AI calls.

Chunk text is stored in R2; Postgres keeps hash + embedding only
(PROJECT_CORE_RULES.md).
"""
from __future__ import annotations

import hashlib
import re


_DEFAULT_TARGET_CHARS = 700
_DEFAULT_OVERLAP_CHARS = 80


def chunk_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def chunk_text(
    text: str,
    *,
    target_chars: int = _DEFAULT_TARGET_CHARS,
    overlap_chars: int = _DEFAULT_OVERLAP_CHARS,
) -> list[str]:
    """Split into overlapping chunks sized ~target_chars. Empty → []."""
    cleaned = re.sub(r"\s+", " ", (text or "").strip())
    if not cleaned:
        return []

    if len(cleaned) <= target_chars:
        return [cleaned]

    chunks: list[str] = []
    start = 0
    n = len(cleaned)
    while start < n:
        end = min(start + target_chars, n)
        if end < n:
            # Prefer break at space near the end of the window.
            space = cleaned.rfind(" ", start + target_chars // 2, end)
            if space > start:
                end = space
        piece = cleaned[start:end].strip()
        if piece:
            chunks.append(piece)
        if end >= n:
            break
        start = max(end - overlap_chars, start + 1)

    return chunks
