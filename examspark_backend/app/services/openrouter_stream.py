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


_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"


async def _stream_single_provider(
    url: str,
    headers: dict[str, str],
    body: dict[str, Any],
    timeout: float,
) -> AsyncIterator[str]:
    async with httpx.AsyncClient(timeout=timeout) as client:
        async with client.stream("POST", url, headers=headers, json=body) as response:
            if response.status_code != 200:
                err_body = (await response.aread())[:300].decode("utf-8", errors="replace")
                raise OpenRouterStreamError(
                    f"Streaming provider HTTP {response.status_code}: {err_body}",
                    status_code=502,
                    result_status=API_ERROR,
                )
            async for line in response.aiter_lines():
                if not line or line.startswith(":"):
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


async def stream_chat_completions(
    messages: list[dict[str, str]],
    *,
    temperature: float = 0.7,
    max_tokens: int = 1200,
    model: str | None = None,
    timeout: float = 90.0,
) -> AsyncIterator[str]:
    """Yield text deltas with automatic Groq <-> OpenRouter resilience."""
    candidates: list[tuple[str, str, dict[str, str], str]] = []

    has_groq = AIConfig.groq_configured()
    has_or = AIConfig.openrouter_configured()

    if not has_groq and not has_or:
        raise OpenRouterStreamError(
            "Neither GROQ_API_KEY nor OPENROUTER_API_KEY configured on server.",
            status_code=500,
            result_status=API_ERROR,
        )

    # If a specific OpenRouter model was requested and it's not groq, try OpenRouter first
    is_explicit_or = model and ("qwen" in model.lower() or "llama" in model.lower()) and "groq" not in model.lower() and has_or

    if is_explicit_or:
        candidates.append((
            "openrouter",
            _OPENROUTER_URL,
            {"Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}", "Content-Type": "application/json"},
            model or AIConfig.AI_CHAT_MODEL,
        ))
        if has_groq:
            candidates.append((
                "groq",
                _GROQ_URL,
                {"Authorization": f"Bearer {AIConfig.GROQ_API_KEY}", "Content-Type": "application/json"},
                AIConfig.GROQ_CHAT_MODEL,
            ))
    else:
        # Groq first for blazing speed (<200ms latency), OpenRouter fallback
        if has_groq:
            candidates.append((
                "groq",
                _GROQ_URL,
                {"Authorization": f"Bearer {AIConfig.GROQ_API_KEY}", "Content-Type": "application/json"},
                AIConfig.GROQ_CHAT_MODEL,
            ))
        if has_or:
            candidates.append((
                "openrouter",
                _OPENROUTER_URL,
                {"Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}", "Content-Type": "application/json"},
                model or AIConfig.AI_CHAT_MODEL,
            ))

    last_err: Exception | None = None
    yielded_any = False

    for prov_name, url, headers, m_name in candidates:
        body = {
            "model": m_name,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }
        prov_timeout = min(timeout, 35.0) if len(candidates) > 1 else timeout
        try:
            async for delta in _stream_single_provider(url, headers, body, prov_timeout):
                yielded_any = True
                yield delta
            if yielded_any:
                return
        except Exception as e:
            last_err = e
            if yielded_any:
                # If stream already began yielding, we cannot cleanly switch providers mid-stream
                raise
            # If no tokens yielded yet, fall through smoothly to next provider

    if not yielded_any:
        if isinstance(last_err, OpenRouterStreamError):
            raise last_err
        raise OpenRouterStreamError(
            f"All streaming providers failed: {last_err}",
            status_code=502,
            result_status=API_ERROR,
        )
