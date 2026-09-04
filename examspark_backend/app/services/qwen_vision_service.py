"""Qwen3-VL via OpenRouter — image/diagram analysis with Flash → Plus escalation.

TECH_STACK.md Vision rule (Jul 12, 2026):
- Default: Qwen3-VL-Flash for every Diagram/Image/Math action
- Escalate to Qwen3-VL-Plus only when Flash output is low-confidence /
  unparseable (JSON fail, empty notes) — rare exception, never the default.

Keep the vision system prompt SHORT — a huge NOTES_SYSTEM_EXTENSION made
OpenRouter truncate mid-JSON (Unterminated string) → 500 on /process.
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging
import re

import httpx

from app.config import AIConfig
from app.constants.visual_notes_prompt import STUDY_CONTENT_LANGUAGE_RULE
from app.models.visual_payload import parse_visual_payload
from app.services.qwen_service import _extract_json_object

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Compact prompt only — full visual schema belongs in text-notes path, not VL.
_VISION_SYSTEM_PROMPT = (
    "You are an expert visual content analyzer, OCR engine, and exam tutor. "
    "Analyze the image carefully using OCR, visual understanding, diagrams, "
    "tables, charts, equations, handwriting, and all visible content. "
    "Return ONLY a valid JSON object with these keys:\n"
    '- "contentType": EXACTLY one of: "question_paper" | "notes" | "textbook" | '
    '"diagram" | "handwritten_work" | "document" | "other"\n'
    '- "detectedIntent": EXACTLY one of: "solve_problem" | "diagnose_error" | "multi_question" | "explain_concept" | "summarize_notes"\n'
    '- "recognizedTopic": Short 1-line label of the primary question, problem, or concept recognized (e.g. "Quadratic Equation: 2x² - 5x + 3 = 0" or "Newton\'s 2nd Law (F=ma)")\n'
    '- "studentAttempt": IF contentType is "handwritten_work" or student attempt is visible → '
    '{"attemptFound": true, "correctSteps": ["Step 1..."], "errorStep": "Step 2: sign error...", "advice": "Watch negative sign when factoring"}; ELSE null\n'
    '- "extractedText": verbatim readable text found in the image — questions, '
    'numbers, labels, sentences exactly as written with math in LaTeX format; empty string if nothing readable\n'
    '- "questionsFound": array of question strings detected; '
    'each element is one question/problem as written; [] if none\n'
    '- "cleanNotes": '
    'IF detectedIntent is "solve_problem" or contentType is "question_paper" → '
    'write step-by-step pedagogical solutions using LaTeX math ($...$ or $$...$$): Given, Formula, Calculation, Final Answer; '
    'IF detectedIntent is "diagnose_error" → evaluate the student\'s steps, state what was right, pinpoint mistake, and provide correct solution; '
    'ELSE → exam-focused explanation of what the image contains\n'
    '- "shortSummary": 2-3 sentences: what the image is and its main content\n'
    '- "keyPoints": array of short bullet strings (key facts, steps, or findings)\n'
    '- "importantTerms": array of {"term","definition"} for any technical terms\n'
    '- "visualPayload": optional diagram/chart object matching the 10 Visual Auto-Trigger Rules; omit or use {} if not needed\n'
    + STUDY_CONTENT_LANGUAGE_RULE
    + "\nCRITICAL RULES:\n"
    "1. Math Formulas: Always write mathematical formulas, variables, and equations in clean standard LaTeX ($...$ or $$...$$).\n"
    "2. Student Intent Understanding: If the image shows handwritten calculations, classify as 'diagnose_error' and analyze the student's work step-by-step.\n"
    "3. Multi-Question Detection: If multiple questions appear, list all of them in questionsFound, solve the primary/first question in cleanNotes.\n"
    "4. Treat every worksheet, exercise, question paper, or activity as a task to complete, not a picture to describe.\n"
    "5. extractedText must contain the actual readable text verbatim — never paraphrase it.\n"
    "6. Never invent text, objects, or context not visible in the image.\n"
    "7. Answer in the language of the user's query if provided; otherwise use the image's dominant language.\n"
    "8. Raw JSON only — no markdown fences. Keep response complete and compact."
)

_MIN_NOTES_CHARS = 40
_VISION_MAX_TOKENS = 8192


class QwenVisionError(Exception):
    pass


class VisionResult:
    def __init__(self, notes: dict, used_plus: bool, notes_list: list[str] | None = None, model_name: str | None = None):
        self.notes = notes
        self.used_plus = used_plus
        self.notes_list = notes_list or []
        self.model_name = model_name or ""


def _mime_from_filename(filename: str | None) -> str:
    name = (filename or "").lower()
    if name.endswith(".png"):
        return "image/png"
    if name.endswith(".jpg") or name.endswith(".jpeg"):
        return "image/jpeg"
    if name.endswith(".webp"):
        return "image/webp"
    if name.endswith(".gif"):
        return "image/gif"
    return "image/jpeg"


def _notes_usable(notes: dict) -> bool:
    """
    Decide whether the vision response contains enough useful content.
    importantTerms and keyPoints are optional.
    """
    clean = (notes.get("cleanNotes") or "").strip()
    summary = (notes.get("shortSummary") or "").strip()
    key_points = notes.get("keyPoints") or []
    important_terms = notes.get("importantTerms") or []

    valid_key_points = (
        isinstance(key_points, list)
        and any(str(item).strip() for item in key_points)
    )

    valid_terms = (
        isinstance(important_terms, list)
        and any(
            (
                isinstance(item, dict)
                and str(item.get("term") or "").strip()
            )
            or (
                not isinstance(item, dict)
                and str(item).strip()
            )
            for item in important_terms
        )
    )

    if len(clean) >= 80:
        return True

    if len(summary) >= 30:
        return True

    if valid_key_points:
        return True

    if valid_terms:
        return True

    # New: extracted text alone is enough — vision model read the image
    extracted = (notes.get("extractedText") or "").strip()
    if len(extracted) >= 20:
        return True

    return False
    


def _normalize_notes(parsed: dict) -> dict:
    visual_raw = parsed.get("visualPayload") or parsed.get("visual_payload")
    visual = parse_visual_payload(visual_raw if isinstance(visual_raw, dict) else None)
    result = {
        "contentType": (parsed.get("contentType") or "other").strip().lower(),
        "detectedIntent": (parsed.get("detectedIntent") or "solve_problem").strip().lower(),
        "recognizedTopic": (parsed.get("recognizedTopic") or "").strip(),
        "studentAttempt": parsed.get("studentAttempt") if isinstance(parsed.get("studentAttempt"), dict) else None,
        "extractedText": (parsed.get("extractedText") or "").strip(),
        "questionsFound": parsed.get("questionsFound") or [],
        "cleanNotes": parsed.get("cleanNotes", "") or "",
        "keyPoints": parsed.get("keyPoints", []) or [],
        "shortSummary": parsed.get("shortSummary", "") or "",
        "importantTerms": parsed.get("importantTerms", []) or [],
    }
    if visual is not None:
        result["visualPayload"] = visual.model_dump(by_alias=False)
    return result


def _close_truncated_json(raw: str) -> str:
    """Best-effort close for truncated model output (Unterminated string)."""
    s = raw.strip()
    if s.startswith("```"):
        s = s.strip("`")
        if s.lower().startswith("json"):
            s = s[4:].lstrip()
    start = s.find("{")
    if start == -1:
        return s
    s = s[start:]
    # If cleanNotes string was cut, close it then close object.
    if '"cleanNotes"' in s and s.count('"') % 2 == 1:
        s += '"'
    # Close open braces/brackets
    open_curly = s.count("{") - s.count("}")
    open_square = s.count("[") - s.count("]")
    s += "]" * max(0, open_square)
    s += "}" * max(0, open_curly)
    return s


def _parse_vision_json(content: str, model: str) -> dict:
    try:
        return _extract_json_object(content)
    except (json.JSONDecodeError, ValueError):
        pass
    repaired = _close_truncated_json(content)
    try:
        return json.loads(repaired)
    except json.JSONDecodeError:
        pass
    # Last salvage: pull cleanNotes text if present
    m = re.search(
        r'"cleanNotes"\s*:\s*"(.*)',
        content,
        flags=re.DOTALL,
    )
    if m:
        chunk = m.group(1)
        # Stop at unescaped newline ending mid-json if possible
        chunk = chunk.replace('\\"', '"')
        if len(chunk) >= _MIN_NOTES_CHARS:
            logger.warning(
                "Vision JSON salvage used cleanNotes only model=%s chars=%s",
                model,
                len(chunk),
            )
            return {
                "cleanNotes": chunk[:8000],
                "keyPoints": [],
                "shortSummary": chunk[:240],
                "importantTerms": [],
            }
    raise QwenVisionError(
        f"Qwen3-VL ({model}) returned unparseable JSON (truncated or invalid)."
    )


async def _call_vision_model(
    client: httpx.AsyncClient,
    model: str,
    image_bytes: bytes,
    mime_type: str,
    text_hint: str | None,
) -> dict:
    if not AIConfig.openrouter_configured():
        raise QwenVisionError("OPENROUTER_API_KEY not configured on the server.")

    b64 = base64.b64encode(image_bytes).decode("ascii")
    data_url = f"data:{mime_type};base64,{b64}"
    user_text = text_hint or (
    "Treat this image as a possible learner task, not as an object to describe. "
    "First identify what the learner is being asked to do: answer questions, "
    "fill blanks, match items, complete a word bank, read labels, or solve a problem. "
    "Then actually complete that task using every visible clue.\n\n"

    "FIRST determine:\n"
    "- what the image contains (question, notes, textbook page, diagram, chart, table, "
    "formula, document, handwritten work, photo, or other content);\n"
    "- whether there is a clear question, exercise, or problem;\n"
    "- the main topic, only when supported by visible/readable content;\n"
    "- the language of the visible text.\n\n"

    "RESPONSE RULES:\n"
    "- If there is a clear question/problem, answer it directly first, then explain it.\n"
    "- If there are empty boxes/blanks beside letters, pictures, or colored word-tabs, "
    "recognize the fill-in or matching exercise and list the answer for each blank in order.\n"
    "- If there are multiple questions, address them clearly in order.\n"
    "- If there is no question or solvable activity, explain the actual content and give useful key points.\n"
    "- If it is clearly study/exam material, make the explanation exam-useful.\n"
    "- If the user message requests a specific language or level, follow that request.\n"
    "- Do not invent text, objects, topics, class level, people, language, or context.\n"
    "- If text is blurry, cropped, or unreadable, say so instead of guessing.\n"
    "- Carefully inspect diagrams, charts, tables, equations, labels, and images; "
    "they are part of the meaning and must not be ignored.\n\n"

    "Write the answer in the user's requested language when a user request is provided. "
    "When there is no user request, use the clearest language supported by the visible text. "
    "Keep JSON complete and compact."
)

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": _VISION_SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_text},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ],
        "temperature": 0.2,
        "max_tokens": _VISION_MAX_TOKENS,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }

    response = None
    for attempt in range(2):
        try:
            response = await client.post(
                _OPENROUTER_URL,
                headers=headers,
                json=payload,
                timeout=35.0,
            )
            break
        except httpx.TransportError as e:
            if attempt == 0:
                logger.warning("Vision OpenRouter transport error, retrying once: %s", e)
                await asyncio.sleep(2)
                continue
            raise QwenVisionError(
                "Network error talking to OpenRouter — please retry on a stable connection."
            ) from e

    if response is None:
        raise QwenVisionError(
            "Network error talking to OpenRouter — please retry on a stable connection."
        )

    if response.status_code != 200:
        raise QwenVisionError(
            f"Qwen3-VL ({model}) failed: {response.status_code} {response.text[:300]}"
        )

    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        err = data.get("error") or data
        raise QwenVisionError(
            f"Qwen3-VL ({model}) returned no choices: {str(err)[:300]}"
        )
    content = choices[0].get("message", {}).get("content") or ""

    if not content.strip():
        finish_reason = choices[0].get("finish_reason")

        logger.error(
            "Vision model returned empty content: model=%s finish_reason=%s response_id=%s",
            model,
            finish_reason,
            data.get("id"),
        )

        raise QwenVisionError(
            f"Qwen3-VL ({model}) returned empty content."
        )

    parsed = _parse_vision_json(content, model)
    return _normalize_notes(parsed)


async def analyze_image(
    image_bytes: bytes,
    filename: str | None = None,
    mime_type: str | None = None,
    text_hint: str | None = None,
) -> VisionResult:
    """Flash first; auto-escalate to Plus on unusable / unparseable Flash output."""
    if not image_bytes:
        raise QwenVisionError("No image bytes received.")

    mime = mime_type or _mime_from_filename(filename)
    notes_meta: list[str] = []

    async with httpx.AsyncClient() as client:
        flash_notes: dict | None = None
        flash_err: QwenVisionError | None = None
        try:
            flash_notes = await _call_vision_model(
                client,
                AIConfig.AI_VISION_FLASH_MODEL,
                image_bytes,
                mime,
                text_hint,
            )
        except QwenVisionError as e:
            flash_err = e
            notes_meta.append(f"Flash call failed ({e}); escalating to Plus.")
            logger.warning("Vision Flash failed, escalating to Plus: %s", e)

        if flash_notes is not None and _notes_usable(flash_notes):
            return VisionResult(notes=flash_notes, used_plus=False, notes_list=notes_meta)

        if flash_notes is not None and not _notes_usable(flash_notes):
            notes_meta.append("Flash output low quality / empty; escalating to Plus.")
            logger.info("Vision Flash output unusable; escalating to Plus.")

        try:
            plus_notes = await _call_vision_model(
                client,
                AIConfig.AI_VISION_PLUS_MODEL,
                image_bytes,
                mime,
                text_hint,
            )
        except QwenVisionError as e:
            notes_meta.append(f"Plus escalation also failed ({e}).")
            logger.warning("Vision Plus escalation failed: %s", e)
            if flash_notes is not None and _notes_usable(flash_notes):
                return VisionResult(
                    notes=flash_notes, used_plus=False, notes_list=notes_meta
                )
            # Do not return empty notes (caused opaque L101/500 later).
            raise QwenVisionError(
                "Image notes failed: vision model returned incomplete JSON. "
                "Please Retry once — your photo is fine; the model cut off mid-response."
            ) from (e if flash_err is None else flash_err)

        if _notes_usable(plus_notes):
            return VisionResult(notes=plus_notes, used_plus=True, notes_list=notes_meta)

        if flash_notes is not None and _notes_usable(flash_notes):
            return VisionResult(notes=flash_notes, used_plus=False, notes_list=notes_meta)

        raise QwenVisionError(
            "Image analysis returned unusable or incomplete content after Flash and Plus attempts. "
            "Please Retry."
        )
