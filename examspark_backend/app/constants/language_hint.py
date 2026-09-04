"""Conversation answer-language (not Translate product).

Hybrid design — deliberately NOT "100% trust the model, no rules":
- A small, deterministic script/keyword layer catches the cases where
  trusting the model alone was actually causing wrong-language replies
  (this is the exact bug this fix addresses — see resolve_answer_language).
- Everything the deterministic layer can't confidently classify (mixed
  script, unusual languages) falls through to MATCH_QUESTION, which is
  the "trust the model's multilingual understanding" path.
- Lock: first-turn language sticks across turns for stability, but an
  UNAMBIGUOUS new script/language in a later message is treated as the
  student naturally switching — no need to say "please switch to X".
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
    r"]"
)
_LATIN_LETTER = re.compile(r"[A-Za-z]")

_FORCE_HINGLISH = re.compile(
    r"(?i)\b(i\s+want\s+hinglish|want\s+hinglish|talk\s+in\s+hinglish|"
    r"reply\s+in\s+hinglish|answer\s+in\s+hinglish|hinglish\s+mein|"
    r"hinglish\s+me|hinglish\s+conversation|use\s+hinglish|"
    r"switch\s+to\s+hinglish)\b"
)
_FORCE_HINDI = re.compile(
    r"(?i)\b(answer\s+in\s+hindi|talk\s+in\s+hindi|speak\s+hindi|speak\s+in\s+hindi|"
    r"hindi\s+speak|in\s+hindi|hindi\s+mein\s+batao|hindi\s+me\s+batao|"
    r"hindi\s+mein|hindi\s+me|हिंदी\s+में|हिन्दी\s+में)\b"
)
_FORCE_ENGLISH = re.compile(
    r"(?i)\b(answer\s+in\s+english|talk\s+in\s+english|talk\s+english|speak\s+english|"
    r"speak\s+in\s+english|english\s+speak|in\s+english|in\s+english\s+please|"
    r"english\s+mein\s+batao|english\s+me\s+batao|english\s+mein\s+baat|"
    r"english\s+me\s+baat|english\s+main\s+baat|english\s+main\s+bat|"
    r"baat\s+karo\s+english|bat\s+karo\s+english|"
    r"switch\s+to\s+english|i\s+want\s+english|reply\s+in\s+english)\b"
)
_FORCE_BENGALI = re.compile(
    r"(?i)\b(answer\s+in\s+bengali|answer\s+in\s+bangla|talk\s+in\s+bengali|"
    r"talk\s+in\s+bangla|speak\s+bengali|speak\s+bangla|speak\s+in\s+bengali|"
    r"speak\s+in\s+bangla|bengali\s+speak|bangla\s+speak|in\s+bengali|in\s+bangla|"
    r"bengali\s+mein|bengali\s+me|bangla\s+mein|bangla\s+me|bengali\s+te|"
    r"bangla\s+te|bengali\s+bolun|bangla\s+bolun|বাংলা\s+তে|বাংলায়)\b"
)
_ENGLISH_MARKERS = re.compile(
    r"(?i)\b(the|what|why|how|when|where|who|which|explain|describe|"
    r"define|list|summarize|summary|simple|words|please|about|should|"
    r"would|could|difference|equation|formula|idea|main|revision|"
    r"remember|important|terms|definitions|lecture|photosynthesis|"
    r"gravity|because|between|without)\b"
)
_STRONG_ENGLISH_START = re.compile(
    r"(?i)^\s*(what|why|how|when|where|who|which|explain|describe|define|"
    r"list|summarize|tell\s+me|can\s+you)\b"
)
_FORCE_NAMED_LANGUAGE = re.compile(
    r"(?i)\b(answer\s+in\s+tamil|talk\s+in\s+tamil|answer\s+in\s+telugu|"
    r"talk\s+in\s+telugu|answer\s+in\s+marathi|talk\s+in\s+marathi|"
    r"marathi\s+mein|marathi\s+me|answer\s+in\s+gujarati|"
    r"talk\s+in\s+gujarati|answer\s+in\s+kannada|talk\s+in\s+kannada|"
    r"answer\s+in\s+malayalam|talk\s+in\s+malayalam|answer\s+in\s+punjabi|"
    r"talk\s+in\s+punjabi|answer\s+in\s+odia|answer\s+in\s+oriya|"
    r"talk\s+in\s+odia|answer\s+in\s+assamese|talk\s+in\s+assamese|"
    r"answer\s+in\s+urdu|talk\s+in\s+urdu|answer\s+in\s+spanish|"
    r"talk\s+in\s+spanish|responde\s+en\s+espa[nñ]ol|answer\s+in\s+french|"
    r"talk\s+in\s+french|r[eé]ponds?\s+en\s+fran[cç]ais|"
    r"answer\s+in\s+arabic|talk\s+in\s+arabic|answer\s+in\s+portuguese|"
    r"talk\s+in\s+portuguese|answer\s+in\s+german|talk\s+in\s+german|"
    r"answer\s+in\s+chinese|talk\s+in\s+chinese|answer\s+in\s+japanese|"
    r"talk\s+in\s+japanese|answer\s+in\s+korean|talk\s+in\s+korean|"
    r"answer\s+in\s+russian|talk\s+in\s+russian|answer\s+in\s+indonesian|"
    r"talk\s+in\s+indonesian|answer\s+in\s+turkish|talk\s+in\s+turkish)\b"
)
_HINGLISH_ROMAN = re.compile(
    r"(?i)\b(kya|kyun|kyunki|hai|hain|nahi|nahin|nhi|tum|tumhara|tumhare|"
    r"mera|meri|acha|accha|achha|theek|thik|batao|bata|bolo|bol|samajh|"
    r"samjha|matlab|chahiye|karo|karna|raha|rahi|rahe|sakhta|sakte|sakti|"
    r"woh|yeh|kaise|kitna|kitni|kahan|kab|kiya|kiye|bhai|yaar|pls\s+bata|"
    r"please\s+bata)\b"
)
_BENGLISH_ROMAN = re.compile(
    r"(?i)\b(ami|amar|amader|tumi|tomar|tomader|apni|apnar|keno|ki|ache|"
    r"nei|bhalo|valo|chai|korbo|hobe|eta|ota|ekhane|kothay|aache|"
    r"bolun|bujhte|parchi|jabe|kemon)\b"
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
    """Script/override detect for a single turn. Returns None when the
    message is ambiguous or mixed (e.g. Hindi words inside an English
    sentence) — ambiguity means "don't force a switch", handled by the
    caller."""
    text = (query or "").strip()
    if not text:
        return None

    override = detect_explicit_override(text)
    if override:
        return override

    has_bengali = bool(_BENGALI.search(text))
    has_deva = bool(_DEVANAGARI.search(text))
    has_non_latin = bool(_NON_LATIN_SCRIPT.search(text)) or has_bengali or has_deva
    has_latin = bool(_LATIN_LETTER.search(text))

    if has_bengali and not has_deva and not has_latin:
        return "BENGALI"
    if has_bengali and has_latin:
        return None  # mixed → ambiguous, don't force a switch
    if has_deva and not has_latin:
        return "HINDI"
    if has_deva and has_latin:
        return None
    if has_non_latin:
        return "MATCH_QUESTION"
    if has_latin and len(_HINGLISH_ROMAN.findall(text)) >= 2:
        return "HINGLISH"
    if has_latin and (
        len(_ENGLISH_MARKERS.findall(text)) >= 2
        or _STRONG_ENGLISH_START.search(text)
    ):
        return "ENGLISH"
    if has_latin:
        return "MATCH_QUESTION"
    return None


def resolve_answer_language(
    query: str,
    conversation_language: Optional[str] = None,
) -> LanguageHint:
    """
    1. Explicit override ("answer in Bengali") → always wins.
    2. THE FIX: if locked, but this message is an UNAMBIGUOUS different
       language (pure script, not mixed) → treat it as a natural switch,
       even without an explicit "please switch" phrase — the way a real
       bilingual tutor notices you started writing in a different
       language and just follows along.
    3. If locked and this message is ambiguous/mixed → keep the lock.
    4. No lock → detect fresh from this message.
    """
    override = detect_explicit_override(query)
    if override:
        return override

    detected = detect_question_language_hint(query)
    locked = normalize_lock(conversation_language)

    if locked:
        if detected and detected != locked:
            return detected  # unambiguous switch — follow it
        return locked

    return detected or "MATCH_QUESTION"


_NATURAL_MIRROR_NOTE = (
    " This detected language is a guide, not a rigid rule — use your own "
    "multilingual understanding like a bilingual human tutor would. If the "
    "student's message itself blends languages (e.g. Hindi words inside an "
    "English sentence, or vice versa), mirror that SAME natural blend in your "
    "reply rather than forcing artificial purity. Match their real chat style, "
    "turn by turn."
)


def language_hint_user_line(
    query: str,
    *,
    conversation_language: Optional[str] = None,
    per_message: bool = False,
) -> str:
    if per_message:
        selected = (conversation_language or "").strip()
        selected_locked = bool(selected) and selected.upper() != "MATCH_QUESTION"

        # An explicit override ("answer in Hindi") always wins, even over a
        # prior selection — the user is deliberately asking for a change.
        override = detect_explicit_override(query)

        # THE FIX: a short chip tap (e.g. "Acne / Pimples", "Oily Skin",
        # "Winter") must NOT be treated as an English switch away from a
        # Hindi/Bengali selection just because the chip label is in
        # English. We require real, longer sentence content in an
        # unambiguous different script before trusting per-message
        # detection over the user's explicit selection.
        stripped = (query or "").strip()
        word_count = len(stripped.split())
        detected = detect_question_language_hint(query)

        if override:
            lang = override
        elif selected_locked and (word_count < 4 or detected is None):
            # Too short / ambiguous (a chip label, a single word, a photo
            # with no caption) — trust the user's selected language
            # instead of a stray English chip label.
            lang = selected.upper()
        elif (
            selected_locked
            and detected
            and detected != "MATCH_QUESTION"
            and detected != selected.upper()
        ):
            # A genuinely longer, unambiguous message in a different
            # script/language — treat it as the user naturally switching.
            lang = detected
        else:
            lang = detected or (selected.upper() if selected_locked else "MATCH_QUESTION")

        selected_note = ""
        if selected_locked:
            selected_note = (
                f" The user selected {selected} for this GlowGuide chat. Use {selected} "
                "for your reply, follow-up question, and every question_options chip "
                "unless the current user message clearly switches to another language "
                "with real sentence content (not just a short chip tap or a single word)."
            )

        roman_bengali = bool(_LATIN_LETTER.search(query)) and len(
            _BENGLISH_ROMAN.findall(query)
        ) >= 2
        script = (
            "Roman/Latin script"
            if _LATIN_LETTER.search(query) and not _NON_LATIN_SCRIPT.search(query)
            else "the script used in the message"
        )
        if roman_bengali and not (selected_locked and word_count < 4):
            return (
                "PER-MESSAGE LANGUAGE RULE: The current message looks like Bengali "
                "written in Roman/Latin script (Benglish). Reply in Benglish, not Bengali script. "
                "Mirror the user's current language mix and Roman script exactly."
                + selected_note
            )
        return (
            f"PER-MESSAGE LANGUAGE RULE: Answer this message in {lang}, using {script}. "
            "A short chip-tap answer (2-4 words, e.g. a category or skin-type label) is NOT "
            "a language-switch signal — it is just the label text of the button the user "
            "tapped. Only treat a message as switching language when it has real, "
            "unambiguous sentence content in a different script. Pure Devanagari means "
            "Hindi, pure Bengali script means Bengali, and Roman Hindi/Hinglish must "
            "remain Roman. Mirror mixed-language messages naturally in the same mix and "
            "script."
            + selected_note
        )
    lang = resolve_answer_language(query, conversation_language)
    locked = normalize_lock(conversation_language)
    is_explicit = bool(detect_explicit_override(query))
    is_implicit_switch = (
        not is_explicit and locked is not None and lang != locked
    )

    lock_note = ""
    if is_explicit:
        lock_note = (
            f" Student explicitly requested {lang} — switch conversation to {lang} now."
        )
    elif is_implicit_switch:
        lock_note = (
            f" The student just switched to writing in {lang} (no need for them "
            f"to say so explicitly) — follow their lead and continue in {lang} "
            f"from here."
        )
    elif locked:
        lock_note = (
            f" Conversation language is LOCKED to {locked} from earlier turns "
            f"— keep answering in {locked} unless the student clearly switches."
        )

    if lang == "ENGLISH":
        return (
            f"Detected answer language: ENGLISH.{lock_note} "
            "HARD LOCK: Write the ENTIRE answer in English only — including "
            "section titles, formula labels, and explanations. "
            "Even if lecture notes / transcript / RAG are Hindi, Hinglish, "
            "Bengali, or any other language — TRANSLATE the grounded facts "
            "into English. NEVER reply in Hindi or Bengali for an English question."
            + _NATURAL_MIRROR_NOTE
        )
    if lang == "HINDI":
        return (
            f"Detected answer language: HINDI.{lock_note} "
            "Write the ENTIRE answer in Hindi only — including section titles."
            + _NATURAL_MIRROR_NOTE
        )
    if lang == "BENGALI":
        return (
            f"Detected answer language: BENGALI.{lock_note} "
            "Write the ENTIRE answer in Bengali (Bangla) only — including section titles."
            + _NATURAL_MIRROR_NOTE
        )
    if lang == "MATCH_QUESTION":
        return (
            f"Detected answer language: MATCH_QUESTION (India + world).{lock_note} "
            "You are multilingual. Write the ENTIRE answer in the SAME language as "
            "the student's question — any Indian language OR any world language "
            "(English, Spanish, French, Arabic, Chinese, Japanese, Portuguese, "
            "German, Russian, Indonesian, Turkish, etc.). "
            "Do NOT force English unless the question is in English. "
            "ANTI-LEAK: ignore the language of lecture notes / transcript / RAG. "
            "If the student wrote Latin English or Hinglish, NEVER reply in a "
            "different script just because the notes use that script."
            + _NATURAL_MIRROR_NOTE
        )
    # HINGLISH
    return (
        f"Detected answer language: HINGLISH.{lock_note} "
        "Reply in natural Hinglish (mix Hindi + English the way Indian students chat) — "
        "section titles can be English or Hinglish. Do not switch to pure English or pure "
        "Hindi unless the student asks. "
        "ANTI-LEAK: do NOT copy notes language — follow the student."
        + _NATURAL_MIRROR_NOTE
    )


def typo_intent_rule_block() -> str:
    """Silent typo / mistype tolerance for Home AI + Ask AI."""
    return """====================================================
TYPO / INTENT RULE — HARD CONSTRAINTS
====================================================
Students often mistype. ALWAYS interpret the intended meaning and answer that question.

- Fix common typos silently: missing/extra letters, swapped letters, wrong vowels,
  Hinglish mistypes, keyboard-adjacent errors, OCR-like glitches
  (e.g. "cradit econocmy" → credit economy; "fotosynthesis" → photosynthesis).
- Prefer the most likely education / ExamSpark meaning in context
  (product terms like credits, lecture, notes, quiz; and subject concepts).
- Answer the CORRECTED intent in the resolved conversation language (LANGUAGE RULE).
- Do NOT refuse or say "I don't understand" only because spelling is wrong.
- Do NOT lecture on spelling unless the student explicitly asks how to spell a word.
- If two real topics are equally plausible after correcting typos, ask ONE short
  clarifying question — do not guess wildly.
- Never invent facts: after resolving intent, still follow RAG / grounding rules
  (no match → same NOT_FOUND / knowledge behavior as today).
"""


def language_rule_block() -> str:
    return (
        """====================================================
LANGUAGE RULE — DETERMINISTIC SIGNAL + NATURAL MIRRORING
====================================================
Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

- Answer in the SAME language / chat style as the student (India or world).
- Qwen3 / model multilingual understanding should follow the student's real message,
  not the language of notes or RAG context.
- Conversation lock: keep that language across turns until the student
  clearly writes in a different, unambiguous language — no explicit
  "please switch" phrase needed for that.
- Explicit switch always wins: "I want Hinglish" / "answer in English" /
  "Hindi mein batao" / "answer in Bengali|Tamil|Spanish|French|…"
- Devanagari (pure) → Hindi. Bengali script (pure) → Bengali.
- Latin Hinglish markers → HINGLISH. Clear English Latin → ENGLISH.
- Any other script or Latin-script language (Spanish, French, Japanese…) → match that language.
- Mixed-script messages (e.g. Hindi words inside an English sentence) → treat as
  ambiguous, keep the current lock, and mirror the natural mix in your reply.

ANTI-LEAK (critical): never copy the language of lecture notes / transcript / RAG.
If notes are in the wrong language, still answer in the student's language.
"""
        + typo_intent_rule_block()
        + "\n\n"
        + GLOBAL_MULTILINGUAL_PROMPT
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
    non_latin_chars = len(_NON_LATIN_SCRIPT.findall(sample)) + (
        len(_DEVANAGARI.findall(sample)) if has_deva else 0
    ) + (len(_BENGALI.findall(sample)) if has_bengali else 0)

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
            "Do NOT translate into Hindi, Hinglish, or any other language."
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


GLOBAL_MULTILINGUAL_PROMPT = """================================================================================
GLOBAL MULTILINGUAL & SCRIPT ADAPTATION RULES (STRICT COMPLIANCE)
================================================================================
1. PRIMARY LANGUAGE DETECTION & RESOLUTION:
   - Explicit Request Priority: If the user explicitly asks for a language (e.g., "Bengali te bolo", "Hindi me samjhao", "in English"), you MUST answer entirely in that requested language.
   - Profile / Session Hint: If an app-level conversation language is provided in context, use it as the default target language.
   - Natural Mirroring: If no explicit preference is specified, automatically detect and mirror the language and dialect used in the user's input query (e.g., English, Bengali, Hindi, Hinglish, Urdu, Tamil, etc.).
2. DIALECT & ROMANIZED SCRIPT HANDLING (Hinglish / Banglish):
   - Conversational Romanized Queries: If the user writes in colloquial Romanized script (Hinglish: "ye kaise kaam karta hai" or Banglish: "eta ki bhabe kaj kore"), reply in smooth, natural conversational Hinglish/Banglish OR clear bilingual format, keeping explanations effortless to read.
   - Native Script Queries: If the user writes in native script (বাংলা script or देवनागरी), strictly formulate the explanation in that native script with authentic grammar and smooth vocabulary.
3. PRESERVATION OF TECHNICAL, MEDICAL & ACADEMIC TERMS:
   - Do NOT awkwardly machine-translate well-known technical, scientific, chemical, or medical terminology (e.g., keep "Photosynthesis", "Quadratic Equation", "Niacinamide", "Salicylic Acid", "Gravity", "Derivative", "Compiler").
   - Format technical terms with parenthetical clarification if needed in Indic languages: 
     Example: সালিসিলিক অ্যাসিড (Salicylic Acid) / प्रकाश संश्लेषण (Photosynthesis).
   - Formulas & Math: Always retain mathematical variables, LaTeX formulas ($...$ or $$...$$), and chemical equations in standard universal notation.
4. TONE, VOCABULARY & NATURAL PHRASING:
   - Never use outdated, bookish, or robotic machine-translated words that a native speaker would not use in real life.
   - Keep the flow human, helpful, polite, and culturally appropriate.
   - In code blocks, commands, and file paths, NEVER translate code syntax or keywords.
================================================================================
"""


def format_multilingual_directive(target_language: str | None = None) -> str:
    lang_str = target_language or "Auto-detect / Natural Mirroring"
    return f"""LANGUAGE & SCRIPT DIRECTIVE:
1. Target Language: {lang_str} (Override if user requests otherwise).
2. Mirror the user's communication style (English, Hindi, Hinglish, Bengali, Banglish, etc.).
3. Keep scientific, technical, skincare, and math terms in standard international English/LaTeX ($...$).
4. Provide fluent, natural explanations without awkward literal machine-translations.
"""