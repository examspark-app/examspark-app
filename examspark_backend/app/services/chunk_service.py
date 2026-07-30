"""Plain-text chunking for RAG index — no AI calls.

Chunk text is stored in R2; Postgres keeps hash + embedding only
(PROJECT_CORE_RULES.md).
"""
from __future__ import annotations

import hashlib
import re


_DEFAULT_TARGET_CHARS = 700
_DEFAULT_OVERLAP_CHARS = 80
_MIN_LAST_CHUNK_CHARS = 120  # merge a too-small trailing chunk into the prior one


def chunk_hash(text: str) -> str:
    """Hash the NORMALIZED text so identical content (different spacing/
    casing at the edges) doesn't produce two different hashes."""
    normalized = re.sub(r"\s+", " ", (text or "").strip()).lower()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _find_break_point(cleaned: str, start: int, target_end: int) -> int:
    """Prefer a sentence-ending punctuation near the window end so a chunk
    stops at a complete thought (better for embeddings/RAG search quality).
    Falls back to a space, then to the raw window end if neither is found.
    """
    window_start = start + max((target_end - start) // 2, 1)

    # 1) Prefer the last sentence-ending punctuation (. ! ?) followed by a
    #    space, within the second half of the window.
    best_sentence_end = -1
    for match in re.finditer(r"[.!?](?=\s|$)", cleaned[window_start:target_end]):
        best_sentence_end = window_start + match.end()
    if best_sentence_end > start:
        return best_sentence_end

    # 2) Fall back to the nearest space.
    space = cleaned.rfind(" ", window_start, target_end)
    if space > start:
        return space

    # 3) No good break found — just cut at the window end.
    return target_end


def chunk_text(
    text: str,
    *,
    target_chars: int = _DEFAULT_TARGET_CHARS,
    overlap_chars: int = _DEFAULT_OVERLAP_CHARS,
) -> list[str]:
    """Split into overlapping chunks sized ~target_chars. Empty → []।

    Prefers sentence-boundary breaks over mid-sentence cuts, and merges a
    too-small trailing chunk into the previous one so no chunk is left as a
    near-useless fragment for RAG search.
    """
    cleaned = re.sub(r"\s+", " ", (text or "").strip())
    if not cleaned:
        return []

    if len(cleaned) <= target_chars:
        return [cleaned]

    chunks: list[str] = []
    start = 0
    n = len(cleaned)
    while start < n:
        target_end = min(start + target_chars, n)
        end = target_end if target_end >= n else _find_break_point(cleaned, start, target_end)
        piece = cleaned[start:end].strip()
        if piece:
            chunks.append(piece)
        if end >= n:
            break
        start = max(end - overlap_chars, start + 1)

    # Merge a too-small trailing fragment into the previous chunk instead of
    # shipping a near-useless standalone chunk to the RAG index.
    if len(chunks) >= 2 and len(chunks[-1]) < _MIN_LAST_CHUNK_CHARS:
        last = chunks.pop()
        chunks[-1] = f"{chunks[-1]} {last}".strip()

    return chunks