import asyncio
from collections.abc import AsyncIterator
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.glow_guide_service import GlowGuideError, turn
from app.services.openrouter_stream import format_sse

router = APIRouter(prefix="/api/v1/glow-guide", tags=["glow-guide"])


async def _glow_guide_sse(
    *,
    user_id: str,
    text: str,
    category: str | None,
    session_id: str | None,
    language: str | None,
    age: str | None,
    weather: str | None,
    image_bytes: bytes | None,
    filename: str | None,
    selected_model: str | None,
) -> AsyncIterator[str]:
    events: asyncio.Queue[dict] = asyncio.Queue()

    async def on_event(event: dict) -> None:
        await events.put(event)

    async def run_turn() -> None:
        try:
            result = await turn(
                user_id,
                session_id,
                category,
                text,
                image_bytes,
                filename,
                language,
                age,
                weather,
                on_event=on_event,
                selected_model=selected_model,
            )
            await events.put({"type": "done", **result})
        except GlowGuideError as error:
            await events.put({
                "type": "error",
                "message": str(error),
                "status": error.status_code,
            })
        except Exception as error:  # noqa: BLE001
            await events.put({"type": "error", "message": str(error), "status": 500})

    task = asyncio.create_task(run_turn())
    try:
        while True:
            event = await events.get()
            yield format_sse(event)
            if event.get("type") in {"done", "error"}:
                break
    finally:
        if not task.done():
            task.cancel()


@router.post("/turn")
async def glow_guide_turn(
    text: str = Form(""),
    category: str | None = Form(None),
    session_id: str | None = Form(None),
    language: str | None = Form(None),
    age: str | None = Form(None),
    weather: str | None = Form(None),
    selected_model: str | None = Form(None),
    image: UploadFile | None = File(None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    image_bytes = None
    filename = None
    if image is not None:
        image_bytes = await image.read()
        filename = image.filename
        if len(image_bytes) > 8 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Photo is too large (max 8 MB).")
    try:
        return await turn(user.user_id, session_id, category, text, image_bytes, filename, language, age, weather, selected_model=selected_model)
    except GlowGuideError as error:
        raise HTTPException(status_code=error.status_code, detail=str(error)) from error


@router.post("/turn/stream")
async def glow_guide_turn_stream(
    text: str = Form(""),
    category: str | None = Form(None),
    session_id: str | None = Form(None),
    language: str | None = Form(None),
    age: str | None = Form(None),
    weather: str | None = Form(None),
    selected_model: str | None = Form(None),
    image: UploadFile | None = File(None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    image_bytes = None
    filename = None
    if image is not None:
        image_bytes = await image.read()
        filename = image.filename
        if len(image_bytes) > 8 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Photo is too large (max 8 MB).")
    return StreamingResponse(
        _glow_guide_sse(
            user_id=user.user_id,
            text=text,
            category=category,
            session_id=session_id,
            language=language,
            age=age,
            weather=weather,
            image_bytes=image_bytes,
            filename=filename,
            selected_model=selected_model,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/sessions/{session_id}")
async def restore_glow_guide_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services.supabase_admin import get_supabase_admin
    db = get_supabase_admin()
    rows = db.table("glow_guide_sessions").select("*").eq("id", session_id).eq("user_id", user.user_id).limit(1).execute().data or []
    if not rows:
        raise HTTPException(status_code=404, detail="GlowGuide session not found.")
    db.table("glow_guide_sessions").update(
        {"updated_at": datetime.now(timezone.utc).isoformat()}
    ).eq("id", session_id).eq("user_id", user.user_id).execute()
    messages = db.table("glow_guide_messages").select(
    "id,role,message,image_path,created_at,question_options,verdict,confidence_note,detailed_breakdown,sources"
).eq("session_id", session_id).eq("user_id", user.user_id).order("created_at", desc=False).execute().data or []
    from app.services.r2_storage_service import R2StorageError, R2StorageService
    r2 = R2StorageService()
    for message in messages:
        if message.get("image_path"):
            try:
                message["image_url"] = r2.signed_url(str(message["image_path"]))
            except R2StorageError:
                message["image_url"] = None
    session = {
        **rows[0],
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    return {
        "session_id": session_id,
        "category": session.get("category_type"),
        "title": session.get("title"),
        "updated_at": session.get("updated_at"),
        "status": session.get("status"),
        "exchange_count": session.get("exchange_count", 0),
        "messages": messages,
    }


class RenameGlowGuideSessionRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)


@router.patch("/sessions/{session_id}")
async def rename_glow_guide_session(
    session_id: str,
    body: RenameGlowGuideSessionRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services import glow_guide_service

    result = glow_guide_service.rename_session(session_id, user.user_id, body.title)
    if result is None:
        raise HTTPException(status_code=404, detail="GlowGuide session not found.")
    return result


@router.get("/sessions")
async def list_glow_guide_sessions(
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services.supabase_admin import get_supabase_admin

    db = get_supabase_admin()
    sessions = db.table("glow_guide_sessions").select(
        "id,title,category_type,status,created_at,updated_at"
    ).eq("user_id", user.user_id).order("updated_at", desc=True).order("id", desc=True).limit(50).execute().data or []
    unique: dict[str, dict] = {}
    for session in sessions:
        session_id = str(session.get("id") or "").strip()
        if session_id and session_id not in unique:
            unique[session_id] = session
    return {"sessions": list(unique.values())}
