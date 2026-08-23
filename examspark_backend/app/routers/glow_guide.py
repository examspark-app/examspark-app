from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.glow_guide_service import GlowGuideError, turn

router = APIRouter(prefix="/api/v1/glow-guide", tags=["glow-guide"])


@router.post("/turn")
async def glow_guide_turn(
    text: str = Form(""),
    category: str | None = Form(None),
    session_id: str | None = Form(None),
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
        return await turn(user.user_id, session_id, category, text, image_bytes, filename)
    except GlowGuideError as error:
        raise HTTPException(status_code=error.status_code, detail=str(error)) from error


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
    messages = db.table("glow_guide_messages").select("id,role,message,created_at").eq("session_id", session_id).eq("user_id", user.user_id).order("created_at", desc=False).execute().data or []
    return {"session_id": session_id, "category": rows[0].get("category_type"), "messages": messages}


@router.get("/sessions")
async def list_glow_guide_sessions(
    user: AuthenticatedUser = Depends(get_current_user),
):
    from app.services.supabase_admin import get_supabase_admin

    db = get_supabase_admin()
    sessions = db.table("glow_guide_sessions").select(
        "id,category_type,status,created_at,updated_at"
    ).eq("user_id", user.user_id).order("updated_at", desc=True).limit(50).execute().data or []
    return {"sessions": sessions}
