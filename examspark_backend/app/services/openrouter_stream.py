"""OpenRouter streaming chat helper — additive SSE path only.

Existing JSON callers keep using non-stream httpx.post.
"""
from __future__ import annotations

import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.config import AIConfig
from app.constants.ai_response_status import API_ERROR, NETWORK_ERROR, TIMEOUT

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


class OpenRouterStreamError(Exception):
    def __init__(
        self,
        message: str,
        *,
        status_code: int = 502,
        result_status: str = API_ERROR,
    ):
        self.status_code = status_code
        self.result_status = result_status
        super().__init__(message)


def parse_sse_data_line(line: str) -> dict[str, Any] | None:
    """Parse one OpenRouter SSE payload line (after 'data: ')."""
    payload = line.strip()
    if not payload or payload == "[DONE]":
        return None
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return None


def extract_delta_text(chunk: dict[str, Any]) -> str:
    choices = chunk.get("choices") or []
    if not choices:
        return ""
    delta = choices[0].get("delta") or {}
    content = delta.get("content")
    return content if isinstance(content, str) else ""


def format_sse(payload: dict[str, Any]) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


async def stream_chat_completions(
    messages: list[dict[str, str]],
    *,
    temperature: float,
    max_tokens: int,
    timeout: float = 90.0,
) -> AsyncIterator[str]:
    """Yield text deltas from OpenRouter with stream=true."""
    if not AIConfig.openrouter_configured():
        raise OpenRouterStreamError(
            "OPENROUTER_API_KEY not configured on the server.",
            status_code=500,
            result_status=API_ERROR,
        )

    headers = {
        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }
    body = {
        "model": AIConfig.AI_CHAT_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": True,
    }

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream(
                "POST",
                _OPENROUTER_URL,
                headers=headers,
                json=body,
            ) as response:
                if response.status_code != 200:
                    err_body = (await response.aread())[:300].decode(
                        "utf-8", errors="replace"
                    )
                    raise OpenRouterStreamError(
                        f"OpenRouter stream failed: {response.status_code} {err_body}",
                        status_code=502,
                        result_status=API_ERROR,
                    )
                async for line in response.aiter_lines():
                    if not line:
                        continue
                    if line.startswith(":"):
                        continue
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    chunk = parse_sse_data_line(data_str)
                    if chunk is None:
                        continue
                    text = extract_delta_text(chunk)
                    if text:
                        yield text
    except OpenRouterStreamError:
        raise
    except httpx.TimeoutException as e:
        raise OpenRouterStreamError(
            "OpenRouter stream timed out.",
            status_code=504,
            result_status=TIMEOUT,
        ) from e
    except httpx.RequestError as e:
        raise OpenRouterStreamError(
            f"OpenRouter stream network error: {e}",
            status_code=502,
            result_status=NETWORK_ERROR,
        ) from e
