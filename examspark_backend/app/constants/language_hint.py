"""Conversation answer-language (not Translate product).

- Lock: first turn Hindi/Bengali/English → stay until user overrides
- Override: "I want Hinglish" / "answer in English" etc.
- Primary signal when unlocked = question text, never notes language
"""
from __future__ import annotations

import re
from typing import Literal, Optional

LanguageHint = Literal["ENGLISH", "HINDI", "BENGALI", "HINGLISH"]

_VALID_LOCKS = frozenset({"ENGLISH", "HINDI", "BENGALI", "HINGLISH"})

_DEVANAGARI = re.compile(r"[\u0900-\u097F]")
_BENGALI = re.compile(r"[\u0980-\u09FF]")
_OTHER_INDIC = re.compile(
    r"[\u0A00-\u0A7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F]"
)
_LATIN_LETTER = re.compile(r"[A-Za-z]")

_FORCE_HINGLISH = re.compile(
    r"(?i)\b("
    r"i\s+want\s+hinglish|"
    r"want\s+hinglish|"
    r"talk\s+in\s+hinglish|"
    r"reply\s+in\s+hinglish|"
    r"answer\s+in\s+hinglish|"
    r"hinglish\s+mein|"
    r"hinglish\s+me|"
    r"hinglish\s+conversation|"
    r"use\s+hinglish|"
    r"switch\s+to\s+hinglish"
    r")\b"
)
_FORCE_HINDI = re.compile(
    r"(?i)\b("
    r"answer\s+in\s+hindi|"
    r"talk\s+in\s+hindi|"
    r"hindi\s+mein\s+batao|"
    r"hindi\s+me\s+batao|"
    r"हिंदी\s+में|"
    r"हिन्दी\s+में"
    r")\b"
)
_FORCE_ENGLISH = re.compile(
    r"(?i)\b("
    r"answer\s+in\s+english|"
    r"talk\s+in\s+english|"
    r"english\s+mein\s+batao|"
    r"in\s+english\s+please|"
    r"switch\s+to\s+english|"
    r"i\s+want\s+english"
    r")\b"
)
_FORCE_BENGALI = re.compile(
    r"(?i)\b("
    r"answer\s+in\s+bengali|"
    r"answer\s+in\s+bangla|"
    r"talk\s+in\s+bengali|"
    r"talk\s+in\s+bangla|"
    r"bengali\s+te|"
    r"bangla\s+te|"
    r"বাংলা\s+তে|"
    r"বাংলায়"
    r")\b"
)


def normalize_lock(value: Optional[str]) -> Optional[LanguageHint]:
    if not value:
        return None
    key = value.strip().upper()
    if key in _VALID_LOCKS:
        return key  # type: ignore[return-value]
    return None


def detect_explicit_override(query: str) -> Optional[LanguageHint]:
    text = (query or "").strip()
    if not text:
        return None
    # Order: Hinglish before Hindi (phrases can overlap less)
    if _FORCE_HINGLISH.search(text):
        return "HINGLISH"
    if _FORCE_BENGALI.search(text):
        return "BENGALI"
    if _FORCE_HINDI.search(text):
        return "HINDI"
    if _FORCE_ENGLISH.search(text):
        return "ENGLISH"
    return None


def detect_question_language_hint(query: str) -> Optional[LanguageHint]:
    """Script / override detect for a single turn (no conversation lock)."""
    text = (query or "").strip()
    if not text:
        return None

    override = detect_explicit_override(text)
    if override:
        return override

    has_bengali = bool(_BENGALI.search(text))
    has_deva = bool(_DEVANAGARI.search(text))
    has_other_indic = bool(_OTHER_INDIC.search(text))
    has_latin = bool(_LATIN_LETTER.search(text))

    if has_bengali and not has_deva and not has_latin:
        return "BENGALI"
    if has_bengali and has_latin:
        return None  # ambiguous mix
    if has_deva and not has_latin:
        return "HINDI"
    if has_deva and has_latin:
        return None
    if has_other_indic:
        return None
    if has_latin and not has_deva and not has_bengali and not has_other_indic:
        return "ENGLISH"
    return None


def resolve_answer_language(
    query: str,
    conversation_language: Optional[str] = None,
) -> LanguageHint:
    """
    Explicit override always wins.
    Else keep conversation lock if set.
    Else detect from this question (default ENGLISH if unclear).
    """
    override = detect_explicit_override(query)
    if override:
        return override

    locked = normalize_lock(conversation_language)
    if locked:
        return locked

    detected = detect_question_language_hint(query)
    return detected or "ENGLISH"


def language_hint_user_line(
    query: str,
    *,
    conversation_language: Optional[str] = None,
) -> str:
    lang = resolve_answer_language(query, conversation_language)
    locked = normalize_lock(conversation_language)
    lock_note = ""
    if locked and not detect_explicit_override(query):
        lock_note = (
            f" Conversation language is LOCKED to {locked} from earlier turns "
            f"— keep answering in {locked} unless the student explicitly switches."
        )
    elif detect_explicit_override(query):
        lock_note = (
            f" Student explicitly requested {lang} — switch conversation to {lang} now."
        )

    if lang == "ENGLISH":
        return (
            f"Detected answer language: ENGLISH.{lock_note} "
            "Write the ENTIRE answer in English only — including section titles. "
            "Do NOT answer in Hindi/Bengali even if notes/RAG are in those languages."
        )
    if lang == "HINDI":
        return (
            f"Detected answer language: HINDI.{lock_note} "
            "Write the ENTIRE answer in Hindi only — including section titles."
        )
    if lang == "BENGALI":
        return (
            f"Detected answer language: BENGALI.{lock_note} "
            "Write the ENTIRE answer in Bengali (Bangla) only — including section titles."
        )
    # HINGLISH
    return (
        f"Detected answer language: HINGLISH.{lock_note} "
        "Reply in natural Hinglish (mix Hindi + English the way Indian students chat) — "
        "section titles can be English or Hinglish. Do not switch to pure English or pure Hindi "
        "unless the student asks."
    )


def typo_intent_rule_block() -> str:
    """Silent typo / mistype tolerance for Home AI + Ask AI."""
    return """====================================================
TYPO / INTENT RULE — HARD CONSTRAINTS
====================================================
Students often mistype. ALWAYS interpret the intended meaning and answer that question.

• Fix common typos silently: missing/extra letters, swapped letters, wrong vowels,
  Hinglish mistypes, keyboard-adjacent errors, OCR-like glitches
  (e.g. "cradit econocmy" → credit economy; "fotosynthesis" → photosynthesis).
• Prefer the most likely education / ExamSpark meaning in context
  (product terms like credits, lecture, notes, quiz; and subject concepts).
• Answer the CORRECTED intent in the resolved conversation language (LANGUAGE RULE).
• Do NOT refuse or say "I don't understand" only because spelling is wrong.
• Do NOT lecture on spelling unless the student explicitly asks how to spell a word.
• If two real topics are equally plausible after correcting typos, ask ONE short
  clarifying question — do not guess wildly.
• Never invent facts: after resolving intent, still follow RAG / grounding rules
  (no match → same NOT_FOUND / knowledge behavior as today).
"""


def language_rule_block() -> str:
    return (
        """====================================================
LANGUAGE RULE (multilingual Q&A) — HARD CONSTRAINTS
====================================================
Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

• Conversation lock: if the chat started in Hindi or Bengali, KEEP that language
  for later turns even if a later question is typed in English letters — until the
  student explicitly switches.
• Explicit switch wins: "I want Hinglish" / "answer in English" / "Hindi mein batao" /
  "answer in Bengali" → switch immediately and stay there.
• Latin-script English (no lock) → English ONLY.
• Devanagari Hindi → Hindi ONLY. Bengali script → Bengali ONLY.
• Natural Hinglish when locked to HINGLISH or when student asks for Hinglish.

ANTI-LEAK: never switch body language because notes/RAG are Hindi/Bengali.
Same credits — NOT the Translate (8 cr) product.
"""
        + typo_intent_rule_block()
    )
