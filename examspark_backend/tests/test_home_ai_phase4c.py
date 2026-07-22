"""Tests for Phase 4C Knowledge Object builder."""
from app.services.home_ai_knowledge import build_knowledge_object, knowledge_to_source_text
from app.services.home_ai_tools_service import home_tool_credit_cost
from app.services.home_ai_response_store import VALID_TOOL_TYPES


def test_build_knowledge_object_sections():
    answer = """## Direct Answer
Photosynthesis makes food using light.

## Easy Explanation
Plants convert CO2 and water into glucose.

## Key Points
- Needs chlorophyll
- Produces oxygen
- Happens in chloroplasts

## Important Formula
6CO2 + 6H2O → C6H12O6 + 6O2
"""
    ko = build_knowledge_object(query="What is photosynthesis?", answer=answer)
    assert "Photosynthesis" in ko["summary"]
    assert len(ko["key_points"]) >= 2
    assert ko["metadata"]["query"] == "What is photosynthesis?"
    src = knowledge_to_source_text(ko)
    assert "Topic / Question" in src
    assert "Key points" in src
    assert len(src) < 4000


def test_knowledge_source_does_not_dump_huge_answer():
    huge = "word " * 5000
    ko = build_knowledge_object(query="Q", answer=huge)
    src = knowledge_to_source_text(ko, max_chars=3500)
    assert len(src) <= 3500


def test_home_tool_credits():
    assert home_tool_credit_cost("flashcards") == 0
    assert home_tool_credit_cost("quiz") == 0
    assert home_tool_credit_cost("mind_map") == 0
    assert home_tool_credit_cost("important_questions") == 0
    assert home_tool_credit_cost("memory_tricks") == 0
    assert home_tool_credit_cost("flashcards", regenerate=True) == 5
    assert home_tool_credit_cost("mind_map", regenerate=True) == 10
    assert "flashcards" in VALID_TOOL_TYPES
    assert "memory_tricks" in VALID_TOOL_TYPES
    assert "visual" in VALID_TOOL_TYPES


def test_derive_flashcards_and_recommend():
    from app.services.home_ai_tool_derive import derive_tool_payload, recommend_tool_types

    ko = {
        "summary": "Photosynthesis makes food using light.",
        "explanation": "Plants convert CO2 and water into glucose using chlorophyll.",
        "key_points": ["Needs chlorophyll", "Produces oxygen", "Happens in chloroplasts"],
        "formulas": ["6CO2 + 6H2O → C6H12O6 + 6O2"],
        "metadata": {"query": "What is photosynthesis?"},
    }
    cards = derive_tool_payload("flashcards", ko)
    assert len(cards["cards"]) >= 3
    # Front must be a question/job — not "Recall: same point"
    assert not any(c["front"].startswith("Recall:") for c in cards["cards"])
    assert cards["cards"][0]["front"] != cards["cards"][0]["back"]
    assert "what is" in cards["cards"][0]["front"].lower()

    quiz = derive_tool_payload("quiz", ko)
    assert len(quiz["questions"]) >= 3
    letters = {q["correctAnswer"] for q in quiz["questions"]}
    # Correct answer must not always be A
    assert letters != {"A"} or len(quiz["questions"]) == 1
    stems = [q["question"] for q in quiz["questions"]]
    assert len(set(stems)) >= 2  # varied stems, not identical pattern spam

    mem = derive_tool_payload("memory_tricks", ko)
    assert len(mem["tricks"]) >= 1
    assert "Cue word" in mem["tricks"][0]["trigger"] or "cue" in mem["tricks"][0]["trigger"].lower()

    booster = derive_tool_payload("exam_booster", ko)
    assert "2-mark" in booster["markdown"] or "5-mark" in booster["markdown"]
    mistakes = derive_tool_payload("common_mistakes", ko)
    assert "Fix:" in mistakes["markdown"]
    tips = derive_tool_payload("teacher_tips", ko)
    assert "Lesson order" in tips["markdown"]
    five = derive_tool_payload("five_min_revision", ko)
    assert "5-Minute Drill" in five["revisionSheet"]
    assert "Pass rule" in five["revisionSheet"]
    iq = derive_tool_payload("important_questions", ko)
    assert any("Define" in q["question"] for q in iq["questions"])

    rec = recommend_tool_types(ko, query="photosynthesis cycle")
    assert "visual" in rec or "flashcards" in rec


def test_followup_and_semantic():
    from app.services.home_ai_followup import (
        is_semantically_similar,
        looks_like_knowledge_follow_up,
    )

    assert looks_like_knowledge_follow_up("Explain in Hindi")
    assert looks_like_knowledge_follow_up("Why?")
    assert looks_like_knowledge_follow_up("more examples please")
    assert is_semantically_similar(
        "What is photosynthesis?", "photosynthesis meaning"
    )
    assert is_semantically_similar(
        "What is Newton first law?", "Newton first law explain"
    )
    assert not is_semantically_similar("Photosynthesis", "Quadratic equations")
