"""Unit tests — question + conversation language lock."""
from __future__ import annotations

from app.constants.language_hint import (
    detect_question_language_hint,
    language_hint_user_line,
    language_rule_block,
    resolve_answer_language,
    typo_intent_rule_block,
)


def test_english_question_hint():
    assert detect_question_language_hint("Explain photosynthesis simply") == "ENGLISH"
    line = language_hint_user_line("What is HOF?")
    assert "ENGLISH" in line


def test_hindi_devanagari_hint():
    assert detect_question_language_hint("प्रकाश संश्लेषण क्या है?") == "HINDI"


def test_bengali_script_hint():
    assert detect_question_language_hint("প্রকাশ সংশ্লেষণ কী?") == "BENGALI"


def test_mixed_returns_none():
    assert detect_question_language_hint("HOF क्या होता है explain") is None


def test_explicit_overrides():
    assert detect_question_language_hint("Answer in Hindi: what is gravity?") == "HINDI"
    assert detect_question_language_hint("I want hinglish conversation") == "HINGLISH"
    assert detect_question_language_hint("answer in bangla please") == "BENGALI"


def test_conversation_lock_holds_english_typed_followup():
    # Started Hindi — later English letters still Hindi until override
    assert (
        resolve_answer_language("What is HOF?", conversation_language="HINDI")
        == "HINDI"
    )
    assert (
        resolve_answer_language("What is HOF?", conversation_language="BENGALI")
        == "BENGALI"
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


def test_typo_intent_rule_exported():
    block = typo_intent_rule_block()
    assert "TYPO / INTENT RULE" in block
    assert "cradit econocmy" in block
    assert "silently" in block.lower() or "silent" in block.lower()
    # Shared language_rule_block includes typo section
    combined = language_rule_block()
    assert "LANGUAGE RULE" in combined
    assert "TYPO / INTENT RULE" in combined
