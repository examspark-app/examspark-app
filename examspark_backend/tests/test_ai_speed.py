"""Unit tests — normal-mode token cap + brevity line."""
from __future__ import annotations

from app.constants.ai_speed import (
    DEEP_MAX_TOKENS,
    NORMAL_MAX_TOKENS,
    brevity_user_line,
    max_tokens_for_mode,
)


def test_normal_max_tokens_is_512():
    assert NORMAL_MAX_TOKENS == 512
    assert max_tokens_for_mode("normal") == 512


def test_deep_max_tokens_unchanged():
    assert DEEP_MAX_TOKENS == 2048
    assert max_tokens_for_mode("deep") == 2048


def test_brevity_only_for_normal():
    assert "SPEED" in brevity_user_line("normal")
    assert brevity_user_line("deep") == ""
