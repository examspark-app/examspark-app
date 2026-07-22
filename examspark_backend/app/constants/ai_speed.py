"""Normal-mode reply length / brevity — faster Home AI + Ask AI.

Deep mode stays fuller. Does not change credits or models.
"""
from __future__ import annotations

# Normal: room for visuals + medium Maths/Science. Deep: hard Physics /
# multi-step equations / long syllabus without cutting mid-answer.
NORMAL_MAX_TOKENS = 2048
DEEP_MAX_TOKENS = 4096

_BREVITY_NORMAL = (
    "LENGTH (normal mode): Lead with Direct Answer. Stay compact. "
    "OMIT irrelevant sections entirely — never write 'not applicable' / "
    "'no formula applies' under a header. "
    "Shape 1 (simple facts): 2–4 useful sentences — not one bare line; "
    "still no forced extra headers. "
    "Do NOT cut equations, worked examples, or diagrams for hard Science/"
    "Maths/Physics topics — those may be longer."
)


def max_tokens_for_mode(mode: str) -> int:
    return DEEP_MAX_TOKENS if mode == "deep" else NORMAL_MAX_TOKENS


def brevity_user_line(mode: str) -> str:
    """Append to user message for normal mode only; empty for deep."""
    if mode == "deep":
        return ""
    return _BREVITY_NORMAL
