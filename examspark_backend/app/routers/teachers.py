"""Teacher Verification v1 — Get Verified (Dashboard only, optional)."""
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import teacher_verification_service as tvs

router = APIRouter(prefix="/api/v1/teachers", tags=["teachers"])


@router.post("/verify-certificate")
async def verify_certificate(
    file: UploadFile = File(...),
    title: str | None = Form(None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Soft AI verify education certificate (+ optional Tavily institution check)."""
    raw = await file.read()
    try:
        return await tvs.verify_teacher_certificate(
            user_id=user.user_id,
            image_bytes=raw,
            filename=file.filename,
            title=title,
        )
    except tvs.TeacherVerificationError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e
