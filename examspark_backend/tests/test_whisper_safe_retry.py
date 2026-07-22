"""Groq Whisper transient retry — P0 reliability (no product change)."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from app.services.whisper_service import (
    WhisperTranscriptionError,
    _call_groq_whisper,
    _is_retryable_http_status,
    _is_transient_transport,
)


def test_retryable_http_status():
    assert _is_retryable_http_status(429) is True
    assert _is_retryable_http_status(500) is True
    assert _is_retryable_http_status(503) is True
    assert _is_retryable_http_status(400) is False
    assert _is_retryable_http_status(401) is False
    assert _is_retryable_http_status(200) is False


def test_transient_transport_types():
    assert _is_transient_transport(httpx.TimeoutException("t")) is True
    assert _is_transient_transport(httpx.ConnectError("c")) is True
    assert _is_transient_transport(ValueError("x")) is False


@pytest.mark.asyncio
async def test_call_groq_retries_timeout_then_succeeds():
    ok = MagicMock()
    ok.status_code = 200
    ok.json.return_value = {"text": "hello world from lecture notes enough chars"}

    client = MagicMock()
    client.post = AsyncMock(
        side_effect=[httpx.TimeoutException("slow"), ok]
    )

    with (
        patch("app.services.whisper_service.AIConfig.groq_configured", return_value=True),
        patch("app.services.whisper_service.AIConfig.GROQ_API_KEY", "k"),
        patch("app.services.whisper_service.asyncio.sleep", new_callable=AsyncMock),
    ):
        payload = await _call_groq_whisper(client, b"audio", "a.webm", "whisper-large-v3-turbo")

    assert payload["text"].startswith("hello")
    assert client.post.await_count == 2


@pytest.mark.asyncio
async def test_call_groq_does_not_retry_http_400():
    bad = MagicMock()
    bad.status_code = 400
    bad.text = "bad request"

    client = MagicMock()
    client.post = AsyncMock(return_value=bad)

    with (
        patch("app.services.whisper_service.AIConfig.groq_configured", return_value=True),
        patch("app.services.whisper_service.AIConfig.GROQ_API_KEY", "k"),
        patch("app.services.whisper_service.asyncio.sleep", new_callable=AsyncMock) as sleep,
    ):
        with pytest.raises(WhisperTranscriptionError) as exc:
            await _call_groq_whisper(client, b"audio", "a.webm", "whisper-large-v3-turbo")

    assert exc.value.status_code == 400
    assert exc.value.retryable is False
    assert client.post.await_count == 1
    sleep.assert_not_awaited()


@pytest.mark.asyncio
async def test_call_groq_retries_429_then_gives_up():
    rate = MagicMock()
    rate.status_code = 429
    rate.text = "rate limited"

    client = MagicMock()
    client.post = AsyncMock(return_value=rate)

    with (
        patch("app.services.whisper_service.AIConfig.groq_configured", return_value=True),
        patch("app.services.whisper_service.AIConfig.GROQ_API_KEY", "k"),
        patch("app.services.whisper_service.asyncio.sleep", new_callable=AsyncMock) as sleep,
    ):
        with pytest.raises(WhisperTranscriptionError) as exc:
            await _call_groq_whisper(client, b"audio", "a.webm", "whisper-large-v3-turbo")

    assert exc.value.retryable is True
    assert client.post.await_count == 3  # initial + 2 retries
    assert sleep.await_count == 2
