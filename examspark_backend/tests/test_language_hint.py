"""Unit tests — question + conversation language lock (India + world)."""
from __future__ import annotations

from app.constants.language_hint import (
    detect_question_language_hint,
    language_hint_user_line,
    language_rule_block,
    resolve_answer_language,
    typo_intent_rule_block,
)


def test_latin_question_clear_english():
    # Clear English Latin → ENGLISH (Ask AI notes-language leak fix)
    assert detect_question_language_hint("Explain photosynthesis simply") == "ENGLISH"
    line = language_hint_user_line("What is HOF?")
    assert "ENGLISH" in line
    assert "HARD LOCK" in line or "English only" in line


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
    assert detect_question_language_hint("english main baat karo") == "ENGLISH"
    assert detect_question_language_hint("bengali mein samjhao") == "BENGALI"
    assert detect_question_language_hint("bengali speak what product i use") == "BENGALI"
    assert detect_question_language_hint("tamil speak what product i use") == "TAMIL"
    assert detect_question_language_hint("telugu speak what product i use") == "TELUGU"
    assert detect_question_language_hint("gujarati speak what product i use") == "GUJARATI"
    assert detect_question_language_hint("urdu speak what product i use") == "URDU"
    assert detect_question_language_hint("punjabi speak what product i use") == "PUNJABI"
    assert detect_question_language_hint("french speak what product i use") == "FRENCH"
    assert detect_question_language_hint("answer in spanish please") == "SPANISH"



def test_conversation_lock_is_default_not_hard_lock():
    assert (
        resolve_answer_language("What is HOF?", conversation_language="HINDI")
        == "ENGLISH"
    )
    assert (
        resolve_answer_language("What is HOF?", conversation_language="BENGALI")
        == "ENGLISH"
    )
    assert (
        resolve_answer_language("Qué es esto?", conversation_language="ENGLISH")
        == "MATCH_QUESTION"
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
    assert "switched to writing in ENGLISH" in line
    assert "ENGLISH" in line


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


def test_pure_english_chip_is_english():
    assert detect_question_language_hint("Explain the main idea in simple words") == (
        "ENGLISH"
    )
    assert (
        resolve_answer_language("Explain the main idea in simple words") == "ENGLISH"
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
        == "MARATHI"
    )


def test_typo_intent_rule_exported():
    block = typo_intent_rule_block()
    assert "TYPO / INTENT RULE" in block
    assert "cradit econocmy" in block
    combined = language_rule_block()
    assert "LANGUAGE RULE" in combined
    assert "TYPO / INTENT RULE" in combined
