"""Conversation answer-language (not Translate product).

Qwen3 is multilingual — match the student's language (India + world).
- Lock: first-turn language → stay until user overrides
- Override: "I want Hinglish" / "answer in English" etc.
- Primary signal when unlocked = question text, never notes language
"""
from __future__ import annotations

import re
from typing import Literal, Optional

LanguageHint = Literal[
    "ENGLISH",
    "HINDI",
    "BENGALI",
    "HINGLISH",
    "MATCH_QUESTION",
]

_VALID_LOCKS = frozenset(
    {"ENGLISH", "HINDI", "BENGALI", "HINGLISH", "MATCH_QUESTION"}
)

_DEVANAGARI = re.compile(r"[\u0900-\u097F]")
_BENGALI = re.compile(r"[\u0980-\u09FF]")
# Other scripts worldwide (Indic + Arabic/Urdu + CJK + Cyrillic + Thai, etc.)
_NON_LATIN_SCRIPT = re.compile(
    r"["
    r"\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF"  # Indic
    r"\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F"
    r"\u0600-\u06FF"  # Arabic / Urdu
    r"\u0400-\u04FF"  # Cyrillic
    r"\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF"  # CJK / JP / KR
    r"\u0E00-\u0E7F"  # Thai
    r"\u0900-\u097F\u0980-\u09FF"  # also Devanagari/Bengali caught above first
    r"]"
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
# Named language requests (India + world) → MATCH_QUESTION
_FORCE_NAMED_LANGUAGE = re.compile(
    r"(?i)\b("
    r"answer\s+in\s+tamil|talk\s+in\s+tamil|"
    r"answer\s+in\s+telugu|talk\s+in\s+telugu|"
    r"answer\s+in\s+marathi|talk\s+in\s+marathi|marathi\s+mein|marathi\s+me|"
    r"answer\s+in\s+gujarati|talk\s+in\s+gujarati|"
    r"answer\s+in\s+kannada|talk\s+in\s+kannada|"
    r"answer\s+in\s+malayalam|talk\s+in\s+malayalam|"
    r"answer\s+in\s+punjabi|talk\s+in\s+punjabi|"
    r"answer\s+in\s+odia|answer\s+in\s+oriya|talk\s+in\s+odia|"
    r"answer\s+in\s+assamese|talk\s+in\s+assamese|"
    r"answer\s+in\s+urdu|talk\s+in\s+urdu|"
    r"answer\s+in\s+spanish|talk\s+in\s+spanish|responde\s+en\s+espa[nñ]ol|"
    r"answer\s+in\s+french|talk\s+in\s+french|r[eé]ponds?\s+en\s+fran[cç]ais|"
    r"answer\s+in\s+arabic|talk\s+in\s+arabic|"
    r"answer\s+in\s+portuguese|talk\s+in\s+portuguese|"
    r"answer\s+in\s+german|talk\s+in\s+german|"
    r"answer\s+in\s+chinese|talk\s+in\s+chinese|"
    r"answer\s+in\s+japanese|talk\s+in\s+japanese|"
    r"answer\s+in\s+korean|talk\s+in\s+korean|"
    r"answer\s+in\s+russian|talk\s+in\s+russian|"
    r"answer\s+in\s+indonesian|talk\s+in\s+indonesian|"
    r"answer\s+in\s+turkish|talk\s+in\s+turkish"
    r")\b"
)

# Roman/Hinglish chat markers (Latin script) — ChatGPT-style student typing
_HINGLISH_ROMAN = re.compile(
    r"(?i)\b("
    r"kya|kyun|kyunki|hai|hain|nahi|nahin|nhi|"
    r"tum|tumhara|tumhare|mera|meri|mera|"
    r"acha|accha|achha|theek|thik|"
    r"batao|bata|bolo|bol|samajh|samjha|"
    r"matlab|chahiye|karo|karna|raha|rahi|rahe|"
    r"sakhta|sakte|sakti|woh|yeh|"
    r"kaise|kitna|kitni|kahan|kab|kiya|kiye|"
    r"bhai|yaar|pls\s+bata|please\s+bata"
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
    if _FORCE_HINGLISH.search(text):
        return "HINGLISH"
    if _FORCE_BENGALI.search(text):
        return "BENGALI"
    if _FORCE_HINDI.search(text):
        return "HINDI"
    if _FORCE_ENGLISH.search(text):
        return "ENGLISH"
    if _FORCE_NAMED_LANGUAGE.search(text):
        return "MATCH_QUESTION"
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
    has_non_latin = bool(_NON_LATIN_SCRIPT.search(text))
    has_latin = bool(_LATIN_LETTER.search(text))

    if has_bengali and not has_deva and not has_latin:
        return "BENGALI"
    if has_bengali and has_latin:
        return None  # ambiguous mix → resolve defaults to MATCH_QUESTION
    if has_deva and not has_latin:
        return "HINDI"
    if has_deva and has_latin:
        return None
    # Any other script (Tamil, Arabic, Chinese, …) → match that language
    if has_non_latin:
        return "MATCH_QUESTION"
    # Latin Hinglish chat (e.g. "accha tum batao kya hai") → HINGLISH
    if has_latin and len(_HINGLISH_ROMAN.findall(text)) >= 2:
        return "HINGLISH"
    # Latin script (English / Spanish / French / …) — match that language;
    # do not force English-only (Qwen3 is multilingual).
    if has_latin:
        return "MATCH_QUESTION"
    return None


def resolve_answer_language(
    query: str,
    conversation_language: Optional[str] = None,
) -> LanguageHint:
    """
    Explicit override always wins.
    Else keep conversation lock if set.
    Else detect from this question (default MATCH_QUESTION — same language as input).
    """
    override = detect_explicit_override(query)
    if override:
        return override

    locked = normalize_lock(conversation_language)
    if locked:
        return locked

    detected = detect_question_language_hint(query)
    return detected or "MATCH_QUESTION"


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
            "Do NOT switch language only because notes/RAG are in another language."
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
    if lang == "MATCH_QUESTION":
        return (
            f"Detected answer language: MATCH_QUESTION (India + world).{lock_note} "
            "Qwen3 is multilingual. Write the ENTIRE answer in the SAME language as "
            "the student's question — any Indian language OR any world language "
            "(English, Spanish, French, Arabic, Chinese, Japanese, Portuguese, "
            "German, Russian, Indonesian, Turkish, etc.). "
            "Do NOT force English unless the question is in English. "
            "ANTI-LEAK: ignore the language of lecture notes / transcript / RAG. "
            "If the student wrote Latin English or Hinglish, NEVER reply in Khmer, "
            "Thai, Chinese, or any other script just because the notes use that script."
        )
    # HINGLISH
    return (
        f"Detected answer language: HINGLISH.{lock_note} "
        "Reply in natural Hinglish (mix Hindi + English the way Indian students chat) — "
        "section titles can be English or Hinglish. Do not switch to pure English or pure Hindi "
        "unless the student asks. "
        "ANTI-LEAK: do NOT copy notes language (Khmer/Hindi/English/etc.) — follow the student."
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
LANGUAGE RULE — CHATGPT-STYLE (Qwen3 multilingual)
====================================================
Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

• Always answer in the SAME language / chat style as the student (India or world).
  Example: English notes + student asks in Hinglish → answer in Hinglish.
  Example: English notes + student asks in Marathi → answer in Marathi.
• Conversation lock: keep that language across turns in this workspace/session
  until an explicit switch (like ChatGPT memory for the chat).
• Explicit switch wins: "I want Hinglish" / "answer in English" / "Hindi mein batao" /
  "Marathi mein" / "answer in Bengali|Tamil|Spanish|French|Arabic|…" → switch.
• Devanagari → Hindi (or match Marathi if the question is Marathi). Bengali script → Bengali.
• Latin Hinglish markers → HINGLISH. Pure English Latin → English.
• Any other script or Latin-script language (Spanish, French, …) → match that language.

ANTI-LEAK (critical): never copy the language of lecture notes / transcript / RAG.
If notes are wrong-language or Khmer/Thai/etc., still answer in the student's language.
Same credits — NOT the Translate (8 cr) product.
"""
        + typo_intent_rule_block()
    )


def notes_language_user_line(source_text: str) -> str:
    """Extra user-message lock for notes generation (input language = output)."""
    sample = (source_text or "").strip()[:2500]
    if not sample:
        return (
            "LANGUAGE LOCK: source is empty — write notes in clear English only. "
            "Do not invent another language."
        )
    has_deva = bool(_DEVANAGARI.search(sample))
    has_bengali = bool(_BENGALI.search(sample))
    has_non_latin = bool(_NON_LATIN_SCRIPT.search(sample))
    has_latin = bool(_LATIN_LETTER.search(sample))
    latin_chars = len(_LATIN_LETTER.findall(sample))
    non_latin_chars = len(_NON_LATIN_SCRIPT.findall(sample))

    if has_bengali and not has_deva and non_latin_chars >= latin_chars:
        tip = "Source looks primarily Bengali → write Bengali notes only."
    elif has_deva and non_latin_chars >= max(1, latin_chars // 2):
        tip = (
            "Source looks primarily Devanagari (Hindi/Marathi/etc.) → "
            "write notes in that SAME language only (do not switch to English)."
        )
    elif has_non_latin and non_latin_chars > latin_chars:
        tip = (
            "Source uses a non-Latin script → write notes in that SAME language only."
        )
    elif has_latin and not has_non_latin:
        tip = (
            "Source looks primarily English/Latin → write ENGLISH notes only. "
            "Do NOT translate into Hindi, Hinglish, Khmer, or any other language."
        )
    elif has_latin and len(_HINGLISH_ROMAN.findall(sample)) >= 2:
        tip = "Source looks Hinglish → keep Hinglish notes (same mix)."
    else:
        tip = "Match the primary language of the source exactly."

    return (
        "LANGUAGE LOCK FOR THIS NOTES JOB: "
        f"{tip} "
        "Headings, summary, key points, and body must match. "
        "Never invent a different language than the transcript/OCR."
    )
