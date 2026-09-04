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

    errors: list[str] = []

    # 1. Try OpenRouter if configured
    if AIConfig.openrouter_configured():
        model = AIConfig.AI_EMBEDDING_MODEL
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    _OPENROUTER_EMBED_URL,
                    headers={
                        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={"model": model, "input": texts},
                )
            if response.status_code == 200:
                data = response.json()
                items = data.get("data") or []
                if len(items) == len(texts):
                    vectors: list[list[float]] = []
                    for item in sorted(items, key=lambda x: x.get("index", 0)):
                        vec = item.get("embedding") or []
                        if len(vec) == _EXPECTED_DIMS:
                            vectors.append(vec)
                    if len(vectors) == len(texts):
                        return vectors
            errors.append(f"OpenRouter status {response.status_code}: {response.text[:120]}")
        except Exception as err:
            errors.append(f"OpenRouter exception: {err}")

    # 2. Fallback to direct OpenAI if configured
    if AIConfig.openai_configured():
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    "https://api.openai.com/v1/embeddings",
                    headers={
                        "Authorization": f"Bearer {AIConfig.OPENAI_API_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={"model": "text-embedding-3-small", "input": texts},
                )
            if response.status_code == 200:
                data = response.json()
                items = data.get("data") or []
                if len(items) == len(texts):
                    vectors = []
                    for item in sorted(items, key=lambda x: x.get("index", 0)):
                        vec = item.get("embedding") or []
                        if len(vec) == _EXPECTED_DIMS:
                            vectors.append(vec)
                    if len(vectors) == len(texts):
                        return vectors
            errors.append(f"OpenAI status {response.status_code}: {response.text[:120]}")
        except Exception as err:
            errors.append(f"OpenAI exception: {err}")

    raise EmbeddingError(f"All embedding providers failed: {' | '.join(errors)}")


async def embed_query(text: str) -> list[float]:
    cached = get_cached_embedding(text)
    if cached is not None:
        return cached
    vectors = await embed_texts([text])
    vec = vectors[0]
    set_cached_embedding(text, vec)
    return vec
