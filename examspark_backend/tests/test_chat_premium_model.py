import asyncio

from app.services import english_practice_service as service


def test_claude_failure_does_not_downgrade_to_free_model(monkeypatch):
    calls = []

    async def claude(messages):
        calls.append("claude")
        raise service.EnglishPracticeError("claude unavailable", 502)

    async def qwen(messages):
        calls.append("qwen3")
        return "free fallback"

    monkeypatch.setattr(service, "_call_claude_model", claude)
    monkeypatch.setattr(service, "_call_model", qwen)

    try:
        asyncio.run(service._call_chat_model([], "claude"))
    except service.EnglishPracticeError as error:
        assert str(error) == "claude unavailable"
    else:
        raise AssertionError("Expected Claude failure")

    assert calls == ["claude"]