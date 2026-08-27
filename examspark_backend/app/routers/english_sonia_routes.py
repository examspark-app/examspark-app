from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import english_sonia_service as sonia
from app.services import english_practice_service as chat

router = APIRouter(prefix='/api/v1/sonia', tags=['sonia'])


class StartBody(BaseModel):
    scenario: str = Field(..., min_length=1, max_length=300)
    native_language: str = Field(default='English', max_length=60)
    target_language: str = Field(default='English', max_length=60)


class MessageBody(BaseModel):
    session_id: str
    text: str = Field(..., min_length=1, max_length=2000)


def _error(e: chat.EnglishPracticeError):
    return HTTPException(status_code=e.status_code, detail=str(e))


@router.post('/start')
async def start(body: StartBody, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return await sonia.start(
            user.user_id, body.scenario, body.native_language, body.target_language
        )
    except chat.EnglishPracticeError as e:
        raise _error(e) from e


@router.post('/message')
async def message(body: MessageBody, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return await sonia.send_message(user.user_id, body.session_id, body.text)
    except chat.EnglishPracticeError as e:
        raise _error(e) from e


@router.post('/{session_id}/end')
async def end(session_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return sonia.end(user.user_id, session_id)
    except chat.EnglishPracticeError as e:
        raise _error(e) from e


@router.get('/sessions/{session_id}')
async def restore(session_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    data = sonia.restore_session(session_id, user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail='Session not found.')
    return data