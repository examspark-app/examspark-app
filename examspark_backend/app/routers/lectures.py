"""Lecture pipeline routes — audio + vision/PDF (Phase 5 Vision Session).

`POST /process` accepts multipart file + metadata. Dispatches by source_type:
recording/audio_upload → Whisper+Qwen3; image_upload → Qwen3-VL; pdf_upload → text PDF or 400 for scans.
"""
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.models.lecture import (
    LectureJobStatusResponse,
    LectureSourceType,
    ProcessedNotes,
    ProcessLectureRequest,
    ProcessLectureResponse,
)
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.lecture_service import LecturePipelineError, LectureService
from app.services.rag_index_service import RagIndexError, ensure_lecture_indexed

router = APIRouter(prefix="/api/v1/lectures", tags=["lectures"])
_service = LectureService()


@router.post("/process", response_model=ProcessLectureResponse)
async def process_lecture(
    source_type: LectureSourceType = Form(...),
    subject: str | None = Form(default=None),
    topic: str | None = Form(default=None),
    duration_minutes: int | None = Form(default=None),
    lecture_id: str | None = Form(default=None),
    file: UploadFile | None = File(default=None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    request = ProcessLectureRequest(
        source_type=source_type,
        subject=subject,
        topic=topic,
        duration_minutes=duration_minutes,
    )
    file_bytes = await file.read() if file else None

    try:
        return await _service.create_job(
            user_id=user.user_id,
            request=request,
            filename=file.filename if file else None,
            file_bytes=file_bytes,
            lecture_id=lecture_id,
        )
    except LecturePipelineError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.get("/{lecture_id}/notes", response_model=ProcessedNotes)
async def get_lecture_notes(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_lecture_notes(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.post("/{lecture_id}/index")
async def index_lecture_for_rag(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Part A smoke: index notes+transcript into rag_documents (lazy / idempotent)."""
    try:
        return await ensure_lecture_indexed(user.user_id, str(lecture_id))
    except RagIndexError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.get("/jobs/{job_id}", response_model=LectureJobStatusResponse)
async def get_job_status(
    job_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    result = await _service.get_job_status(job_id, user.user_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found.")
    return result
