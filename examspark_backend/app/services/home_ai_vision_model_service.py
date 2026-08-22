from __future__ import annotations

import logging

from app.services.gemini_vision_service import GeminiVisionError, analyze_image as analyze_gemini
from app.services.qwen_vision_service import QwenVisionError, VisionResult, analyze_image as analyze_qwen

logger = logging.getLogger(__name__)


async def analyze_image_with_fallback(
    image_bytes: bytes,
    *,
    filename: str | None,
    mime_type: str | None,
    text_hint: str | None,
    selected_model: str,
) -> VisionResult:
    selected = selected_model if selected_model in {"qwen-vl", "gemini"} else "qwen-vl"
    fallback = "gemini" if selected == "qwen-vl" else "qwen-vl"

    async def call(model: str) -> VisionResult:
        if model == "gemini":
            return await analyze_gemini(image_bytes, filename, mime_type, text_hint)
        return await analyze_qwen(image_bytes, filename, mime_type, text_hint)

    try:
        result = await call(selected)
        logger.info("home_ai_vision_model_selected=%s served=%s", selected, selected)
        return result
    except (QwenVisionError, GeminiVisionError) as primary_error:
        logger.warning(
            "home_ai_vision_model_failed selected=%s fallback=%s error=%s",
            selected,
            fallback,
            type(primary_error).__name__,
        )
        try:
            result = await call(fallback)
            logger.info("home_ai_vision_model_selected=%s served=%s", selected, fallback)
            return result
        except (QwenVisionError, GeminiVisionError) as fallback_error:
            logger.exception(
                "home_ai_vision_models_failed selected=%s fallback=%s",
                selected,
                fallback,
            )
            raise primary_error from fallback_error