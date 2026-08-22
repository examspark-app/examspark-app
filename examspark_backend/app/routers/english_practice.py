"""English Learning — AI conversation practice routes."""
import base64
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import english_practice_service as eps

router = APIRouter(prefix="/api/v1/english-practice", tags=["english-practice"])


class SetLanguageRequest(BaseModel):
    language: str = Field(..., min_length=1, max_length=60)


class SetPreferenceRequest(BaseModel):
    native_language: str = Field(..., min_length=1, max_length=60)
    target_language: str | None = Field(None, min_length=1, max_length=60)


class SendMessageRequest(BaseModel):
    session_id: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1, max_length=2000)


class StartRequest(BaseModel):
    model: str = Field("qwen3", min_length=1, max_length=20)


class _RenameSessionBody(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)


class _PinSessionBody(BaseModel):
    pinned: bool = True


def _http(e: eps.EnglishPracticeError) -> HTTPException:
    return HTTPException(status_code=e.status_code, detail=str(e))


@router.get("/preference")
async def get_preference(user: AuthenticatedUser = Depends(get_current_user)):
    lang = eps.get_native_language(user.user_id)
    target = eps.get_target_language(user.user_id)
    return {"native_language": lang, "target_language": target}


@router.post("/preference")
async def set_preference(
    body: SetPreferenceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        eps.set_native_language(user.user_id, body.native_language)
        if body.target_language is not None:
            eps.set_target_language(user.user_id, body.target_language)
    except eps.EnglishPracticeError as e:
        raise _http(e) from e
    return {
        "native_language": body.native_language,
        "target_language": body.target_language,
    }


@router.post("/start")
async def start(
    body: StartRequest | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        result = await eps.start_session(
            user.user_id,
            model=body.model if body is not None else "qwen3",
        )
        audio = result.pop("audio_bytes", None)
        return {
            **result,
            "audio_base64": base64.b64encode(audio).decode("ascii") if audio else None,
        }
    except eps.EnglishPracticeError as e:
        raise _http(e) from e


@router.post("/message")
async def send_message(
    body: SendMessageRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        result = await eps.send_message(user.user_id, body.session_id, body.message)
        audio = result.pop("audio_bytes", None)
        return {
            **result,
            "audio_base64": base64.b64encode(audio).decode("ascii") if audio else None,
        }
    except eps.EnglishPracticeError as e:
        raise _http(e) from e


@router.post("/turn/audio")
async def send_audio_message(
    session_id: str = Form(...),
    audio: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not (audio.content_type or "").lower().startswith("audio/"):
        raise HTTPException(status_code=415, detail="Unsupported audio format.")
    payload = await audio.read()
    if len(payload) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Audio is too large. Keep one turn under 10 MB.")
    try:
        result = await eps.send_audio_message(
            user.user_id, session_id, payload, audio.filename or "english_chat_audio.m4a"
        )
        audio_bytes = result.pop("audio_bytes", None)
        return {
            **result,
            "audio_base64": base64.b64encode(audio_bytes).decode("ascii") if audio_bytes else None,
        }
    except eps.EnglishPracticeError as e:
        raise _http(e) from e


@router.get("/sessions")
async def sessions(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = 30,
):
    return {"sessions": eps.list_sessions(user.user_id, limit=limit)}


@router.get("/sessions/latest-active")
async def latest_active_session(
    user: AuthenticatedUser = Depends(get_current_user),
):
    return {"session": eps.latest_active_session(user.user_id)}


@router.get("/sessions/{session_id}")
async def restore(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    data = eps.restore_session(session_id, user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Session not found.")
    return data


@router.patch("/sessions/{session_id}")
async def patch_session(
    session_id: str,
    body: _RenameSessionBody,
    user: AuthenticatedUser = Depends(get_current_user),
):
    row = eps.rename_session(session_id, user.user_id, body.title)
    if not row:
        raise HTTPException(status_code=404, detail="Session not found.")
    return {"id": row["id"], "title": row.get("title")}


@router.post("/sessions/{session_id}/pin")
async def post_session_pin(
    session_id: str,
    body: _PinSessionBody,
    user: AuthenticatedUser = Depends(get_current_user),
):
    ok = eps.set_session_pinned(session_id, user.user_id, body.pinned)
    if not ok:
        raise HTTPException(status_code=404, detail="Session not found.")
    return {"id": session_id, "pinned": body.pinned}


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    ok = eps.delete_session(session_id, user.user_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Session not found.")
    return {"ok": True}
