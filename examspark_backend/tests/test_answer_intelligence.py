"""Tests — education answer intelligence (anti-template)."""
from __future__ import annotations

from app.constants.answer_intelligence import (
    ANSWER_INTELLIGENCE_BLOCK,
    answer_intelligence_user_line,
    detect_question_intent,
)


def test_detect_intents():
    assert detect_question_intent("hi") == "greeting"
    assert detect_question_intent("What is photosynthesis?") == "definition"
    assert detect_question_intent("Why does photosynthesis need sunlight?") == "how_why"
    assert detect_question_intent("Difference between mitosis and meiosis") == "compare"
    assert detect_question_intent("Write a short answer on osmosis") == "short_exam"
    assert (
        detect_question_intent("Explain this clearly for a student in detail")
        == "long_exam"
    )
    assert detect_question_intent("Calculate the value of x^2 - 5x + 6") == "numerical"
    assert detect_question_intent("List the steps of mitosis") == "list"


def test_user_line_anti_template():
    line = answer_intelligence_user_line("What is HOF?", "normal")
    assert "Intent:" in line
    assert "template" in line.lower()
    block = ANSWER_INTELLIGENCE_BLOCK
    assert "ANTI-TEMPLATE" in block
    assert "UNDERSTAND" in block
