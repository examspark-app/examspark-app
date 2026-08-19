import base64
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import english_roleplay_service as service
from app.services import english_practice_service as chat
from app.services import roleplay_tts_service as tts
from app.services.openrouter_stream import format_sse

router = APIRouter(prefix='/api/v1/english-roleplay', tags=['english-roleplay'])
class StartBody(BaseModel): scenario: str = Field(..., min_length=1, max_length=300); native_language: str = Field(default='English', max_length=60)
class TurnBody(BaseModel): session_id: str; transcript: str = Field(..., min_length=1, max_length=4000)
class EndBody(BaseModel): duration_seconds: int | None = Field(default=None, ge=0)
class VoicePreferenceBody(BaseModel):
    provider: str = Field(..., pattern='^(qwen|gemini)$')
    voice_key: str = Field(..., min_length=1, max_length=30)
def _error(e: chat.EnglishPracticeError): return HTTPException(status_code=e.status_code, detail=str(e))
@router.post('/start')
async def start(body: StartBody, user: AuthenticatedUser = Depends(get_current_user)):
    try: return service.start(user.user_id, body.scenario, body.native_language)
    except chat.EnglishPracticeError as e: raise _error(e) from e
@router.get('/voice-preference')
async def get_voice_preference(user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return tts.get_voice_preference(user.user_id)
    except tts.RoleplayTtsError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
@router.put('/voice-preference')
async def set_voice_preference(body: VoicePreferenceBody, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return tts.set_voice_preference(user.user_id, body.provider, body.voice_key)
    except tts.RoleplayTtsError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
@router.post('/turn')
async def turn(body: TurnBody, user: AuthenticatedUser = Depends(get_current_user)):
    try: return await service.send_turn(user.user_id, body.session_id, body.transcript)
    except chat.EnglishPracticeError as e: raise _error(e) from e
@router.post('/turn/audio')
async def audio_turn(
    session_id: str = Form(...),
    audio: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not (audio.content_type or '').lower().startswith('audio/'):
        raise HTTPException(status_code=415, detail='Unsupported audio format.')
    payload = await audio.read()
    if len(payload) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='Audio is too large. Keep one turn under 10 MB.')
    try:
        result = await service.send_audio_turn(
            user.user_id, session_id, payload, audio.filename or 'roleplay_audio.m4a'
        )
    except chat.EnglishPracticeError as e:
        raise _error(e) from e
    return {
        'transcript': result['transcript'],
        'reply': result['reply'],
        'audio_base64': base64.b64encode(result['audio_bytes']).decode('ascii'),
        'audio_mime_type': result['audio_mime_type'],
    }


async def _roleplay_sse_events(
    user_id: str, session_id: str, audio_bytes: bytes, filename: str,
) -> AsyncIterator[str]:
    audio_emitted = False
    try:
        async for event in service.stream_audio_turn(user_id, session_id, audio_bytes, filename):
            if event.get('type') == 'audio_chunk':
                audio_emitted = True
                event = {
                    **event,
                    'audio_base64': base64.b64encode(event.pop('audio_bytes')).decode('ascii'),
                }
            yield f"event: {event.get('type', 'message')}\n{format_sse(event)}"
    except chat.EnglishPracticeError as error:
        payload = {
            'type': 'error', 'message': str(error), 'status_code': error.status_code,
            'can_fallback': not audio_emitted,
        }
        yield f"event: error\n{format_sse(payload)}"


@router.post('/turn/audio/stream')
async def stream_audio_turn(
    session_id: str = Form(...),
    audio: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not (audio.content_type or '').lower().startswith('audio/'):
        raise HTTPException(status_code=415, detail='Unsupported audio format.')
    payload = await audio.read()
    if len(payload) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail='Audio is too large. Keep one turn under 10 MB.')
    return StreamingResponse(
        _roleplay_sse_events(user.user_id, session_id, payload, audio.filename or 'roleplay_audio.m4a'),
        media_type='text/event-stream',
        headers={'Cache-Control': 'no-cache', 'Connection': 'keep-alive', 'X-Accel-Buffering': 'no'},
    )
@router.get('/sessions')
async def sessions(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = Query(default=30, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
):
    return {'sessions': service.list_sessions(user.user_id, limit=limit, offset=offset)}
@router.get('/sessions/{session_id}')
async def restore(session_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    data = service.restore_session(session_id, user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail='Roleplay session not found.')
    return data
@router.post('/{session_id}/end')
async def end(session_id: str, body: EndBody, user: AuthenticatedUser = Depends(get_current_user)):
    try: return service.end(user.user_id, session_id, body.duration_seconds)
    except chat.EnglishPracticeError as e: raise _error(e) from e
