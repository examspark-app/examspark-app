import asyncio

from app.services import home_ai_vision_model_service as service
from app.services.qwen_vision_service import VisionResult, _VISION_SYSTEM_PROMPT


def test_gemini_vision_uses_same_task_prompt(monkeypatch):
    captured = {}

    async def fake_gemini(image, filename, mime, hint):
        captured["prompt"] = _VISION_SYSTEM_PROMPT
        captured["hint"] = hint
        return VisionResult({"cleanNotes": "Solved worksheet."}, False)

    monkeypatch.setattr(service, "analyze_gemini", fake_gemini)
    result = asyncio.run(
        service.analyze_image_with_fallback(
            b"image", filename="worksheet.png", mime_type="image/png",
            text_hint="Solve the worksheet.", selected_model="gemini",
        )
    )

    assert result.notes["cleanNotes"] == "Solved worksheet."
    assert captured["prompt"] == _VISION_SYSTEM_PROMPT
    assert "Solve the worksheet." in captured["hint"]
    assert "Treat every worksheet" in _VISION_SYSTEM_PROMPT
    assert "direct answers/solutions" in _VISION_SYSTEM_PROMPT


def test_selected_gemini_falls_back_to_qwen_once(monkeypatch):
    calls = []

    async def failed_gemini(*args):
        calls.append("gemini")
        from app.services.gemini_vision_service import GeminiVisionError
        raise GeminiVisionError("temporary failure")

    async def qwen(*args, **kwargs):
        calls.append("qwen-vl")
        return VisionResult({"cleanNotes": "Solved."}, False)

    monkeypatch.setattr(service, "analyze_gemini", failed_gemini)
    monkeypatch.setattr(service, "analyze_qwen", qwen)
    result = asyncio.run(
        service.analyze_image_with_fallback(
            b"image", filename="worksheet.png", mime_type="image/png",
            text_hint=None, selected_model="gemini",
        )
    )

    assert result.notes["cleanNotes"] == "Solved."
    assert calls == ["gemini", "qwen-vl"]
