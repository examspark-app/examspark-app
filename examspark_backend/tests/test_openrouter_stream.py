"""Unit tests — OpenRouter SSE line parsing helpers."""
from __future__ import annotations

from app.services.openrouter_stream import (
    extract_delta_text,
    format_sse,
    parse_sse_data_line,
)


def test_parse_sse_done():
    assert parse_sse_data_line("[DONE]") is None
    assert parse_sse_data_line("") is None


def test_extract_delta_text():
    chunk = {"choices": [{"delta": {"content": "Hello"}}]}
    assert extract_delta_text(chunk) == "Hello"
    assert extract_delta_text({"choices": [{"delta": {}}]}) == ""


def test_format_sse():
    out = format_sse({"type": "token", "text": "Hi"})
    assert out.startswith("data: ")
    assert out.endswith("\n\n")
    assert '"type": "token"' in out or '"type":"token"' in out
