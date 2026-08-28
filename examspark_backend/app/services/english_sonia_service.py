"""Sonia — WhatsApp-style text-only roleplay chat. Reuses the same
roleplay prompt/pacing logic as voice-roleplay, text-only, Qwen3 primary
with Gemini fallback."""
import logging
import re
from datetime import datetime, timezone

from app.constants.english_roleplay_prompt import build_roleplay_prompt
from app.services import english_practice_service as chat
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.supabase_admin import get_supabase_admin
from app.services import english_learning_memory_service as learning_memory

SONIA_CREDITS_PER_MESSAGE = 1

# Message length rules — keep chat turns short and controlled.
SONIA_MESSAGE_MIN_CHARS = 1
SONIA_MESSAGE_MAX_CHARS = 200


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _session(session_id: str, user_id: str) -> dict | None:
    rows = (
        get_supabase_admin()
        .table('english_sonia_sessions')
        .select('*')
        .eq('id', session_id)
        .eq('user_id', user_id)
        .limit(1)
        .execute()
        .data
        or []
    )
    return rows[0] if rows else None





async def start(
    user_id: str,
    scenario: str,
    native_language: str,
    target_language: str = 'English',
) -> dict:
    scenario = scenario.strip()
    if not scenario:
        raise chat.EnglishPracticeError('Choose a scenario.', 400)

    db = get_supabase_admin()
    row = (
        db.table('english_sonia_sessions')
        .insert({
            'user_id': user_id,
            'scenario': scenario,
            'native_language': native_language,
            'target_language': target_language,
            'status': 'active',
        })
        .execute()
        .data[0]
    )
    sid = row['id']

    memory_context = learning_memory.format_memory_context(
        learning_memory.load_memory(user_id, target_language),
        mode='roleplay',
    )
    sys_prompt = build_roleplay_prompt(
        scenario=scenario,
        native_language=native_language,
        target_language=target_language,
        learning_memory=memory_context,
        turn_number=0,
    )

    opening_messages = [
        {'role': 'system', 'content': sys_prompt},
        {
            'role': 'user',
            'content': (
                '(system: Send your opening line now, in character, '
                'exactly as instructed in the system prompt — short, '
                'warm, scenario-specific. Then wait.)'
            ),
        },
    ]
    try:
        opening_raw = await chat._call_chat_model(opening_messages, 'qwen3')
    except Exception as primary_error:
        logging.warning(
            'Sonia opening: qwen3 failed, falling back to gemini: %s',
            primary_error,
        )
        opening_raw = await chat._call_chat_model(opening_messages, 'gemini')
    opening_clean, _, _ = chat._split_and_extract(opening_raw)
    opening = opening_clean.strip() or 'Hey! Ready to start?'

    db.table('english_sonia_messages').insert({
        'session_id': sid,
        'user_id': user_id,
        'role': 'assistant',
        'message': opening,
    }).execute()

    return {
        'session_id': sid,
        'scenario': scenario,
        'started_at': row['started_at'],
        'opening_reply': opening,
        'character_name': 'Sonia',
        'avatar_path': 'images/sonia_avatar.png',
    }


async def send_message(user_id: str, session_id: str, text: str) -> dict:
    session = _session(session_id, user_id)
    text = text.strip()
    if not session:
        raise chat.EnglishPracticeError('Session not found.', 404)
    if session['status'] != 'active':
        raise chat.EnglishPracticeError('This chat has ended.', 409)
    if len(text) < SONIA_MESSAGE_MIN_CHARS:
        raise chat.EnglishPracticeError('Message is empty.', 400)
    if len(text) > SONIA_MESSAGE_MAX_CHARS:
        raise chat.EnglishPracticeError(
            f'Message is too long — keep it under {SONIA_MESSAGE_MAX_CHARS} characters.',
            400,
        )

    db = get_supabase_admin()

    try:
        new_balance = deduct_credits(
            user_id=user_id,
            amount=SONIA_CREDITS_PER_MESSAGE,
            description='Sonia Chat message',
            action='english_sonia',
        )
    except InsufficientCreditsError as e:
        raise chat.EnglishPracticeError(str(e), 402) from e

    

    db.table('english_sonia_messages').insert({
        'session_id': session_id,
        'user_id': user_id,
        'role': 'user',
        'message': text,
    }).execute()

    rows = (
        db.table('english_sonia_messages')
        .select('role,message')
        .eq('session_id', session_id)
        .order('created_at', desc=True)
        .limit(8)
        .execute()
        .data
        or []
    )
    turn_number = len(rows)

    memory_context = learning_memory.format_memory_context(
        learning_memory.load_memory(
            user_id, session.get('target_language', 'English')
        ),
        mode='roleplay',
    )
    messages = [
        {
            'role': 'system',
            'content': build_roleplay_prompt(
                scenario=session['scenario'],
                native_language=session['native_language'],
                target_language=session.get('target_language', 'English'),
                learning_memory=memory_context,
                turn_number=turn_number,
            ),
        }
    ]
    messages += [{'role': r['role'], 'content': r['message']} for r in reversed(rows)]

    try:
        reply_raw = await chat._call_chat_model(messages, 'qwen3')
    except Exception as primary_error:
        logging.warning(
            'Sonia message: qwen3 failed, falling back to gemini: %s',
            primary_error,
        )
        reply_raw = await chat._call_chat_model(messages, 'gemini')
    reply, suggestions, mcq = chat._split_and_extract(reply_raw)
    reply = reply.strip() or 'Sorry, could you say that again?'

    # Keep Sonia's own replies within the same length rule so turns stay short.
    if len(reply) > SONIA_MESSAGE_MAX_CHARS:
        reply = reply[:SONIA_MESSAGE_MAX_CHARS].rstrip()

    db.table('english_sonia_messages').insert({
        'session_id': session_id,
        'user_id': user_id,
        'role': 'assistant',
        'message': reply,
    }).execute()

    learning_memory.schedule_update(
        user_id=user_id,
        native_language=session['native_language'],
        target_language=session.get('target_language', 'English'),
        mode='roleplay',
        user_text=text,
        assistant_text=reply,
        scenario=session['scenario'],
    )
    db.table('english_sonia_sessions').update({'updated_at': _now()}).eq(
        'id', session_id
    ).execute()

    result = {
        'reply': reply,
        'suggestions': suggestions,
        'credits_charged': SONIA_CREDITS_PER_MESSAGE,
        'new_balance': new_balance,
    }
    if mcq is not None:
        result['mcq'] = mcq
    return result


def end(user_id: str, session_id: str) -> dict:
    session = _session(session_id, user_id)
    if not session:
        raise chat.EnglishPracticeError('Session not found.', 404)
    get_supabase_admin().table('english_sonia_sessions').update(
        {'status': 'ended', 'ended_at': _now(), 'updated_at': _now()}
    ).eq('id', session_id).execute()
    return {'session_id': session_id}


def restore_session(session_id: str, user_id: str) -> dict | None:
    session = _session(session_id, user_id)
    if not session:
        return None
    messages = (
        get_supabase_admin()
        .table('english_sonia_messages')
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
        'character_name': 'Sonia',
        'avatar_path': 'images/sonia_avatar.png',
        'status': session.get('status'),
        'messages': list(messages),
    }