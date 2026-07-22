"""Short / medium / long notes prompt banding — processing speed."""
from __future__ import annotations

from app.constants.visual_notes_prompt import (
    NOTES_CHARS_MEDIUM,
    NOTES_CHARS_SHORT,
    notes_band_for_transcript,
)
from app.services.qwen_service import (
    _NOTES_MAX_TOKENS,
    _NOTES_SYSTEM_PROMPT,
    _NOTES_SYSTEM_PROMPT_MEDIUM,
    _NOTES_SYSTEM_PROMPT_SHORT,
    _notes_prompt_and_max_tokens,
)


def test_notes_band_short_medium_long():
    assert notes_band_for_transcript("x" * (NOTES_CHARS_SHORT - 1)) == "short"
    assert notes_band_for_transcript("x" * NOTES_CHARS_SHORT) == "medium"
    assert notes_band_for_transcript("x" * (NOTES_CHARS_MEDIUM - 1)) == "medium"
    assert notes_band_for_transcript("x" * NOTES_CHARS_MEDIUM) == "long"


def test_notes_band_prefers_duration_minutes():
    long_text = "x" * NOTES_CHARS_MEDIUM
    assert notes_band_for_transcript(long_text, duration_minutes=1) == "short"
    assert notes_band_for_transcript("hi", duration_minutes=10) == "medium"
    assert notes_band_for_transcript("hi", duration_minutes=45) == "long"


def test_short_and_medium_prompts_lighter_than_full():
    assert len(_NOTES_SYSTEM_PROMPT_SHORT) < len(_NOTES_SYSTEM_PROMPT)
    assert len(_NOTES_SYSTEM_PROMPT_MEDIUM) < len(_NOTES_SYSTEM_PROMPT)


def test_notes_prompt_and_max_tokens_by_band():
    short_p, short_m, short_b = _notes_prompt_and_max_tokens("hi " * 50)
    assert short_b == "short"
    assert short_p is _NOTES_SYSTEM_PROMPT_SHORT
    assert short_m == _NOTES_MAX_TOKENS["short"]

    med_p, med_m, med_b = _notes_prompt_and_max_tokens("x" * NOTES_CHARS_SHORT)
    assert med_b == "medium"
    assert med_p is _NOTES_SYSTEM_PROMPT_MEDIUM
    assert med_m == _NOTES_MAX_TOKENS["medium"]

    long_p, long_m, long_b = _notes_prompt_and_max_tokens("x" * NOTES_CHARS_MEDIUM)
    assert long_b == "long"
    assert long_p is _NOTES_SYSTEM_PROMPT
    assert long_m == _NOTES_MAX_TOKENS["long"]
