"""Offline tests for provider choice without real provider credentials."""
import asyncio
import base64

from app.services import roleplay_tts_service as tts
from app.services import qwen_tts_service as qwen
from app.services import gemini_tts_service as gemini


class _Response:
    def __init__(self, *, content=b'', headers=None, body=None):
        self.status_code = 200
        self.content = content
        self.headers = headers or {}
        self._body = body or {}
        self.text = ''

    def json(self):
        return self._body


class _Client:
    def __init__(self, response, captured, **_kwargs):
        self._response = response
        self._captured = captured

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        return False

    async def post(self, url, **kwargs):
        self._captured.update(url=url, **kwargs)
        return self._response


class _PreferenceDb:
    def __init__(self):
        self.rows = {}
        self._id = None
        self._update = None
        self._select = False

    def table(self, _name):
        return self

    def select(self, _columns):
        self._select = True
        return self

    def update(self, values):
        self._update = values
        return self

    def eq(self, _column, value):
        self._id = value
        return self

    def limit(self, _value):
        return self

    def execute(self):
        if self._update is not None:
            self.rows[self._id] = dict(self._update)
            self._update = None
            return type('Result', (), {'data': []})()
        row = self.rows.get(self._id)
        return type('Result', (), {'data': [row] if row else []})()


def test_voice_ids_are_backend_only_and_provider_specific():
    assert tts.VOICE_OPTIONS['qwen'][0] == {'key': 'female', 'label': 'Female'}
    assert tts.VOICE_OPTIONS['gemini'][0] == {'key': 'warm', 'label': 'Warm'}
    assert tts._VOICE_IDS['qwen']['female'] == 'loongeva_v3.6'
    assert tts._VOICE_IDS['qwen']['male'] == 'loongjohn'
    assert tts._VOICE_IDS['gemini'] == {
        'warm': 'Sulafat', 'friendly': 'Achird', 'upbeat': 'Puck'
    }


def test_selected_provider_calls_only_its_adapter(monkeypatch):
    monkeypatch.setattr(
        tts, 'get_voice_preference',
        lambda _user_id: {'provider': 'gemini', 'voice_key': 'warm'},
    )
    called = {}

    async def gemini(text, *, voice):
        called.update(text=text, voice=voice)
        return b'wav', 'audio/wav'

    async def qwen(*_args, **_kwargs):
        raise AssertionError('Qwen must not be called for Gemini selection')

    monkeypatch.setattr(tts, 'synthesize_gemini', gemini)
    monkeypatch.setattr(tts, 'synthesize_qwen', qwen)
    assert asyncio.run(tts.synthesize_for_user('user-a', 'Hello')) == (b'wav', 'audio/wav')
    assert called == {'text': 'Hello', 'voice': 'Sulafat'}


def test_preferences_are_persisted_per_authenticated_user_without_exposing_voice_id(monkeypatch):
    db = _PreferenceDb()
    monkeypatch.setattr(tts, 'get_supabase_admin', lambda: db)
    saved = tts.set_voice_preference('user-a', 'gemini', 'friendly')
    tts.set_voice_preference('user-b', 'qwen', 'male')
    assert saved['provider'] == 'gemini'
    assert saved['voice_key'] == 'friendly'
    assert 'voice_id' not in saved
    assert tts.get_voice_preference('user-b')['voice_key'] == 'male'
    assert db.rows['user-a']['roleplay_tts_voice_id'] == 'Achird'


def test_qwen_request_uses_selected_backend_voice_and_returns_provider_mime(monkeypatch):
    captured = {}
    monkeypatch.setattr(qwen.AIConfig, 'OPENROUTER_API_KEY', 'test-key')
    monkeypatch.setattr(qwen.httpx, 'AsyncClient', lambda **kwargs: _Client(
        _Response(content=b'mp3', headers={'content-type': 'audio/mpeg; charset=binary'}),
        captured,
        **kwargs,
    ))
    assert asyncio.run(qwen.synthesize_speech('Hi', voice='loongjohn')) == (b'mp3', 'audio/mpeg')
    assert captured['url'] == 'https://openrouter.ai/api/v1/audio/speech'
    assert captured['json']['model'] == 'qwen/qwen-audio-3.0-tts-flash'
    assert captured['json']['voice'] == 'loongjohn'


def test_gemini_request_uses_selected_voice_and_wraps_pcm_as_wav(monkeypatch):
    captured = {}
    pcm = b'\x00\x00\x01\x00'
    response = _Response(body={'candidates': [{'content': {'parts': [
        {'inlineData': {'mimeType': 'audio/L16;codec=pcm;rate=24000', 'data': base64.b64encode(pcm).decode()}},
    ]}}]})
    monkeypatch.setattr(gemini.AIConfig, 'GEMINI_API_KEY', 'test-key')
    monkeypatch.setattr(gemini.httpx, 'AsyncClient', lambda **kwargs: _Client(response, captured, **kwargs))
    audio, mime = asyncio.run(gemini.synthesize_speech('Namaste', voice='Sulafat'))
    assert mime == 'audio/wav' and audio.startswith(b'RIFF')
    assert captured['url'].endswith('gemini-2.5-flash-preview-tts:generateContent')
    assert captured['json']['generationConfig']['speechConfig']['voiceConfig']['prebuiltVoiceConfig']['voiceName'] == 'Sulafat'
