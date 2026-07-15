"""Normal-mode reply length / brevity — faster Home AI + Ask AI.

Deep mode stays fuller. Does not change credits or models.
"""
from __future__ import annotations

NORMAL_MAX_TOKENS = 512
DEEP_MAX_TOKENS = 2048

_BREVITY_NORMAL = (
    "SPEED (normal mode): Lead with Direct Answer in the first sentences. "
    "Omit empty sections. Keep explanations tight (short paragraphs). "
    "No essay unless the student asks for long / detailed / deep answer."
)


def max_tokens_for_mode(mode: str) -> int:
    return DEEP_MAX_TOKENS if mode == "deep" else NORMAL_MAX_TOKENS


def brevity_user_line(mode: str) -> str:
    """Append to user message for normal mode only; empty for deep."""
    if mode == "deep":
        return ""
    return _BREVITY_NORMAL
