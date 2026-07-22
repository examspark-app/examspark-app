"""Tests — visual fallback when model skips <<VISUAL_JSON>>."""
from __future__ import annotations

from app.services.visual_fallback import (
    fallback_visual_payload,
    visual_reminder_user_line,
    wants_visual,
)
from app.services.visual_stream_parser import split_answer_and_visual


def test_wants_visual_detects_graph_words():
    assert wants_visual("Show the parabola graph and mark the roots")
    assert wants_visual("Draw a timeline of 1857 revolt")
    # Known school topics auto-want a diagram (Founder: photosynthesis must show Visual Card)
    assert wants_visual("What is photosynthesis in one sentence?")
    assert not wants_visual("What is the capital of France?")


def test_fallback_photosynthesis_short_question():
    payload = fallback_visual_payload("What is photosynthesis?", "")
    assert payload is not None
    assert payload.get("text_diagrams") or payload.get("process_flows")


def test_fallback_quadratic_graph():
    payload = fallback_visual_payload(
        "Explain x^2 - 5x + 6 = 0. Show the parabola graph.",
        "Roots are 2 and 3.",
    )
    assert payload is not None
    assert payload["graphs"]
    assert "x^2" in payload["graphs"][0]["function"]
    assert "5*x" in payload["graphs"][0]["function"] or "-5*x" in payload["graphs"][0]["function"]


def test_fallback_photosynthesis_is_real_not_placeholder():
    payload = fallback_visual_payload(
        "Explain photosynthesis with a simple labelled text diagram of the process flow.",
        "Occurs in chloroplasts.",
    )
    assert payload is not None
    diagram = payload["text_diagrams"][0]["content"]
    assert "Chloroplast" in diagram or "chloroplast" in diagram.lower()
    assert "Concept" not in diagram
    assert "Key relation" not in diagram


def test_no_fake_generic_stub():
    payload = fallback_visual_payload(
        "Draw a diagram of mitosis stages",
        "Mitosis has four stages.",
    )
    # Unknown topic without arrows → None (never placeholder stub)
    assert payload is None


def test_visual_reminder_required_line():
    line = visual_reminder_user_line("Show the parabola graph")
    assert "VISUAL REQUIRED" in line
    assert "<<VISUAL_JSON>>" in line


def test_split_still_works_with_model_visual():
    text = (
        "Answer text.\n"
        "<<VISUAL_JSON>>\n"
        '{"graphs":[{"function":"y=x^2-5*x+6","x_range":[-2,7],"label":"P"}]}'
    )
    answer, visual = split_answer_and_visual(text)
    assert answer == "Answer text."
    assert visual is not None
    assert visual["graphs"][0]["function"] == "y=x^2-5*x+6"
