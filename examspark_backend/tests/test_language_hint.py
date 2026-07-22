"""Unit tests — question + conversation language lock (India + world)."""
from __future__ import annotations

from app.constants.language_hint import (
    detect_question_language_hint,
    language_hint_user_line,
    language_rule_block,
    resolve_answer_language,
    typo_intent_rule_block,
)


def test_latin_question_matches_not_force_english():
    # Latin script → MATCH_QUESTION (English/Spanish/French — model matches)
    assert detect_question_language_hint("Explain photosynthesis simply") == "MATCH_QUESTION"
    line = language_hint_user_line("What is HOF?")
    assert "MATCH_QUESTION" in line
    assert "world" in line.lower() or "Qwen3" in line


def test_hindi_devanagari_hint():
    assert detect_question_language_hint("प्रकाश संश्लेषण क्या है?") == "HINDI"


def test_bengali_script_hint():
    assert detect_question_language_hint("প্রকাশ সংশ্লেষণ কী?") == "BENGALI"


def test_mixed_returns_none_then_match_default():
    assert detect_question_language_hint("HOF क्या होता है explain") is None
    assert resolve_answer_language("HOF क्या होता है explain") == "MATCH_QUESTION"


def test_explicit_overrides():
    assert detect_question_language_hint("Answer in Hindi: what is gravity?") == "HINDI"
    assert detect_question_language_hint("I want hinglish conversation") == "HINGLISH"
    assert detect_question_language_hint("answer in bangla please") == "BENGALI"
    assert detect_question_language_hint("answer in english please") == "ENGLISH"
    assert detect_question_language_hint("answer in spanish please") == "MATCH_QUESTION"


def test_conversation_lock_holds_english_typed_followup():
    assert (
        resolve_answer_language("What is HOF?", conversation_language="HINDI")
        == "HINDI"
    )
    assert (
        resolve_answer_language("What is HOF?", conversation_language="BENGALI")
        == "BENGALI"
    )
    assert (
        resolve_answer_language("Qué es esto?", conversation_language="ENGLISH")
        == "ENGLISH"
    )


def test_hinglish_override_breaks_lock():
    assert (
        resolve_answer_language(
            "I want hinglish — explain HOF",
            conversation_language="HINDI",
        )
        == "HINGLISH"
    )


def test_lock_note_in_user_line():
    line = language_hint_user_line(
        "What is photosynthesis?", conversation_language="HINDI"
    )
    assert "LOCKED to HINDI" in line
    assert "HINDI" in line


def test_tamil_script_match_question():
    assert detect_question_language_hint("ஒளிச்சேர்க்கை என்றால் என்ன?") == "MATCH_QUESTION"
    line = language_hint_user_line("ஒளிச்சேர்க்கை என்றால் என்ன?")
    assert "MATCH_QUESTION" in line


def test_chinese_script_match_question():
    assert detect_question_language_hint("什么是光合作用？") == "MATCH_QUESTION"


def test_language_rule_india_and_world():
    block = language_rule_block()
    assert "INDIA + WORLD" in block or "India or world" in block
    assert "Qwen3" in block
    assert "multilingual" in block.lower()
    assert "ANTI-LEAK" in block or "never copy" in block.lower() or "NEVER" in block


def test_hinglish_roman_chat_detected():
    q = "ACCHA TUM BOL SAKTE HO A KIYA BOL RAHA"
    assert detect_question_language_hint(q) == "HINGLISH"
    line = language_hint_user_line(q)
    assert "HINGLISH" in line
    assert "ANTI-LEAK" in line


def test_pure_english_not_forced_hinglish():
    assert detect_question_language_hint("Explain the main idea in simple words") == (
        "MATCH_QUESTION"
    )


def test_notes_language_user_line_english_lock():
    from app.constants.language_hint import notes_language_user_line

    line = notes_language_user_line(
        "Photosynthesis is the process by which green plants make food using sunlight."
    )
    assert "ENGLISH" in line.upper()
    assert "NOT translate" in line or "Do NOT translate" in line


def test_marathi_explicit_override():
    assert (
        detect_question_language_hint("Marathi mein samja: photosynthesis")
        == "MATCH_QUESTION"
    )


def test_typo_intent_rule_exported():
    block = typo_intent_rule_block()
    assert "TYPO / INTENT RULE" in block
    assert "cradit econocmy" in block
    combined = language_rule_block()
    assert "LANGUAGE RULE" in combined
    assert "TYPO / INTENT RULE" in combined
