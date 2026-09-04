"""Education answer intelligence — understand question intent, then answer.

Home AI + Ask AI share this. Goal: tutor feel, NOT a fixed section template.
"""
from __future__ import annotations

import re
from typing import Literal

QuestionIntent = Literal[
    "greeting",
    "definition",
    "how_why",
    "compare",
    "short_exam",
    "long_exam",
    "numerical",
    "list",
    "general",
]

_GREETING = re.compile(r"(?i)^(hi+|hello|hey|ok|okay|thanks|thank\s*you)\b")
_DEFINE = re.compile(
    r"(?i)\b(what\s+is|what's|define|definition|meaning\s+of|kya\s+hai|"
    r"matlab\s+kya|kis[e]?\s+kahte)\b"
)
_HOW_WHY = re.compile(
    r"(?i)\b(how\s+(does|do|can|to)|why|kaise|kyun|kyunki|"
    r"explain|samjhao|samjha|describe)\b"
)
_COMPARE = re.compile(
    r"(?i)\b(difference|compare|vs\.?|versus|between|farq|"
    r"difference\s+between|distinguish)\b"
)
_SHORT_EXAM = re.compile(
    r"(?i)\b(short\s+answer|in\s+(one|1|two|2)\s+(line|sentence)s?|"
    r"briefly|one\s+mark|2\s*marks?|very\s+short)\b"
)
_LONG_EXAM = re.compile(
    r"(?i)\b(long\s+answer|in\s+detail|detailed|explain\s+clearly|"
    r"step\s+by\s+step|exam\s+style|5\s*marks?|8\s*marks?|"
    r"full\s+answer|pura\s+samjhao|detail\s+mein)\b"
)
_NUMERICAL = re.compile(
    r"(?i)\b(calculate|find\s+the\s+value|solve|numerical|"
    r"how\s+much|formula|equation|=\s*\d|x\s*\^)\b"
)
_LIST = re.compile(
    r"(?i)\b(list|enumerate|points|key\s+points|important\s+points|"
    r"types\s+of|steps\s+of|batao\s+points)\b"
)

# Shared system-prompt block (Home + Ask)
ANSWER_INTELLIGENCE_BLOCK = """
==================================================
ANSWER INTELLIGENCE (HARD — no template feel)
==================================================
You are a sharp education tutor for Class 11–12 / NEET / board exams.

STEP 1 — UNDERSTAND the student's real ask (silently):
  greeting | definition | how/why | compare | short exam | long exam |
  numerical | list | general doubt
Do NOT write the intent label in the answer.

STEP 2 — ANSWER that intent only. Match length to the ask:
  • greeting → 1–2 friendly study lines
  • definition / "what is" → 2–4 natural sentences (idea + one clear detail)
  • how / why / explain → clear flowing explanation; add a tiny example only if it helps
  • compare → side-by-side contrast in plain language (not forced tables)
  • short exam / "in one line" → exam-short, crisp
  • long exam / "explain clearly" / detail → fuller but still structured naturally
  • numerical → show steps briefly, then final value
  • list → tight bullets only when listing is the ask

ANTI-TEMPLATE (HARD):
• Do NOT paste the same skeleton every time
  (Direct Answer / Easy Explanation / Key Points / Source / Exam Tip).
• Prefer natural paragraphs like a good teacher speaking.
• Use a markdown header ONLY when it truly helps a long/multi-part answer.
• Never invent filler sections. Never "N/A" under a header.
• Visuals: follow VISUAL AUTO-TRIGGER RULES — auto-generate visual diagram when topic has a process, cycle, mechanism, formula, graph, or structure; skip only for greetings or simple 1-line factual lookups.

Tone: clear, kind, exam-useful. India student first. No chatbot fluff.
"""


def detect_question_intent(query: str) -> QuestionIntent:
    q = (query or "").strip()
    if not q:
        return "general"
    if len(q) <= 12 and _GREETING.search(q):
        return "greeting"
    if _NUMERICAL.search(q):
        return "numerical"
    if _COMPARE.search(q):
        return "compare"
    if _LONG_EXAM.search(q) or len(q) > 180:
        return "long_exam"
    if _SHORT_EXAM.search(q):
        return "short_exam"
    if _LIST.search(q):
        return "list"
    if _HOW_WHY.search(q):
        return "how_why"
    if _DEFINE.search(q) and len(q) < 120:
        return "definition"
    return "general"


def answer_intelligence_user_line(query: str, mode: str = "normal") -> str:
    """Per-turn coach line: intent + length + anti-template."""
    intent = detect_question_intent(query)
    deep = (mode or "normal").lower() == "deep"

    intent_guide = {
        "greeting": (
            "Intent: greeting. Reply 1–2 friendly study-coach sentences. "
            "No sections. No diagram."
        ),
        "definition": (
            "Intent: definition / what-is. Write 2–4 natural sentences "
            "(core meaning + one useful detail). No section headers."
        ),
        "how_why": (
            "Intent: how/why/explain. Give a clear flowing explanation a Class 12 "
            "student can follow. Example only if it helps. Avoid template headers."
        ),
        "compare": (
            "Intent: compare/difference. Contrast the ideas in plain language "
            "(short paragraphs or tight bullets). No forced table."
        ),
        "short_exam": (
            "Intent: short exam answer. Keep it crisp and mark-worthy — "
            "short paragraph or 2–3 tight lines. No fluff headers."
        ),
        "long_exam": (
            "Intent: long / clear explanation. Fuller tutor answer — still natural "
            "prose. Optional short bullets only if multi-part. No checklist spam."
        ),
        "numerical": (
            "Intent: numerical/solve. Brief steps, then the final answer clearly. "
            "No unrelated sections."
        ),
        "list": (
            "Intent: list/points. Give a tight, well-ordered list only — "
            "no long essay around it."
        ),
        "general": (
            "Intent: general study doubt. Answer what they asked — nothing more. "
            "Natural tutor tone, not a fixed template."
        ),
    }[intent]

    mode_line = (
        "Mode: deep — fuller exam-ready depth, still no template spam."
        if deep
        else "Mode: normal — compact and sharp; chips can deepen later."
    )

    return (
        f"ANSWER INTELLIGENCE FOR THIS TURN:\n"
        f"{intent_guide}\n"
        f"{mode_line}\n"
        "Remember: understand first, then answer. Never reuse a fixed section template."
    )
