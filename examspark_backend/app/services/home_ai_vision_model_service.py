from __future__ import annotations

import logging

from app.services.gemini_vision_service import GeminiVisionError, analyze_image as analyze_gemini
from app.services.qwen_vision_service import QwenVisionError, VisionResult, analyze_image as analyze_qwen

logger = logging.getLogger(__name__)

# --- Model display names for frontend ---
_MODEL_DISPLAY_NAMES = {
    "gemini": "Gemini 2.5 Flash",
    "qwen-vl": "Qwen3-VL",
    "chatgpt": "GPT-4o-mini",
    "claude": "Claude 3.5 Haiku",
}

# Free-tier fallback chain: Gemini Flash → Qwen-VL (last)
_FREE_CHAIN = ("gemini", "qwen-vl")

# Premium-tier fallback chain: Claude → GPT-4o-mini → Gemini Flash → Qwen-VL (last)
_PREMIUM_CHAIN = ("claude", "chatgpt", "gemini", "qwen-vl")


async def _call_chatgpt_vision(
    image_bytes: bytes, filename: str | None, mime_type: str | None, text_hint: str | None,
) -> VisionResult:
    """GPT-4o-mini vision analysis — OpenAI chat completions with image."""
    import base64
    import json
    import httpx
    from app.config import AIConfig
    from app.services.qwen_vision_service import (
        _VISION_SYSTEM_PROMPT,
        _mime_from_filename,
        _normalize_notes,
    )

    if not AIConfig.openai_configured():
        raise GeminiVisionError("OpenAI is not configured.")

    mime = mime_type or _mime_from_filename(filename)
    image_data = base64.b64encode(image_bytes).decode("ascii")
    data_url = f"data:{mime};base64,{image_data}"

    user_text = text_hint or (
        "Analyze this image. If it contains questions or problems, solve them step-by-step. "
        "If it contains notes or diagrams, explain the content with key points."
    )

    messages = [
        {"role": "system", "content": _VISION_SYSTEM_PROMPT},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": user_text},
                {"type": "image_url", "image_url": {"url": data_url}},
            ],
        },
    ]

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {AIConfig.OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": AIConfig.OPENAI_VISION_MODEL,
                    "messages": messages,
                    "temperature": 0.2,
                    "max_tokens": 4096,
                    "response_format": {"type": "json_object"},
                },
            )
    except Exception as exc:
        raise GeminiVisionError(f"OpenAI vision network error: {exc}") from exc

    if response.status_code != 200:
        raise GeminiVisionError(f"OpenAI vision failed: {response.status_code}")

    try:
        content = response.json()["choices"][0]["message"]["content"]
        parsed = json.loads(content)
        notes = _normalize_notes(parsed)
        return VisionResult(notes=notes, used_plus=False)
    except (KeyError, IndexError, json.JSONDecodeError, TypeError) as error:
        raise GeminiVisionError("OpenAI vision returned unparseable output.") from error


async def _call_claude_vision(
    image_bytes: bytes, filename: str | None, mime_type: str | None, text_hint: str | None,
) -> VisionResult:
    """Claude 3.5 Haiku vision analysis."""
    import base64
    import json
    import httpx
    from app.config import AIConfig
    from app.services.qwen_vision_service import (
        _VISION_SYSTEM_PROMPT,
        _mime_from_filename,
        _normalize_notes,
    )

    if not AIConfig.CLAUDE_API_KEY:
        raise GeminiVisionError("Claude is not configured.")

    mime = mime_type or _mime_from_filename(filename)
    image_data = base64.b64encode(image_bytes).decode("ascii")

    user_text = text_hint or (
        "Analyze this image. If it contains questions or problems, solve them step-by-step. "
        "If it contains notes or diagrams, explain the content with key points."
    )

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": user_text},
                {"type": "image", "source": {"type": "base64", "media_type": mime, "data": image_data}},
            ],
        },
    ]

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": AIConfig.CLAUDE_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": AIConfig.CLAUDE_CHAT_MODEL,
                    "system": _VISION_SYSTEM_PROMPT,
                    "messages": messages,
                    "max_tokens": 4096,
                    "temperature": 0.2,
                },
            )
    except Exception as exc:
        raise GeminiVisionError(f"Claude vision network error: {exc}") from exc

    if response.status_code != 200:
        raise GeminiVisionError(f"Claude vision failed: {response.status_code}")

    try:
        text_content = "".join(
            block.get("text", "")
            for block in response.json().get("content", [])
            if block.get("type") == "text"
        )
        parsed = json.loads(text_content)
        notes = _normalize_notes(parsed)
        return VisionResult(notes=notes, used_plus=False)
    except (KeyError, json.JSONDecodeError, TypeError) as error:
        raise GeminiVisionError("Claude vision returned unparseable output.") from error


async def analyze_image_with_fallback(
    image_bytes: bytes,
    *,
    filename: str | None,
    mime_type: str | None,
    text_hint: str | None,
    selected_model: str,
    user_id: str | None = None,
) -> VisionResult:
    """Route vision analysis through free or premium fallback chains.

    Free users:  gemini → qwen-vl (or qwen-vl → gemini)
    Premium (₹199): claude → chatgpt → gemini → qwen-vl
    """
    is_premium = selected_model in ("claude", "chatgpt")

    if is_premium and user_id:
        from app.services.plan_tier_service import (
            FeatureLockedError,
            GatedFeature,
            require_feature_unlocked,
        )
        try:
            require_feature_unlocked(user_id, GatedFeature.PREMIUM_VISION_MODEL)
        except FeatureLockedError:
            # Silently downgrade to free chain if plan check fails
            is_premium = False
            selected_model = "qwen-vl"

    if is_premium:
        chain = ("claude", "chatgpt", "qwen-vl", "gemini") if selected_model == "claude" else ("chatgpt", "claude", "qwen-vl", "gemini")
    else:
        chain = ("qwen-vl", "gemini") if selected_model == "qwen-vl" else ("gemini", "qwen-vl")

    async def call(model: str) -> VisionResult:
        if model == "gemini":
            return await analyze_gemini(image_bytes, filename, mime_type, text_hint)
        if model == "chatgpt":
            return await _call_chatgpt_vision(image_bytes, filename, mime_type, text_hint)
        if model == "claude":
            return await _call_claude_vision(image_bytes, filename, mime_type, text_hint)
        return await analyze_qwen(image_bytes, filename, mime_type, text_hint)

    last_error: Exception | None = None
    for model_key in chain:
        try:
            result = await call(model_key)
            result.model_name = _MODEL_DISPLAY_NAMES.get(model_key, model_key)
            logger.info(
                "home_ai_vision selected=%s served=%s premium=%s",
                selected_model, model_key, is_premium,
            )
            return result
        except Exception as error:
            last_error = error
            logger.warning(
                "home_ai_vision_failed model=%s error=%s",
                model_key, type(error).__name__,
            )

    raise last_error or GeminiVisionError("All vision models failed.")