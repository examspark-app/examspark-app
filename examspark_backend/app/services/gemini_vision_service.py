from __future__ import annotations

import base64
import json

import httpx

from app.config import AIConfig
from app.services.qwen_vision_service import (
    VisionResult,
    _VISION_SYSTEM_PROMPT,
    _mime_from_filename,
    _normalize_notes,
)

_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"


class GeminiVisionError(Exception):
    pass


async def analyze_image(
    image_bytes: bytes,
    filename: str | None = None,
    mime_type: str | None = None,
    text_hint: str | None = None,
) -> VisionResult:
    if not AIConfig.gemini_tts_configured():
        raise GeminiVisionError("GEMINI_API_KEY not configured on the server.")
    if not image_bytes:
        raise GeminiVisionError("No image bytes received.")

    mime = mime_type or _mime_from_filename(filename)
    image_data = base64.b64encode(image_bytes).decode("ascii")
    user_text = text_hint or (
        "Treat this image as a possible learner task, not as an object to describe. "
        "First identify what the learner is being asked to do: answer questions, "
        "fill blanks, match items, complete a word bank, read labels, or solve a problem. "
        "Then actually complete that task using every visible clue.\n\n"
        "If there is a clear question/problem, answer it directly first, then explain it. "
        "If there are empty boxes/blanks beside letters, pictures, or colored word-tabs, "
        "list the answer for each blank in order. Do not stop at describing the layout. "
        "If there is no solvable activity, explain the actual content and give useful key points."
    )
    payload = {
        "systemInstruction": {"parts": [{"text": _VISION_SYSTEM_PROMPT}]},
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": user_text},
                    {"inlineData": {"mimeType": mime, "data": image_data}},
                ],
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 8192,
            "responseMimeType": "application/json",
        },
    }
    candidates = [
        AIConfig.GEMINI_VISION_MODEL,
        "gemini-flash-latest",
        "gemini-3.6-flash",
        "gemini-pro-latest",
    ]
    last_err = ""
    async with httpx.AsyncClient(timeout=12.0) as client:
        for model in candidates:
            if not model:
                continue
            url = f"{_BASE_URL}/{model}:generateContent"
            try:
                response = await client.post(
                    url,
                    headers={"x-goog-api-key": AIConfig.GEMINI_API_KEY},
                    json=payload,
                )
                if response.status_code == 200:
                    break
                last_err = f"Gemini vision {model} failed ({response.status_code}): {response.text[:200]}"
            except (httpx.TimeoutException, httpx.RequestError) as error:
                last_err = f"Gemini vision {model} network error: {error}"
        else:
            raise GeminiVisionError(f"Gemini vision failed: {last_err}")
    try:
        candidates = response.json().get("candidates") or []
        parts = (candidates[0].get("content") or {}).get("parts") or []
        content = "".join(
            part.get("text", "") for part in parts if isinstance(part, dict)
        ).strip()
        parsed = json.loads(content)
    except (IndexError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise GeminiVisionError("Gemini vision returned invalid JSON.") from error
    return VisionResult(notes=_normalize_notes(parsed), used_plus=False)
