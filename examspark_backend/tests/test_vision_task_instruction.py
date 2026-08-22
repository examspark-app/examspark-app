from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.qwen_vision_service import _call_vision_model


@pytest.mark.asyncio
async def test_default_vision_instruction_solves_worksheets_instead_of_describing():
    response = MagicMock(status_code=200)
    response.json.return_value = {
        "choices": [{"message": {"content": '{"cleanNotes":"Solved answers."}'}}]
    }
    client = AsyncMock()
    client.post = AsyncMock(return_value=response)

    with patch(
        "app.services.qwen_vision_service.AIConfig.openrouter_configured",
        return_value=True,
    ), patch(
        "app.services.qwen_vision_service.AIConfig.OPENROUTER_API_KEY",
        "test-key",
    ):
        await _call_vision_model(
            client,
            "flash-model",
            b"worksheet-bytes",
            "image/png",
            None,
        )

    payload = client.post.await_args.kwargs["json"]
    system = payload["messages"][0]["content"]
    user = payload["messages"][1]["content"][0]["text"]

    combined = f"{system}\n{user}"
    assert "possible learner task, not as an object to describe" in user
    assert "empty boxes/blanks" in user
    assert "list the answer for each blank in order" in user
    assert "complete sentence" not in combined.lower() or "complete that task" in combined.lower()
