"""OpenRouter embeddings — openai/text-embedding-3-small (1536 dims).

Matches rag_documents.embedding vector(1536) in schema.sql. Uses the same
OPENROUTER_API_KEY as Qwen text/vision (no new vendor).
"""
from __future__ import annotations

import httpx

from app.config import AIConfig
from app.services.ai_performance_cache import (
    get_cached_embedding,
    set_cached_embedding,
)

_OPENROUTER_EMBED_URL = "https://openrouter.ai/api/v1/embeddings"
_EXPECTED_DIMS = 1536


class EmbeddingError(Exception):
    pass


async def embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed one or more strings. Returns one vector per input string."""
    if not texts:
        return []
    if not AIConfig.openrouter_configured():
        raise EmbeddingError("OPENROUTER_API_KEY not configured on the server.")

    model = AIConfig.AI_EMBEDDING_MODEL
    async with httpx.AsyncClient() as client:
        response = await client.post(
            _OPENROUTER_EMBED_URL,
            headers={
                "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={"model": model, "input": texts},
            timeout=90.0,
        )

    if response.status_code != 200:
        raise EmbeddingError(
            f"Embedding ({model}) failed: {response.status_code} {response.text[:300]}"
        )

    data = response.json()
    items = data.get("data") or []
    if len(items) != len(texts):
        raise EmbeddingError(
            f"Embedding returned {len(items)} vectors for {len(texts)} inputs."
        )

    vectors: list[list[float]] = []
    for item in sorted(items, key=lambda x: x.get("index", 0)):
        vec = item.get("embedding") or []
        if len(vec) != _EXPECTED_DIMS:
            raise EmbeddingError(
                f"Expected {_EXPECTED_DIMS}-dim embedding, got {len(vec)}."
            )
        vectors.append(vec)
    return vectors


async def embed_query(text: str) -> list[float]:
    cached = get_cached_embedding(text)
    if cached is not None:
        return cached
    vectors = await embed_texts([text])
    vec = vectors[0]
    set_cached_embedding(text, vec)
    return vec
