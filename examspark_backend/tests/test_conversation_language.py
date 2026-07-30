"""Tests — conversation_language normalize (Home/Ask validation fix)."""
from __future__ import annotations

from app.models.ask_ai import HomeAiRequest, normalize_conversation_language


def test_normalize_accepts_match_question_and_case():
    assert normalize_conversation_language("MATCH_QUESTION") == "MATCH_QUESTION"
    assert normalize_conversation_language("match_question") == "MATCH_QUESTION"
    assert normalize_conversation_language("english") == "ENGLISH"
    assert normalize_conversation_language("ENGLISH") == "ENGLISH"
    assert normalize_conversation_language("hindi") == "HINDI"
    assert normalize_conversation_language(None) is None


def test_home_ai_request_accepts_match_question():
    req = HomeAiRequest(query="hi", conversation_language="MATCH_QUESTION")
    assert req.conversation_language == "MATCH_QUESTION"
    req2 = HomeAiRequest(query="hi", conversation_language="english")
    assert req2.conversation_language == "ENGLISH"
