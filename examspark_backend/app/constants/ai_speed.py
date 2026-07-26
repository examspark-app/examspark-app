"""Normal-mode reply length — Home AI + Ask AI.

Length + intent coaching lives in answer_intelligence (anti-template).
"""
from __future__ import annotations

from app.constants.answer_intelligence import answer_intelligence_user_line

# Normal: room for visuals + medium Maths/Science. Deep: hard Physics /
# multi-step equations / long syllabus without cutting mid-answer.
NORMAL_MAX_TOKENS = 2048
DEEP_MAX_TOKENS = 4096

_BREVITY_NORMAL = (
    "LENGTH (normal mode): Stay compact and natural. "
    "OMIT irrelevant sections. Prefer tutor prose over fixed headers. "
    "Do NOT cut equations or worked examples for hard Science/Maths/Physics."
)


def max_tokens_for_mode(mode: str) -> int:
    return DEEP_MAX_TOKENS if mode == "deep" else NORMAL_MAX_TOKENS


def answer_length_user_line(query: str, mode: str) -> str:
    """Match answer to question intent (shared Home + Ask)."""
    return answer_intelligence_user_line(query, mode)


def brevity_user_line(mode: str) -> str:
    """Legacy helper — prefer answer_length_user_line when query exists."""
    if mode == "deep":
        return ""
    return _BREVITY_NORMAL
