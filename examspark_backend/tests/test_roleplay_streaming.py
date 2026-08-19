"""Offline unit tests for the additive Roleplay voice SSE pipeline."""
import asyncio
from types import SimpleNamespace

import pytest

from app.services import english_practice_service as chat
from app.services import english_roleplay_service as roleplay
from app.services.qwen_tts_service import QwenTtsError
from app.routers import english_roleplay as roleplay_router


def test_sentence_chunker_handles_abbreviations_decimals_and_ellipsis():
    split = roleplay.split_complete_speech_chunks
    assert split('Dr. Smith is here. Next? ')[0] == ['Dr. Smith is here.', 'Next?']
    assert split('The value is 3.14. Great! ')[0] == ['The value is 3.14.', 'Great!']
    assert split('Wait... ')[0] == ['Wait...']
    assert split('One sentence.', final=True)[0] == ['One sentence.']


def test_stream_model_reuses_existing_openrouter_stream_helper(monkeypatch):
    captured = {}

    async def fake_stream(messages, **kwargs):
        captured['messages'] = messages
        captured['kwargs'] = kwargs
        yield 'Hello'
        yield ' world'

    monkeypatch.setattr(chat, 'stream_chat_completions', fake_stream)

    async def collect():
        return [part async for part in chat._stream_model([{'role': 'user', 'content': 'Hi'}])]

    assert asyncio.run(collect()) == ['Hello', ' world']
    assert captured['kwargs']['temperature'] == 0.5
    assert captured['kwargs']['max_tokens'] == 400


class _Db:
    def __init__(self):
        self.inserts = []
        self.updated = []

    def table(self, _name):
        return self

    def insert(self, value):
        self.inserts.append(value)
        return self

    def update(self, value):
        self.updated.append(value)
        return self

    def eq(self, *_args):
        return self

    def execute(self):
        return SimpleNamespace(data=[])


async def _collect(generator):
    return [event async for event in generator]


def _install_success_mocks(monkeypatch, *, tts):
    db = _Db()
    monkeypatch.setattr(roleplay, '_session', lambda *_: {
        'id': 'session', 'status': 'active', 'scenario': 'Restaurant',
        'native_language': 'Hindi',
    })
    async def transcribe(*_args):
        return SimpleNamespace(text='I need a table.', likely_no_speech=False)
    monkeypatch.setattr(roleplay, 'transcribe_audio', transcribe)
    monkeypatch.setattr(roleplay, '_stream_messages', lambda *_: [])
    monkeypatch.setattr(roleplay, 'synthesize_speech', tts)
    monkeypatch.setattr(roleplay, 'get_supabase_admin', lambda: db)
    monkeypatch.setattr(roleplay.learning_memory, 'schedule_update', lambda **_: None)
    return db


def test_stream_audio_emits_ordered_audio_and_persists_only_on_success(monkeypatch):
    async def model(_messages):
        for token in ['First sentence. ', 'Second sentence.']:
            yield token

    async def tts(text):
        # Sentence two finishes first, but may not overtake sentence one.
        await asyncio.sleep(0.01 if text.startswith('First') else 0)
        return text.encode(), 'audio/mpeg'

    db = _install_success_mocks(monkeypatch, tts=tts)
    monkeypatch.setattr(chat, '_stream_model', model)
    events = asyncio.run(_collect(roleplay.stream_audio_turn('user', 'session', b'audio', 'turn.m4a')))
    assert [event['type'] for event in events] == ['transcript', 'audio_chunk', 'audio_chunk', 'done']
    assert [event['sequence'] for event in events if event['type'] == 'audio_chunk'] == [0, 1]
    assert len(db.inserts) == 1 and len(db.inserts[0]) == 2


def test_stream_failure_before_audio_does_not_persist(monkeypatch):
    async def model(_messages):
        raise chat.EnglishPracticeError('Qwen stream failed.', 502)
        yield ''  # pragma: no cover - keeps this an async generator

    async def tts(_text):
        return b'audio', 'audio/mpeg'

    db = _install_success_mocks(monkeypatch, tts=tts)
    monkeypatch.setattr(chat, '_stream_model', model)
    with pytest.raises(chat.EnglishPracticeError):
        asyncio.run(_collect(roleplay.stream_audio_turn('user', 'session', b'audio', 'turn.m4a')))
    assert db.inserts == []


def test_stream_failure_after_first_audio_does_not_persist(monkeypatch):
    async def model(_messages):
        yield 'First sentence. Second sentence.'

    async def tts(text):
        if text.startswith('Second'):
            raise QwenTtsError('TTS failed')
        return b'first', 'audio/mpeg'

    db = _install_success_mocks(monkeypatch, tts=tts)
    monkeypatch.setattr(chat, '_stream_model', model)
    stream = roleplay.stream_audio_turn('user', 'session', b'audio', 'turn.m4a')

    async def consume_until_error():
        events = []
        with pytest.raises(chat.EnglishPracticeError):
            async for event in stream:
                events.append(event)
        return events

    events = asyncio.run(consume_until_error())
    assert [event['type'] for event in events] == ['transcript', 'audio_chunk']
    assert db.inserts == []


def test_empty_transcript_does_not_create_a_turn(monkeypatch):
    db = _Db()
    monkeypatch.setattr(roleplay, '_session', lambda *_: {'status': 'active'})
    async def transcribe(*_args):
        return SimpleNamespace(text='', likely_no_speech=True)
    monkeypatch.setattr(roleplay, 'transcribe_audio', transcribe)
    monkeypatch.setattr(roleplay, 'get_supabase_admin', lambda: db)
    with pytest.raises(chat.EnglishPracticeError, match='No speech detected'):
        asyncio.run(_collect(roleplay.stream_audio_turn('user', 'session', b'audio', 'turn.m4a')))
    assert db.inserts == []


def test_sse_error_marks_fallback_only_before_first_audio(monkeypatch):
    async def stream(*_args):
        yield {'type': 'transcript', 'transcript': 'Hello'}
        raise chat.EnglishPracticeError('provider failed', 502)
        yield {}  # pragma: no cover

    monkeypatch.setattr(roleplay_router.service, 'stream_audio_turn', stream)
    events = asyncio.run(_collect(roleplay_router._roleplay_sse_events('u', 's', b'a', 'a.m4a')))
    assert 'event: transcript' in events[0]
    assert '"can_fallback": true' in events[1]
