"""Offline Fish Audio adapter and provider-dispatch tests."""
import asyncio

from app.services import fish_tts_service as fish
from app.services import roleplay_tts_service as tts


class _SpeechResponse:
    def __init__(self, audio=b"mp3"):
        self.audio = audio

    def read(self):
        return self.audio


class _Speech:
    def __init__(self, captured):
        self.captured = captured

    def create(self, **kwargs):
        self.captured.update(kwargs)
        return _SpeechResponse()


class _Audio:
    def __init__(self, captured):
        self.speech = _Speech(captured)


class _Client:
    def __init__(self, captured, **kwargs):
        captured["client"] = kwargs
        self.audio = _Audio(captured)


def test_fish_request_uses_openai_compatible_endpoint_and_reference_voice(monkeypatch):
    captured = {}
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_API_KEY", "test-key")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_FEMALE_VOICE_ID", "female-ref")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_MALE_VOICE_ID", "male-ref")
    monkeypatch.setattr(fish, "OpenAI", lambda **kwargs: _Client(captured, **kwargs))

    result = asyncio.run(fish.synthesize_speech("Hello", voice="female-ref"))

    assert result == (b"mp3", "audio/mpeg")
    assert captured["client"] == {
        "base_url": "https://api.fish.audio/compat/v1",
        "api_key": "test-key",
    }
    assert captured["model"] == "fish-audio/s2.1-pro"
    assert captured["voice"] == "female-ref"
    assert captured["response_format"] == "mp3"


def test_fish_requires_key_and_both_voice_ids(monkeypatch):
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_API_KEY", "")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_FEMALE_VOICE_ID", "")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_MALE_VOICE_ID", "")

    try:
        asyncio.run(fish.synthesize_speech("Hello", voice="female-ref"))
    except fish.FishTtsError as error:
        assert "FISH_AUDIO_API_KEY" in str(error)
    else:  # pragma: no cover
        raise AssertionError("Fish configuration failure was not raised")


def test_placeholder_fish_voice_ids_are_not_configured(monkeypatch):
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_API_KEY", "test-key")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_FEMALE_VOICE_ID", "<female>")
    monkeypatch.setattr(fish.AIConfig, "FISH_AUDIO_MALE_VOICE_ID", "<male>")
    assert fish.AIConfig.fish_audio_configured() is False


def test_fish_provider_dispatches_selected_voice(monkeypatch):
    monkeypatch.setattr(
        tts,
        "get_voice_preference",
        lambda _user_id: {"provider": "fish", "voice_key": "male"},
    )
    called = {}

    async def fish_adapter(text, *, voice, user_id):
        called.update(text=text, voice=voice, user_id=user_id)
        return b"mp3", "audio/mpeg"

    monkeypatch.setattr(tts, "synthesize_fish", fish_adapter)
    monkeypatch.setattr(tts.AIConfig, "FISH_AUDIO_MALE_VOICE_ID", "male-ref")
    tts._VOICE_IDS["fish"]["male"] = "male-ref"

    assert asyncio.run(tts.synthesize_for_user("user-a", "Hello")) == (
        b"mp3",
        "audio/mpeg",
    )
    assert called["voice"] == "male-ref"


def test_fish_is_attempted_before_other_fallbacks(monkeypatch):
    monkeypatch.setattr(
        tts,
        "get_voice_preference",
        lambda _user_id: {"provider": "qwen", "voice_key": "female"},
    )
    monkeypatch.setattr(tts, "_provider_configured", lambda provider: provider in {"fish", "gemini"})
    calls = []

    async def qwen_adapter(*_args, **_kwargs):
        calls.append("qwen")
        raise tts.QwenTtsError("qwen failed")

    async def fish_adapter(*_args, **_kwargs):
        calls.append("fish")
        return b"mp3", "audio/mpeg"

    monkeypatch.setattr(tts, "synthesize_qwen", qwen_adapter)
    monkeypatch.setattr(tts, "synthesize_fish", fish_adapter)
    monkeypatch.setattr(tts, "synthesize_gemini", lambda *_args, **_kwargs: None)

    assert asyncio.run(tts.synthesize_for_user("user-a", "Hello")) == (
        b"mp3",
        "audio/mpeg",
    )
    assert calls == ["qwen", "fish"]
