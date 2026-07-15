"""Qwen3-VL via OpenRouter — image/diagram analysis with Flash → Plus escalation.

TECH_STACK.md Vision rule (Jul 12, 2026):
- Default: Qwen3-VL-Flash for every Diagram/Image/Math action
- Escalate to Qwen3-VL-Plus only when Flash output is low-confidence /
  unparseable (JSON fail, empty notes) — rare exception, never the default.
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging

import httpx

from app.config import AIConfig
from app.services.qwen_service import _extract_json_object

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

_VISION_SYSTEM_PROMPT = (
    "You are an expert educational content analyzer. Analyze the provided "
    "image/diagram (OCR + diagram meaning + math if present) and return ONLY "
    "a JSON object with these exact keys:\n"
    '- "cleanNotes": well-formatted, organized notes in markdown\n'
    '- "keyPoints": array of short bullet-point strings for the main concepts\n'
    '- "shortSummary": a 2-3 sentence summary\n'
    '- "importantTerms": array of objects, each with "term" and "definition"\n'
    "Return raw JSON only, no markdown code fences, no commentary."
)

_MIN_NOTES_CHARS = 40


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
    return {
        "cleanNotes": parsed.get("cleanNotes", "") or "",
        "keyPoints": parsed.get("keyPoints", []) or [],
        "shortSummary": parsed.get("shortSummary", "") or "",
        "importantTerms": parsed.get("importantTerms", []) or [],
    }


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
    user_text = text_hint or "Analyze this educational image/diagram and extract study notes."

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
        "temperature": 0.3,
        "max_tokens": 4096,
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
    try:
        parsed = _extract_json_object(content)
    except (json.JSONDecodeError, ValueError) as e:
        raise QwenVisionError(f"Qwen3-VL ({model}) returned unparseable JSON: {e}") from e
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
        try:
            flash_notes = await _call_vision_model(
                client,
                AIConfig.AI_VISION_FLASH_MODEL,
                image_bytes,
                mime,
                text_hint,
            )
        except QwenVisionError as e:
            notes_meta.append(f"Flash call failed ({e}); escalating to Plus.")
            logger.warning("Vision Flash failed, escalating to Plus: %s", e)
            plus_notes = await _call_vision_model(
                client,
                AIConfig.AI_VISION_PLUS_MODEL,
                image_bytes,
                mime,
                text_hint,
            )
            return VisionResult(notes=plus_notes, used_plus=True, notes_list=notes_meta)

        if _notes_usable(flash_notes):
            return VisionResult(notes=flash_notes, used_plus=False, notes_list=notes_meta)

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
            notes_meta.append(f"Plus escalation also failed ({e}); returning Flash output.")
            logger.warning("Vision Plus escalation failed: %s", e)
            return VisionResult(notes=flash_notes, used_plus=False, notes_list=notes_meta)

        return VisionResult(notes=plus_notes, used_plus=True, notes_list=notes_meta)
