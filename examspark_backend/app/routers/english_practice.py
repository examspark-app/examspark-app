"""English Learning — AI conversation practice routes."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import english_practice_service as eps

router = APIRouter(prefix="/api/v1/english-practice", tags=["english-practice"])


class SetLanguageRequest(BaseModel):
    language: str = Field(..., min_length=1, max_length=60)


class SendMessageRequest(BaseModel):
    session_id: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1, max_length=2000)


def _http(e: eps.EnglishPracticeError) -> HTTPException:
    return HTTPException(status_code=e.status_code, detail=str(e))


@router.get("/preference")
async def get_preference(user: AuthenticatedUser = Depends(get_current_user)):
    lang = eps.get_native_language(user.user_id)
    return {"native_language": lang}


@router.post("/preference")
async def set_preference(
    body: SetLanguageRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        eps.set_native_language(user.user_id, body.language)
    except eps.EnglishPracticeError as e:
        raise _http(e) from e
    return {"native_language": body.language}


@router.post("/start")
async def start(user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return await eps.start_session(user.user_id)
    except eps.EnglishPracticeError as e:
        raise _http(e) from e


@router.post("/message")
async def send_message(
    body: SendMessageRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await eps.send_message(user.user_id, body.session_id, body.message)
    except eps.EnglishPracticeError as e:
        raise _http(e) from e


@router.get("/sessions")
async def sessions(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = 30,
):
    return {"sessions": eps.list_sessions(user.user_id, limit=limit)}


@router.get("/sessions/{session_id}")
async def restore(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    data = eps.restore_session(session_id, user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Session not found.")
    return data