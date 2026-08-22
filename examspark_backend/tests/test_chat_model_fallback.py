import asyncio

from app.services import english_practice_service as service


def test_selected_qwen_falls_back_to_gemini_with_same_messages(monkeypatch):
    messages = [{"role": "system", "content": "same prompt"}]
    calls = []

    async def qwen(received):
        calls.append(("qwen3", received))
        raise service.EnglishPracticeError("qwen unavailable", 502)

    async def gemini(received):
        calls.append(("gemini", received))
        return "Gemini reply"

    monkeypatch.setattr(service, "_call_model", qwen)
    monkeypatch.setattr(service, "_call_gemini_model", gemini)

    result = asyncio.run(service._call_chat_model(messages, "qwen3"))

    assert result == "Gemini reply"
    assert calls == [("qwen3", messages), ("gemini", messages)]


def test_selected_gemini_falls_back_to_qwen_once(monkeypatch):
    messages = [{"role": "user", "content": "hello"}]
    calls = []

    async def gemini(received):
        calls.append("gemini")
        raise service.EnglishPracticeError("gemini unavailable", 502)

    async def qwen(received):
        calls.append("qwen3")
        return "Qwen reply"

    monkeypatch.setattr(service, "_call_gemini_model", gemini)
    monkeypatch.setattr(service, "_call_model", qwen)

    result = asyncio.run(service._call_chat_model(messages, "gemini"))

    assert result == "Qwen reply"
    assert calls == ["gemini", "qwen3"]


def test_both_chat_models_fail_without_a_retry_loop(monkeypatch):
    messages = [{"role": "system", "content": "same prompt"}]
    calls = []

    async def qwen(received):
        calls.append("qwen3")
        raise service.EnglishPracticeError("qwen unavailable", 502)

    async def gemini(received):
        calls.append("gemini")
        raise service.EnglishPracticeError("gemini unavailable", 502)

    monkeypatch.setattr(service, "_call_model", qwen)
    monkeypatch.setattr(service, "_call_gemini_model", gemini)

    try:
        asyncio.run(service._call_chat_model(messages, "qwen3"))
    except service.EnglishPracticeError as error:
        assert str(error) == "qwen unavailable"
    else:
        raise AssertionError("Expected both-model failure")

    assert calls == ["qwen3", "gemini"]
