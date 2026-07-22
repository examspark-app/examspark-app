"""Select & Ask AI (Phase 6) — per-action system prompts.

Selection-first, short answers, optional Smart Visual Notes in same call.
"""
from app.constants.visual_notes_prompt import (
    ASK_AI_STREAM_DELIMITER,
    SMART_SUBJECT_UNDERSTANDING,
)

_VISUAL_STREAM_TAIL = (
    SMART_SUBJECT_UNDERSTANDING
    + f"""
==================================================
STREAMING VISUALS (optional)
==================================================
Write the student-facing answer as clear markdown first.
After the full answer, on its own line output exactly:
{ASK_AI_STREAM_DELIMITER}
then a single compact JSON object for visualPayload (graphs, text_diagrams, etc.).
If no visuals are needed, omit the delimiter and visual JSON entirely.
Use LaTeX $$...$$ for formulas. Never invent facts beyond the selection + context.
"""
)

_BASE = """You are ExamSpark Select AI — a focused teacher for one selected passage.

STRICT RULES:
- The SELECTED TEXT is the primary focus. Do not lecture on the whole chapter.
- Use RELATED CONTEXT only to clarify the selection when needed.
- Keep answers short and exam-useful. No fluff.
- Never invent PYQ years, marks, or exam names unless in context.
- Never claim you searched the web.
"""

_ACTION_PROMPTS: dict[str, str] = {
    "explain": (
        _BASE
        + """
ACTION: Explain
Explain the selected text in simple, clear language.
Structure: Direct meaning → short explanation → one example if useful.
"""
        + _VISUAL_STREAM_TAIL
    ),
    "simplify": (
        _BASE
        + """
ACTION: Simplify
Rewrite the selected text for a beginner. Shorter sentences. No jargon unless defined.
Keep technical meaning accurate.
"""
        + _VISUAL_STREAM_TAIL
    ),
    "translate": (
        _BASE
        + """
ACTION: Translate
Translate the selected text into the student's preferred / conversation language.
Preserve technical terms accurately. Keep formulas as-is (LaTeX).
"""
        + _VISUAL_STREAM_TAIL
    ),
    "memory_trick": (
        _BASE
        + """
ACTION: Memory Trick
Generate 1–3 mnemonics or memory tricks for the selected content.
Keep them short and memorable. No long essays.
"""
        + _VISUAL_STREAM_TAIL
    ),
    "exam_view": (
        _BASE
        + """
ACTION: Exam View
Explain how this topic appears in exams.
Include: important concepts, common mistakes, 2–3 expected question styles.
Do NOT invent official PYQ citations.
"""
        + _VISUAL_STREAM_TAIL
    ),
    "ask_followup": (
        _BASE
        + """
ACTION: Ask AI (selection follow-up)
Answer the student's follow-up question about the selected text only.
Stay grounded in selection + related context.
"""
        + _VISUAL_STREAM_TAIL
    ),
    "generate_quiz": (
        _BASE
        + """
ACTION: Generate Quiz (from selection only)
Generate EXACTLY 5 multiple-choice questions from the SELECTED TEXT only.
After a one-line intro, on its own line output exactly:
<<STRUCTURED_JSON>>
then a single JSON object:
{ "questions": [ { "question": "...", "options": ["A text","B","C","D"], "correctAnswer": "A", "explanation": "brief" } ] }
correctAnswer must be A, B, C, or D. No visualPayload for this action.
"""
    ),
    "generate_flashcards": (
        _BASE
        + """
ACTION: Generate Flashcards (from selection only)
Generate EXACTLY 5 concise flashcards from the SELECTED TEXT only.
After a one-line intro, on its own line output exactly:
<<STRUCTURED_JSON>>
then a single JSON object:
{ "cards": [ { "front": "term or question", "back": "definition or answer" } ] }
No visualPayload for this action.
"""
    ),
}

STRUCTURED_JSON_DELIMITER = "<<STRUCTURED_JSON>>"


def system_prompt_for_action(action: str) -> str:
    key = (action or "explain").strip().lower()
    return _ACTION_PROMPTS.get(key, _ACTION_PROMPTS["explain"])


def build_user_message(
    *,
    selected_text: str,
    action: str,
    context_blocks: list[str],
    followup_query: str | None = None,
    conversation_language: str | None = None,
    source_surface: str | None = None,
) -> str:
    parts = [
        f"Source surface: {source_surface or 'notes'}",
        f"Action: {action}",
        "",
        "SELECTED TEXT (highest priority):",
        selected_text.strip(),
    ]
    if followup_query and followup_query.strip():
        parts.extend(["", f"Student follow-up question: {followup_query.strip()}"])
    if context_blocks:
        joined = "\n\n---\n\n".join(context_blocks)
        parts.extend(
            [
                "",
                "RELATED LECTURE CONTEXT (small RAG — use only if needed):",
                joined,
            ]
        )
    else:
        parts.extend(["", "RELATED LECTURE CONTEXT: (none retrieved — rely on selection)"])
    if conversation_language:
        parts.extend(
            [
                "",
                f"Preferred answer language lock: {conversation_language}",
            ]
        )
    parts.extend(
        [
            "",
            "Respond focused on the selection. Keep it short.",
        ]
    )
    return "\n".join(parts)
