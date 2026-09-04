"""OpenAI chat adapter — GPT-4o-mini default for Study AI & English Practice.

Used as primary for English Practice, Study AI text chat,
and as fallback in GlowGuide and Vision pipelines.
"""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import AIConfig

logger = logging.getLogger(__name__)

_OPENAI_URL = "https://api.openai.com/v1/chat/completions"
_TIMEOUT_SECONDS = 60.0


class OpenAIChatError(Exception):
    """User-facing OpenAI call failure."""

    def __init__(self, message: str, status_code: int = 502):
        self.status_code = status_code
        super().__init__(message)


async def call_openai_chat(
    messages: list[dict[str, Any]],
    *,
    model: str | None = None,
    temperature: float = 0.45,
    max_tokens: int = 1200,
    response_format: dict[str, str] | None = None,
) -> str:
    """Single non-streaming OpenAI chat completion.

    Returns the assistant's text content.
    """
    if not AIConfig.openai_configured():
        raise OpenAIChatError("OPENAI_API_KEY not configured on the server.", 500)

    body: dict[str, Any] = {
        "model": model or AIConfig.OPENAI_CHAT_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    if response_format:
        body["response_format"] = response_format

    async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
        try:
            response = await client.post(
                _OPENAI_URL,
                headers={
                    "Authorization": f"Bearer {AIConfig.OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
        except (httpx.TimeoutException, httpx.RequestError) as error:
            raise OpenAIChatError(
                "OpenAI network error. Please try again."
            ) from error

    if response.status_code != 200:
        raise OpenAIChatError(
            f"OpenAI failed: {response.status_code} {response.text[:300]}",
            502,
        )

    try:
        choices = response.json().get("choices") or []
        return (choices[0].get("message") or {}).get("content") or ""
    except (KeyError, IndexError, TypeError) as error:
        raise OpenAIChatError("OpenAI returned no answer.", 502) from error


async def call_openai_vision(
    messages: list[dict[str, Any]],
    *,
    model: str | None = None,
    max_tokens: int = 4096,
) -> str:
    """OpenAI vision call — same endpoint, image URLs in messages."""
    return await call_openai_chat(
        messages,
        model=model or AIConfig.OPENAI_VISION_MODEL,
        max_tokens=max_tokens,
        temperature=0.2,
    )
