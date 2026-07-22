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
    "You are an expert educational content analyzer. "
    "Analyze the image/diagram (OCR + meaning + math if present). "
    "Return ONLY a JSON object with these keys:\n"
    '- "cleanNotes": exam-focused markdown notes (Summary, Key Points, Explanation)\n'
    '- "keyPoints": array of short bullet strings\n'
    '- "shortSummary": 2-3 sentences\n'
    '- "importantTerms": array of {"term","definition"}\n'
    '- "visualPayload": optional object; use {} or omit if not needed\n'
    + STUDY_CONTENT_LANGUAGE_RULE
    + "\nKeep cleanNotes compact enough to finish. Raw JSON only — no markdown fences."
)

_MIN_NOTES_CHARS = 40
_VISION_MAX_TOKENS = 8192


class QwenVisionError(Exception):
    pass


class VisionResult:
    def __init__(self, notes: dict, used_plus: bool, notes_list: list[str] | None = None):
        self.notes = notes
        self.used_plus = used_plus
        self.notes_list = notes_list or []


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
    clean = (notes.get("cleanNotes") or "").strip()
    summary = (notes.get("shortSummary") or "").strip()
    key_points = notes.get("keyPoints") or []
    if len(clean) >= _MIN_NOTES_CHARS:
        return True
    if len(summary) >= 20 and isinstance(key_points, list) and len(key_points) >= 1:
        return True
    return False


def _normalize_notes(parsed: dict) -> dict:
    visual_raw = parsed.get("visualPayload") or parsed.get("visual_payload")
    visual = parse_visual_payload(visual_raw if isinstance(visual_raw, dict) else None)
    result = {
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
        "Analyze this educational image/diagram and extract study notes. "
        "LANGUAGE LOCK: write notes in the SAME language as text visible in the image "
        "(OCR language = notes language). "
        "English text in image → English notes only — do NOT translate to Hindi. "
        "Never invent Khmer/Thai/Chinese unless that script is in the image. "
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
                timeout=120.0,
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
        raise QwenVisionError(f"Qwen3-VL ({model}) returned empty content.")
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
            "Image notes failed: model output was empty. Please Retry."
        )
