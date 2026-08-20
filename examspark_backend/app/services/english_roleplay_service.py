"""Persisted Roleplay turns, including an additive streaming voice path."""
import asyncio
import logging
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
from app.services.roleplay_tts_service import RoleplayTtsError, synthesize_for_user
from app.services.whisper_service import (
    WhisperTranscriptionError,
    transcribe_audio,
)
from app.services import english_learning_memory_service as learning_memory

logger = logging.getLogger(__name__)

_ABBREVIATIONS = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'vs', 'etc', 'e.g', 'i.e',
    'a.m', 'p.m', 'st', 'fig', 'no', 'approx', 'inc', 'ltd',
}
_NATURAL_PAUSE_MIN_CHARS = 180
_GENERIC_OPENING_BLACKLIST = {
    'hello, how can i help',
    'how can i help you today',
    'how may i assist you',
    'how may i help',
    'welcome to this roleplay',
    'today we will practice',
    'this is a roleplay',
    "let's begin the lesson",
    "let's begin the practice",
    'let us start the lesson',
    'welcome to the lesson',
    'welcome to our practice',
    'welcome to our session',
    'how can i help you today',
    'what would you like to practice today',
}
_SCENARIO_FALLBACK_OPENING = {
    'restaurant': (
        'Good evening! Table for two this evening, or did you already book ahead? '
        'I can grab you a menu as soon as you are seated.'
    ),
    'friends': (
        'Hey! I got here two minutes ago — did you find the place okay? '
        'I already ordered us two coffees while I waited.'
    ),
    'interview': (
        'Thanks so much for coming in today. Could you start by telling me a little about yourself?'
    ),
    'market': (
        'Hi there! Looking for something fresh today, or just browsing? These tomatoes just came in this morning.'
    ),
    'party': (
        'Hey! So glad you made it. Come on in — have you met anyone else here yet?'
    ),
    'travel': (
        'This flight seems delayed, huh? Where are you heading to today?'
    ),
}


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


def _opening_looks_generic(text: str) -> bool:
    lower = (text or '').lower().strip()
    if not lower:
        return True
    return any(phrase in lower for phrase in _GENERIC_OPENING_BLACKLIST)


def _fallback_opening(scenario: str) -> str:
    key = (scenario or '').lower()
    for k, v in _SCENARIO_FALLBACK_OPENING.items():
        if k in key:
            return v
    return (
        'Hey! So glad you could make it today. '
        'Have you done this kind of practice before, or is this your first time roleplaying?'
    )


async def start(
    user_id: str,
    scenario: str,
    native_language: str,
    target_language: str = 'English'
) -> dict:
    """Create a session and let the in-character partner make the first move."""

    scenario = scenario.strip()

    if not scenario:
        raise chat.EnglishPracticeError(
            'Choose a roleplay scenario.',
            400
        )

    _precheck_minimum_balance(user_id)

    db = get_supabase_admin()

    row = (
        db.table('english_roleplay_sessions')
        .insert({
            'user_id': user_id,
            'scenario': scenario,
            'native_language': native_language,
            'target_language': target_language,
            'status': 'active'
        })
        .execute()
        .data[0]
    )

    sid = row['id']

    memory_dict = learning_memory.load_memory(user_id)

    memory_context = learning_memory.format_memory_context(
        memory_dict,
        mode='roleplay'
    )

    # Load a small set of previous openings from this user's
    # previous sessions for the same scenario.
    # These are used only to prevent repetitive openings/events.
    recent_sessions = (
        db.table('english_roleplay_sessions')
        .select('id,created_at')
        .eq('user_id', user_id)
        .eq('scenario', scenario)
        .neq('id', sid)
        .order('created_at', desc=True)
        .limit(8)
        .execute()
        .data
        or []
    )

    recent_openings: list[str] = []

    for previous_session in recent_sessions:
        opening_rows = (
            db.table('english_roleplay_messages')
            .select('message')
            .eq('session_id', previous_session['id'])
            .eq('user_id', user_id)
            .eq('role', 'assistant')
            .order('created_at', desc=False)
            .limit(1)
            .execute()
            .data
            or []
        )

        if opening_rows:
            opening_text = (
                opening_rows[0].get('message') or ''
            ).strip()

            if opening_text:
                recent_openings.append(opening_text)

    recent_opening_context = '\n'.join(
        f'- {opening}'
        for opening in recent_openings
    )

    freshness_context = (
        '\nRECENT OPENINGS TO AVOID:\n'
        f'{recent_opening_context or "- None"}\n'
        '\nFRESH SESSION RULE:\n'
        'These are previous openings from this learner. '
        'Do not copy their wording, greeting pattern, event, object, '
        'or small environment detail. '
        'Create a materially fresh situation for this session. '
        'Learning memory is for understanding the learner, not for '
        'replaying old conversation.\n'
    )

    sys_prompt = build_roleplay_prompt(
        scenario=scenario,
        native_language=native_language,
        target_language=target_language,
        learning_memory=memory_context + freshness_context,
    )

    memory_has_name = bool(
        memory_dict.get('preferred_name')
        or memory_dict.get('learner_name')
    )

    if memory_has_name:
        name_note = (
            ' You already know the learner\'s name from the memory block — '
            'use it NATURALLY and OCCASIONALLY only if it fits the scenario '
            '(e.g., a waiter greeting a returning guest, a friend calling '
            'them by name). '
            'Do NOT stuff it into every line.'
        )
    else:
        name_note = (
            ' You do NOT know the learner\'s name yet. ONLY IF this scenario '
            'naturally supports asking someone their name '
            '(e.g. a new friend introducing themselves, a host greeting '
            'someone at a party, an interviewer asking their pre-interview '
            'admin, a waiter asking for a booking name), THEN casually ask '
            'for it IN-character ONCE, early in the conversation '
            '(the first OR second line OR your first reply to their response). '
            'Do NOT force it into scenarios where it would be weird '
            '(strangers bargaining in a market, random passerby small talk '
            'at an airport gate). '
            'Ask in the target language if staying in character, or briefly '
            'step out briefly in the native language for one line then back in. '
            'If you do ask, only ask once. If the learner skips, drop it forever.'
        )

    opening_instruction = (
        '(system: THIS IS NON-NEGOTIABLE — YOU are sending the very first '
        'line of this roleplay session. The user has not yet spoken or typed '
        'anything; there must NOT be a blank screen. Open this roleplay NOW '
        'in character, in the target language, with exactly ONE short warm '
        'scenario-specific greeting (1-2 short sentences MAX, never 4+), '
        'including ONE invented tiny specific environment detail fresh for '
        'this run (never reuse the same detail twice), followed by ONE easy '
        'follow-up question folded naturally out of that reaction. '
        'Then STOP and WAIT. No second message, no teaching preamble, '
        'no meta-commentary, NO mentioning "the roleplay / scenario / '
        'practice / lesson" anywhere. NO generic lines like '
        '"Hello, how can I help you?", "welcome to this roleplay", '
        '"let\'s practice", or any line that could be pasted into any '
        'random scenario. Act like a real person actually inside this exact '
        'environment — a stranger reading your line should instantly GUESS '
        'which scenario it\'s from without being told. '
        'FRIEND-ENERGY CALIBRATION — do NOT open with a flat greeting + empty '
        'question. Instead: invent ONE specific tiny scenario detail '
        '(fresh every time, never repeat the same detail twice) and react '
        'to it first, share a mini opinion/tease/observation, THEN fold '
        'your follow-up question naturally out of that reaction. '
        'BAD example (do NOT do): "Hi! Welcome to the party. How are you?" '
        'GOOD example (the FEEL to copy, not the words): '
        '"Heyyy you made it! I was starting to think you\'d bail on me lol — '
        'okay but this playlist though, you\'re gonna love it." '
        'LENGTH/PACING: one reaction-beat + one question. '
        'Never stack multiple topics in one opening line. '
        'Keep it 1-2 sentences only. '
        'Vary the invented detail every single session so no two openings '
        'feel templated.'
        + name_note
        + ')'
    )

    opening_raw = await chat._call_model([
        {
            'role': 'system',
            'content': sys_prompt
        },
        {
            'role': 'user',
            'content': opening_instruction
        },
    ])

    opening_clean, opening_suggestions, opening_mcq = (
        chat._split_and_extract(opening_raw)
    )

    opening = opening_clean.strip()

    if not opening:
        opening = _fallback_opening(scenario)

    elif _opening_looks_generic(opening):

        retry_instruction = (
            '(system: Re-write the opening. The previous attempt was too '
            'generic / sounded like a help-bot / teacher starting class / '
            'or too long. Make it sound like a real PERSON actually INSIDE '
            'this exact environment. Scenario: '
            + scenario
            + '. 1-2 SHORT sentences MAX (never 4+). ONE reaction-beat '
            '(fresh invented scenario detail, DIFFERENT from the previous '
            'attempt) + ONE easy follow-up question folded naturally out '
            'of it. Target language only. '
            'CRITICAL (1) ENV-GUESS TEST: a stranger reading only this line '
            'must instantly guess the scenario from the content + energy '
            'alone — never say "welcome to this roleplay" or explain the '
            'scene; use specific vocabulary that belongs only in this '
            'scenario. '
            'CRITICAL (2) FRESH INVENTED DETAIL for this retry: pick a '
            'DIFFERENT tiny detail from the previous attempt '
            '(a different restaurant special, a different party song, '
            'a different airport delay cause, a different market vegetable, '
            'etc.). React to that new detail first, share a mini '
            'in-character opinion / tease / observation, THEN fold the '
            'follow-up question out of that reaction. '
            'CRITICAL (3) LENGTH/PACING: one single beat, no stacking — '
            '1-2 sentences only. '
            'BAD (flat): "Hi! Welcome. How are you feeling today?" '
            'GOOD (alive, feel-only reference, do NOT copy words): '
            '"Heyyy you made it! I was starting to think you\'d bail on me '
            'lol — okay but this playlist though, you\'re gonna love it." '
            'Make the invented detail specific and tied to this exact '
            'scenario — a new restaurant menu item, a song at the party, '
            'a vendor\'s just-arrived produce, whatever fits.'
            + name_note
            + ')'
        )

        try:
            second_raw = await chat._call_model([
                {
                    'role': 'system',
                    'content': sys_prompt
                },
                {
                    'role': 'user',
                    'content': retry_instruction
                },
            ])

            second_clean, _, _ = chat._split_and_extract(second_raw)

            second = second_clean.strip()

            if second and not _opening_looks_generic(second):
                opening = second
            else:
                opening = _fallback_opening(scenario)

        except Exception as exc:  # pragma: no cover - network layer
            logger.warning(
                'roleplay_opening_regen_failed user=%s error=%s',
                user_id,
                type(exc).__name__
            )
            opening = _fallback_opening(scenario)

    try:
        audio, mime_type = await synthesize_for_user(
            user_id,
            opening
        )

    except RoleplayTtsError as error:

        logger.warning(
            'Roleplay opening TTS unavailable user=%s provider_error=%s',
            user_id,
            str(error)[:200],
        )

        # Do not leave a successful-looking session when the opening voice failed.
        try:
            (
                db.table('english_roleplay_messages')
                .delete()
                .eq('session_id', sid)
                .eq('user_id', user_id)
                .execute()
            )

            (
                db.table('english_roleplay_sessions')
                .delete()
                .eq('id', sid)
                .eq('user_id', user_id)
                .execute()
            )

        except Exception:
            logger.exception(
                'Failed to clean up failed roleplay start user=%s',
                user_id
            )

        raise chat.EnglishPracticeError(
            'AI voice could not be generated. Please try again.',
            502
        ) from error

    if not audio:
        raise chat.EnglishPracticeError(
            'AI voice returned empty audio. Please try again.',
            502
        )

    db.table('english_roleplay_messages').insert({
        'session_id': sid,
        'user_id': user_id,
        'role': 'assistant',
        'message': opening,
    }).execute()

    result = {
        'session_id': sid,
        'scenario': scenario,
        'started_at': row['started_at'],
        'opening_reply': opening,
        'suggestions': opening_suggestions,
        'audio_bytes': audio,
        'audio_mime_type': mime_type,
    }

    if opening_mcq is not None:
        result['mcq'] = opening_mcq

    return result


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
    messages = [{'role': 'system', 'content': build_roleplay_prompt(scenario=session['scenario'], native_language=session['native_language'], target_language=session.get('target_language', 'English'), learning_memory=memory_context)}]
    messages += [{'role': r['role'], 'content': r['message']} for r in reversed(rows)]
    reply_raw = await chat._call_model(messages)
    reply, suggestions, mcq = chat._split_and_extract(reply_raw)
    if not reply.strip():
        reply = 'Okay — let me think. Could you say that again a little more simply?'
    assistant_insert = db.table('english_roleplay_messages').insert({'session_id': session_id, 'user_id': user_id, 'role': 'assistant', 'message': reply}).execute()
    assistant_id = ((assistant_insert.data or [{}])[0]).get('id')
    learning_memory.schedule_update(user_id=user_id, native_language=session['native_language'], mode='roleplay', user_text=text, assistant_text=reply, scenario=session['scenario'])
    db.table('english_roleplay_sessions').update({'updated_at': _now()}).eq('id', session_id).execute()
    result = {'transcript': text, 'reply': reply, 'suggestions': suggestions, 'assistant_message_id': assistant_id}
    if mcq is not None:
        result['mcq'] = mcq
    return result

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
        audio, mime_type = await synthesize_for_user(user_id, result["reply"])
    except RoleplayTtsError as e:
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
        target_language=session.get('target_language', 'English'), learning_memory=memory_context,
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
                pending.append(asyncio.create_task(synthesize_for_user(user_id, chunk)))
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
            pending.append(asyncio.create_task(synthesize_for_user(user_id, chunk)))
        while sequence < len(pending):
            audio, mime_type = await pending[sequence]
            yield {
                'type': 'audio_chunk',
                'sequence': sequence,
                'audio_bytes': audio,
                'audio_mime_type': mime_type,
            }
            sequence += 1
    except RoleplayTtsError as error:
        raise chat.EnglishPracticeError(str(error), 502) from error
    finally:
        for task in pending[sequence:]:
            if not task.done():
                task.cancel()

    reply_raw = ''.join(reply_parts).strip()
    reply, suggestions, mcq = chat._split_and_extract(reply_raw)
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
    done_event = {
        'type': 'done',
        'transcript': transcript,
        'reply': reply,
        'suggestions': suggestions,
        'sequence_count': sequence,
    }
    if mcq is not None:
        done_event['mcq'] = mcq
    yield done_event

def end(user_id: str, session_id: str, duration_seconds: int | None = None) -> dict:
    session = _session(session_id, user_id)
    if not session: raise chat.EnglishPracticeError('Roleplay session not found.', 404)
    if session.get('status') == 'ended':
        return {'session_id': session_id, 'duration_seconds': int(session.get('duration_seconds') or 0), 'credits_used': int(session.get('credits_used') or 0)}
    seconds = _server_duration_seconds(session['started_at'])
    db = get_supabase_admin()
    # An AI opening line is free. Preserve the no-user-speech/no-charge rule.
    user_rows = db.table('english_roleplay_messages').select('id').eq('session_id', session_id).eq('role', 'user').limit(1).execute().data or []
    credits_used = 0
    new_balance = None
    if user_rows:
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
