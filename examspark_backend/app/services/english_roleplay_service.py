"""Persisted Roleplay turns, including an additive streaming voice path."""
import asyncio
import re
from collections.abc import AsyncIterator
from datetime import datetime, timezone
from app.constants.english_roleplay_prompt import build_roleplay_prompt
from app.constants.credit_costs import (
    ROLEPLAY_CREDITS_PER_MINUTE,
    ROLEPLAY_MINIMUM_CREDITS,
    roleplay_credits_for_duration_seconds,
)
from app.services import english_practice_service as chat
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.supabase_admin import get_supabase_admin
from app.services.qwen_tts_service import QwenTtsError, synthesize_speech
from app.services.whisper_service import (
    WhisperTranscriptionError,
    transcribe_audio,
)
from app.services import english_learning_memory_service as learning_memory

_ABBREVIATIONS = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'vs', 'etc', 'e.g', 'i.e',
    'a.m', 'p.m', 'st', 'fig', 'no', 'approx', 'inc', 'ltd',
}
_NATURAL_PAUSE_MIN_CHARS = 180


def _is_sentence_boundary(text: str, index: int) -> bool:
    """Avoid decimal, abbreviation, and ellipsis false sentence splits."""
    char = text[index]
    if char in '!?…':
        return True
    if char != '.':
        return False
    # A three-dot ellipsis is considered only at the third dot.
    if index >= 2 and text[index - 2:index] == '..':
        return True
    if (index > 0 and text[index - 1] == '.') or (
        index + 1 < len(text) and text[index + 1] == '.'
    ):
        return False
    if index > 0 and index + 1 < len(text) and text[index - 1].isdigit() and text[index + 1].isdigit():
        return False
    prefix = text[:index]
    word = re.search(r'([A-Za-z](?:[A-Za-z.]*)?)$', prefix)
    return not word or word.group(1).lower() not in _ABBREVIATIONS


def split_complete_speech_chunks(buffer: str, *, final: bool = False) -> tuple[list[str], str]:
    """Return complete natural speech chunks plus the unfinished tail.

    A boundary must be followed by whitespace while streaming so a token ending
    with ``Dr.`` or ``...`` is not prematurely spoken as a finished sentence.
    Very long replies may also break at the last comma/semicolon natural pause.
    """
    chunks: list[str] = []
    start = 0
    for index, char in enumerate(buffer):
        next_is_space = index + 1 < len(buffer) and buffer[index + 1].isspace()
        if next_is_space and _is_sentence_boundary(buffer, index):
            piece = buffer[start:index + 1].strip()
            if piece:
                chunks.append(piece)
            start = index + 1
    tail = buffer[start:]
    if not chunks and len(tail) >= _NATURAL_PAUSE_MIN_CHARS:
        pauses = [match.end() for match in re.finditer(r'[,;:]\s+', tail)]
        if pauses:
            split_at = pauses[-1]
            chunks.append(tail[:split_at].strip())
            tail = tail[split_at:]
    if final and tail.strip():
        chunks.append(tail.strip())
        tail = ''
    return chunks, tail

def _now() -> str: return datetime.now(timezone.utc).isoformat()

def _server_duration_seconds(started_at: str) -> int:
    started = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
    if started.tzinfo is None:
        started = started.replace(tzinfo=timezone.utc)
    return max(0, int((datetime.now(timezone.utc) - started).total_seconds()))

def _precheck_minimum_balance(user_id: str) -> None:
    row = get_supabase_admin().table('users').select('credits_balance').eq('id', user_id).single().execute().data or {}
    balance = int(row.get('credits_balance') or 0)
    if balance < ROLEPLAY_MINIMUM_CREDITS:
        raise chat.EnglishPracticeError(
            f'At least {ROLEPLAY_MINIMUM_CREDITS} credits are required to start Roleplay. Current balance: {balance}.',
            402,
        )

def _session(session_id: str, user_id: str) -> dict | None:
    rows = get_supabase_admin().table('english_roleplay_sessions').select('*').eq('id', session_id).eq('user_id', user_id).limit(1).execute().data or []
    return rows[0] if rows else None

def start(user_id: str, scenario: str, native_language: str) -> dict:
    scenario = scenario.strip()
    if not scenario: raise chat.EnglishPracticeError('Choose a roleplay scenario.', 400)
    _precheck_minimum_balance(user_id)
    row = get_supabase_admin().table('english_roleplay_sessions').insert({'user_id': user_id, 'scenario': scenario, 'native_language': native_language, 'status': 'active'}).execute().data[0]
    return {'session_id': row['id'], 'scenario': scenario, 'started_at': row['started_at']}

async def send_turn(user_id: str, session_id: str, transcript: str) -> dict:
    session = _session(session_id, user_id)
    text = transcript.strip()
    if not session: raise chat.EnglishPracticeError('Roleplay session not found.', 404)
    if session['status'] != 'active': raise chat.EnglishPracticeError('This roleplay has ended.', 409)
    if not text: raise chat.EnglishPracticeError('No speech detected. Please try again.', 400)
    db = get_supabase_admin()
    db.table('english_roleplay_messages').insert({'session_id': session_id, 'user_id': user_id, 'role': 'user', 'message': text}).execute()
    rows = db.table('english_roleplay_messages').select('role,message').eq('session_id', session_id).order('created_at', desc=True).limit(8).execute().data or []
    memory_context = learning_memory.format_memory_context(learning_memory.load_memory(user_id), mode='roleplay')
    messages = [{'role': 'system', 'content': build_roleplay_prompt(scenario=session['scenario'], native_language=session['native_language'], learning_memory=memory_context)}]
    messages += [{'role': r['role'], 'content': r['message']} for r in reversed(rows)]
    reply = await chat._call_model(messages)
    assistant_insert = db.table('english_roleplay_messages').insert({'session_id': session_id, 'user_id': user_id, 'role': 'assistant', 'message': reply}).execute()
    assistant_id = ((assistant_insert.data or [{}])[0]).get('id')
    learning_memory.schedule_update(user_id=user_id, native_language=session['native_language'], mode='roleplay', user_text=text, assistant_text=reply, scenario=session['scenario'])
    db.table('english_roleplay_sessions').update({'updated_at': _now()}).eq('id', session_id).execute()
    return {'transcript': text, 'reply': reply, 'assistant_message_id': assistant_id}

async def send_audio_turn(
    user_id: str, session_id: str, audio_bytes: bytes, filename: str
) -> dict:
    """One manual audio turn: existing Whisper → existing Qwen → Qwen TTS."""
    if not audio_bytes:
        raise chat.EnglishPracticeError("Audio file is empty.", 400)
    try:
        transcription = await transcribe_audio(audio_bytes, filename)
    except WhisperTranscriptionError as e:
        raise chat.EnglishPracticeError(f"Could not understand the audio: {e}", 502) from e
    # A roleplay turn can legitimately be one short beginner phrase.
    if not transcription.text.strip():
        raise chat.EnglishPracticeError("No speech detected. Please try again.", 400)
    result = await send_turn(user_id, session_id, transcription.text)
    try:
        audio, mime_type = await synthesize_speech(result["reply"])
    except QwenTtsError as e:
        # A reply without playable audio is not a successful voice turn.
        assistant_id = result.get('assistant_message_id')
        if assistant_id:
            get_supabase_admin().table('english_roleplay_messages').delete().eq('id', assistant_id).eq('session_id', session_id).eq('user_id', user_id).execute()
        raise chat.EnglishPracticeError(str(e), 502) from e
    return {**result, "audio_bytes": audio, "audio_mime_type": mime_type}


def _stream_messages(session: dict, user_id: str, transcript: str) -> list[dict]:
    """Build the normal Roleplay context without persisting an in-flight turn."""
    db = get_supabase_admin()
    rows = (
        db.table('english_roleplay_messages').select('role,message')
        .eq('session_id', session['id']).eq('user_id', user_id)
        .order('created_at', desc=True).limit(8).execute().data or []
    )
    memory_context = learning_memory.format_memory_context(
        learning_memory.load_memory(user_id), mode='roleplay'
    )
    messages = [{'role': 'system', 'content': build_roleplay_prompt(
        scenario=session['scenario'], native_language=session['native_language'],
        learning_memory=memory_context,
    )}]
    messages += [{'role': row['role'], 'content': row['message']} for row in reversed(rows)]
    messages.append({'role': 'user', 'content': transcript})
    return messages


async def stream_audio_turn(
    user_id: str, session_id: str, audio_bytes: bytes, filename: str,
) -> AsyncIterator[dict]:
    """Stream transcript then ordered per-sentence TTS chunks over SSE.

    No user/assistant messages are persisted until every chunk is produced,
    allowing a pre-audio Flutter fallback to reuse the existing JSON endpoint.
    """
    if not audio_bytes:
        raise chat.EnglishPracticeError('Audio file is empty.', 400)
    session = _session(session_id, user_id)
    if not session:
        raise chat.EnglishPracticeError('Roleplay session not found.', 404)
    if session['status'] != 'active':
        raise chat.EnglishPracticeError('This roleplay has ended.', 409)
    try:
        transcription = await transcribe_audio(audio_bytes, filename)
    except WhisperTranscriptionError as error:
        raise chat.EnglishPracticeError(f'Could not understand the audio: {error}', 502) from error
    transcript = transcription.text.strip()
    # A roleplay turn can legitimately be one short beginner phrase.
    if not transcript:
        raise chat.EnglishPracticeError('No speech detected. Please try again.', 400)

    yield {'type': 'transcript', 'transcript': transcript}
    reply_parts: list[str] = []
    pending: list[asyncio.Task[tuple[bytes, str]]] = []
    sequence = 0
    buffer = ''
    try:
        async for delta in chat._stream_model(_stream_messages(session, user_id, transcript)):
            reply_parts.append(delta)
            buffer += delta
            chunks, buffer = split_complete_speech_chunks(buffer)
            for chunk in chunks:
                pending.append(asyncio.create_task(synthesize_speech(chunk)))
            while sequence < len(pending) and pending[sequence].done():
                audio, mime_type = await pending[sequence]
                yield {
                    'type': 'audio_chunk',
                    'sequence': sequence,
                    'audio_bytes': audio,
                    'audio_mime_type': mime_type,
                }
                sequence += 1
        chunks, _ = split_complete_speech_chunks(buffer, final=True)
        for chunk in chunks:
            pending.append(asyncio.create_task(synthesize_speech(chunk)))
        while sequence < len(pending):
            audio, mime_type = await pending[sequence]
            yield {
                'type': 'audio_chunk',
                'sequence': sequence,
                'audio_bytes': audio,
                'audio_mime_type': mime_type,
            }
            sequence += 1
    except QwenTtsError as error:
        raise chat.EnglishPracticeError(str(error), 502) from error
    finally:
        for task in pending[sequence:]:
            if not task.done():
                task.cancel()

    reply = ''.join(reply_parts).strip()
    if not reply or not pending:
        raise chat.EnglishPracticeError('Model returned an empty response.', 502)
    db = get_supabase_admin()
    db.table('english_roleplay_messages').insert([
        {'session_id': session_id, 'user_id': user_id, 'role': 'user', 'message': transcript},
        {'session_id': session_id, 'user_id': user_id, 'role': 'assistant', 'message': reply},
    ]).execute()
    learning_memory.schedule_update(
        user_id=user_id, native_language=session['native_language'], mode='roleplay',
        user_text=transcript, assistant_text=reply, scenario=session['scenario'],
    )
    db.table('english_roleplay_sessions').update({'updated_at': _now()}).eq('id', session_id).execute()
    yield {'type': 'done', 'transcript': transcript, 'reply': reply, 'sequence_count': sequence}

def end(user_id: str, session_id: str, duration_seconds: int | None = None) -> dict:
    session = _session(session_id, user_id)
    if not session: raise chat.EnglishPracticeError('Roleplay session not found.', 404)
    if session.get('status') == 'ended':
        return {'session_id': session_id, 'duration_seconds': int(session.get('duration_seconds') or 0), 'credits_used': int(session.get('credits_used') or 0)}
    seconds = _server_duration_seconds(session['started_at'])
    db = get_supabase_admin()
    assistant_rows = db.table('english_roleplay_messages').select('id').eq('session_id', session_id).eq('role', 'assistant').limit(1).execute().data or []
    credits_used = 0
    new_balance = None
    if assistant_rows:
        credits_used = roleplay_credits_for_duration_seconds(seconds)
        try:
            new_balance = deduct_credits(
                user_id=user_id,
                amount=credits_used,
                description=f'English Roleplay ({(seconds + 59) // 60} min)',
                action='english_roleplay',
            )
        except InsufficientCreditsError as e:
            raise chat.EnglishPracticeError(str(e), 402) from e
    db.table('english_roleplay_sessions').update({'status': 'ended', 'ended_at': _now(), 'duration_seconds': seconds, 'credits_used': credits_used, 'updated_at': _now()}).eq('id', session_id).execute()
    return {'session_id': session_id, 'duration_seconds': seconds, 'credits_used': credits_used, 'new_balance': new_balance}


def list_sessions(user_id: str, limit: int = 30, offset: int = 0) -> list[dict]:
    """Return compact, owner-scoped roleplay history for the Flutter list."""
    db = get_supabase_admin()
    rows = (
        db.table('english_roleplay_sessions')
        .select('id,scenario,native_language,status,started_at,ended_at,duration_seconds,credits_used,created_at,updated_at')
        .eq('user_id', user_id)
        .order('updated_at', desc=True)
        .range(offset, offset + limit - 1)
        .execute()
        .data
        or []
    )
    sessions = list(rows)
    for session in sessions:
        preview_rows = (
            db.table('english_roleplay_messages')
            .select('message')
            .eq('session_id', session['id'])
            .eq('user_id', user_id)
            .eq('role', 'user')
            .order('created_at', desc=False)
            .limit(1)
            .execute()
            .data
            or []
        )
        session['preview'] = (preview_rows[0].get('message') if preview_rows else '') or ''
    return sessions


def restore_session(session_id: str, user_id: str) -> dict | None:
    """Load a roleplay transcript only after verifying its authenticated owner."""
    session = _session(session_id, user_id)
    if not session:
        return None
    messages = (
        get_supabase_admin().table('english_roleplay_messages')
        .select('id,role,message,created_at')
        .eq('session_id', session_id)
        .eq('user_id', user_id)
        .order('created_at', desc=False)
        .execute()
        .data
        or []
    )
    return {
        'id': session['id'],
        'scenario': session['scenario'],
        'native_language': session.get('native_language'),
        'status': session.get('status'),
        'started_at': session.get('started_at'),
        'ended_at': session.get('ended_at'),
        'duration_seconds': session.get('duration_seconds'),
        'messages': list(messages),
    }
