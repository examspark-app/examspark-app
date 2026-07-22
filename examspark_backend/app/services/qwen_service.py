"""Qwen3 32B via OpenRouter — notes/summary generation from a transcript.

Groq does not host Qwen3, so this goes through OpenRouter (AI_CHAT_MODEL,
default `qwen/qwen3` — see .env.example / TECH_STACK.md AI Pipeline table).
"""
import json

import httpx

from app.config import AIConfig
from app.constants.language_hint import notes_language_user_line
from app.constants.visual_notes_prompt import (
    MEDIUM_NOTES_SYSTEM_EXTENSION,
    NOTES_SYSTEM_EXTENSION,
    REVISION_VISUAL_EXTENSION,
    SHORT_NOTES_SYSTEM_EXTENSION,
    STUDY_CONTENT_LANGUAGE_RULE,
    notes_band_for_transcript,
)
from app.models.visual_payload import parse_visual_payload

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

_NOTES_JSON_KEYS = (
    "You are an expert educational content processor — an intelligent teacher, not a chatbot. "
    "Process the lecture content and return ONLY a JSON object with these exact keys:\n"
    '- "cleanNotes": well-formatted exam-focused notes in markdown (Summary, Key Points, '
    "Detailed Explanation, equations in LaTeX $$...$$, markdown tables when comparing)\n"
    '- "keyPoints": array of short bullet-point strings for the main concepts\n'
    '- "shortSummary": a 2-3 sentence summary\n'
    '- "importantTerms": array of objects, each with "term" and "definition"\n'
    '- "visualPayload": structured visual aids object (see schema below)\n'
)

_NOTES_SYSTEM_PROMPT = (
    _NOTES_JSON_KEYS
    + NOTES_SYSTEM_EXTENSION
    + "\nReturn raw JSON only, no markdown code fences, no commentary."
)

_NOTES_SYSTEM_PROMPT_SHORT = (
    _NOTES_JSON_KEYS
    + SHORT_NOTES_SYSTEM_EXTENSION
    + "\nReturn raw JSON only, no markdown code fences, no commentary."
)

_NOTES_SYSTEM_PROMPT_MEDIUM = (
    _NOTES_JSON_KEYS
    + MEDIUM_NOTES_SYSTEM_EXTENSION
    + "\nReturn raw JSON only, no markdown code fences, no commentary."
)

# max_tokens by band — same schema keys; short/medium clips finish sooner.
_NOTES_MAX_TOKENS = {"short": 2560, "medium": 4096, "long": 6144}


class QwenGenerationError(Exception):
    pass


def _extract_json_object(raw: str) -> dict:
    """Best-effort JSON extraction — some OpenRouter providers ignore
    response_format and wrap JSON in prose or code fences / truncate mid-string."""
    raw = (raw or "").strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:].lstrip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            pass

    # Truncated / bad commas — close open string + braces, then parse.
    if start != -1:
        chunk = raw[start:]
        if chunk.count('"') % 2 == 1:
            chunk += '"'
        open_curly = chunk.count("{") - chunk.count("}")
        open_square = chunk.count("[") - chunk.count("]")
        chunk += "]" * max(0, open_square)
        chunk += "}" * max(0, open_curly)
        try:
            return json.loads(chunk)
        except json.JSONDecodeError:
            pass
        # Decoder may still recover a prefix object
        try:
            obj, _ = json.JSONDecoder().raw_decode(chunk)
            if isinstance(obj, dict):
                return obj
        except json.JSONDecodeError:
            pass

    # Salvage cleanNotes if present
    import re

    m = re.search(r'"cleanNotes"\s*:\s*"(.*)', raw, flags=re.DOTALL)
    if m:
        text = m.group(1)
        # Unescape common sequences; stop before a clear next-key if any
        cut = re.search(r'"\s*,\s*"(?:keyPoints|shortSummary|importantTerms|visualPayload)"', text)
        if cut:
            text = text[: cut.start()]
        text = text.replace('\\"', '"').replace("\\n", "\n")
        if len(text.strip()) >= 40:
            return {
                "cleanNotes": text.strip()[:12000],
                "keyPoints": [],
                "shortSummary": text.strip()[:240],
                "importantTerms": [],
            }

    raise json.JSONDecodeError("Could not parse model JSON", raw, 0)


def _notes_prompt_and_max_tokens(
    transcript_text: str,
    *,
    duration_minutes: int | None = None,
) -> tuple[str, int, str]:
    """Pick system prompt + max_tokens from duration and/or transcript length."""
    band = notes_band_for_transcript(
        transcript_text, duration_minutes=duration_minutes
    )
    if band == "short":
        return _NOTES_SYSTEM_PROMPT_SHORT, _NOTES_MAX_TOKENS["short"], band
    if band == "medium":
        return _NOTES_SYSTEM_PROMPT_MEDIUM, _NOTES_MAX_TOKENS["medium"], band
    return _NOTES_SYSTEM_PROMPT, _NOTES_MAX_TOKENS["long"], band


async def generate_notes(
    transcript_text: str,
    *,
    duration_minutes: int | None = None,
) -> dict:
    """Returns {cleanNotes, keyPoints, shortSummary, importantTerms, visualPayload?}."""
    if not AIConfig.openrouter_configured():
        raise QwenGenerationError("OPENROUTER_API_KEY not configured on the server.")

    system_prompt, max_tokens, band = _notes_prompt_and_max_tokens(
        transcript_text, duration_minutes=duration_minutes
    )

    async with httpx.AsyncClient() as client:
        response = await client.post(
            _OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": AIConfig.AI_CHAT_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": (
                            "Create study notes from this transcript. "
                            "Return complete valid JSON only.\n"
                            + notes_language_user_line(transcript_text or "")
                            + "\n\n"
                            + (transcript_text or "")
                        ),
                    },
                ],
                "temperature": 0.2,
                "max_tokens": max_tokens,
                "response_format": {"type": "json_object"},
            },
            timeout=180.0,
        )

    if response.status_code != 200:
        raise QwenGenerationError(f"Qwen3 (OpenRouter) failed: {response.status_code} {response.text[:300]}")

    data = response.json()
    content = data["choices"][0]["message"]["content"]
    try:
        parsed = _extract_json_object(content)
    except (json.JSONDecodeError, ValueError, TypeError) as e:
        raise QwenGenerationError(
            f"Qwen3 notes JSON parse failed: {e}. Please Retry."
        ) from e

    visual_raw = parsed.get("visualPayload") or parsed.get("visual_payload")
    visual = parse_visual_payload(visual_raw if isinstance(visual_raw, dict) else None)

    logger = __import__("logging").getLogger(__name__)
    logger.info(
        "generate_notes band=%s max_tokens=%s transcript_chars=%s",
        band,
        max_tokens,
        len(transcript_text or ""),
    )

    result = {
        "cleanNotes": parsed.get("cleanNotes", ""),
        "keyPoints": parsed.get("keyPoints", []) or [],
        "shortSummary": parsed.get("shortSummary", ""),
        "importantTerms": parsed.get("importantTerms", []) or [],
    }
    if not (result["cleanNotes"] or "").strip() and (result["shortSummary"] or "").strip():
        result["cleanNotes"] = result["shortSummary"]
    if len((result["cleanNotes"] or "").strip()) < 40:
        raise QwenGenerationError(
            "Qwen3 notes were too short or incomplete. Please Retry."
        )
    if visual is not None:
        result["visualPayload"] = visual.model_dump(by_alias=False)
    return result


_FLASHCARDS_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate study flashcards from the lecture content. Return ONLY JSON:\n"
    '{ "cards": [ { "front": "question or term", "back": "answer or definition" } ] }\n'
    "Create 10-15 cards covering the main concepts. Raw JSON only."
)

_QUIZ_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate exactly 20 multiple-choice questions from the lecture content. "
    "Return ONLY JSON:\n"
    '{ "questions": [ { "question": "...", "options": ["opt A text", "opt B", "opt C", "opt D"], '
    '"correctAnswer": "A", "explanation": "brief why" } ] }\n'
    "correctAnswer must be a single letter A, B, C, or D matching the options index. "
    "Raw JSON only."
)

_REVISION_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate a comprehensive exam-focused revision sheet from the lecture content. "
    "Return ONLY JSON:\n"
    '{ "revisionSheet": "markdown with ## headings, bullet points, key formulas (LaTeX $$...$$), and summary", '
    '"visualPayload": { ... optional same schema as lecture notes ... } }\n'
    + REVISION_VISUAL_EXTENSION
    + "\nCover main concepts, definitions, formulas, and quick recap points. Raw JSON only."
)

_FIVE_MIN_REVISION_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate a SHORT 5-minute revision recap from the lecture content — "
    "something a student can skim in about five minutes before an exam. "
    "Return ONLY JSON:\n"
    '{ "revisionSheet": "compact markdown: ## Must-know (5-8 bullets), ## Formulas '
    '(LaTeX $$...$$ if any), ## One-line traps, ## 60-second summary", '
    '"visualPayload": { ... optional, only if a tiny diagram/table clearly helps } }\n'
    + REVISION_VISUAL_EXTENSION
    + "\nKeep total content short (roughly 250-450 words). No long essays. Raw JSON only."
)

_IMPORTANT_QUESTIONS_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate important exam-style questions from the study content. Return ONLY JSON:\n"
    '{ "questions": [ { "question": "...", "type": "short_answer|long_answer|numerical", '
    '"marks": 2, "hint": "brief study hint without giving the full answer" } ] }\n'
    "Create exactly 8 questions (easy→hard). "
    "If EXAM FOCUS lines are present, bias MORE questions toward high weightage chapters "
    "(weightage 5 = highest chance). Metadata tags only — never invent or quote original "
    "exam paper question text, options, or answer keys. Raw JSON only."
)

_MIND_MAP_SYSTEM = (
    STUDY_CONTENT_LANGUAGE_RULE
    + "\nGenerate a hierarchical mind map from the lecture content. Return ONLY JSON:\n"
    '{ "title": "topic title", "root": { "label": "central concept", "children": [ '
    '{ "label": "branch", "children": [ { "label": "leaf detail", "children": [] } ] } ] } }\n'
    "Use 4-8 main branches with 2-4 nested children where helpful. Raw JSON only."
)


async def _chat_json(system_prompt: str, user_content: str, *, max_tokens: int = 4096) -> dict:
    if not AIConfig.openrouter_configured():
        raise QwenGenerationError("OPENROUTER_API_KEY not configured on the server.")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            _OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": AIConfig.AI_CHAT_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content},
                ],
                "temperature": 0.3,
                "max_tokens": max_tokens,
                "response_format": {"type": "json_object"},
            },
            timeout=120.0,
        )

    if response.status_code != 200:
        raise QwenGenerationError(
            f"Qwen3 (OpenRouter) failed: {response.status_code} {response.text[:300]}"
        )

    data = response.json()
    content = data["choices"][0]["message"]["content"]
    return _extract_json_object(content)


async def generate_flashcards(source_text: str) -> dict:
    """Returns {cards: [{front, back}, ...]}."""
    parsed = await _chat_json(_FLASHCARDS_SYSTEM, source_text, max_tokens=4096)
    cards = parsed.get("cards") or []
    if not isinstance(cards, list) or len(cards) < 3:
        raise QwenGenerationError("Flashcard generation returned too few cards.")
    return {"cards": cards}


async def generate_quiz_mcq(source_text: str) -> dict:
    """Returns {questions: [{question, options, correctAnswer, explanation?}, ...]}."""
    parsed = await _chat_json(_QUIZ_SYSTEM, source_text, max_tokens=8192)
    questions = parsed.get("questions") or []
    if not isinstance(questions, list) or len(questions) < 5:
        raise QwenGenerationError("Quiz generation returned too few questions.")
    return {"questions": questions}


async def generate_revision_sheet(source_text: str) -> dict:
    """Returns {revisionSheet, visualPayload?}."""
    parsed = await _chat_json(_REVISION_SYSTEM, source_text, max_tokens=6144)
    sheet = (parsed.get("revisionSheet") or parsed.get("revision_sheet") or "").strip()
    if len(sheet) < 80:
        raise QwenGenerationError("Revision sheet generation returned too little content.")
    result: dict = {"revisionSheet": sheet}
    visual_raw = parsed.get("visualPayload") or parsed.get("visual_payload")
    visual = parse_visual_payload(visual_raw if isinstance(visual_raw, dict) else None)
    if visual is not None:
        result["visualPayload"] = visual.model_dump(by_alias=False)
    return result


async def generate_five_min_revision(source_text: str) -> dict:
    """Returns short {revisionSheet, visualPayload?} for 5-minute Home chip."""
    parsed = await _chat_json(_FIVE_MIN_REVISION_SYSTEM, source_text, max_tokens=3072)
    sheet = (parsed.get("revisionSheet") or parsed.get("revision_sheet") or "").strip()
    if len(sheet) < 60:
        raise QwenGenerationError("5-minute revision returned too little content.")
    result: dict = {"revisionSheet": sheet}
    visual_raw = parsed.get("visualPayload") or parsed.get("visual_payload")
    visual = parse_visual_payload(visual_raw if isinstance(visual_raw, dict) else None)
    if visual is not None:
        result["visualPayload"] = visual.model_dump(by_alias=False)
    return result


def _count_mind_map_nodes(node: dict) -> int:
    if not isinstance(node, dict):
        return 0
    count = 1 if (node.get("label") or "").strip() else 0
    for child in node.get("children") or []:
        if isinstance(child, dict):
            count += _count_mind_map_nodes(child)
    return count


async def generate_important_questions(source_text: str) -> dict:
    """Returns {questions: [{question, type, marks, hint?}, ...]}."""
    parsed = await _chat_json(_IMPORTANT_QUESTIONS_SYSTEM, source_text, max_tokens=2200)
    questions = parsed.get("questions") or []
    if not isinstance(questions, list) or len(questions) < 5:
        raise QwenGenerationError(
            "Important questions generation returned too few questions."
        )
    return {"questions": questions[:8]}


async def generate_mind_map(source_text: str) -> dict:
    """Returns {title, root: {label, children: [...]}}."""
    parsed = await _chat_json(_MIND_MAP_SYSTEM, source_text, max_tokens=4096)
    title = (parsed.get("title") or "").strip()
    root = parsed.get("root")
    if not isinstance(root, dict) or _count_mind_map_nodes(root) < 4:
        raise QwenGenerationError("Mind map generation returned too little structure.")
    return {"title": title or "Mind Map", "root": root}
