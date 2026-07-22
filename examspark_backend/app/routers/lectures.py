"""Lecture pipeline routes — audio + vision/PDF + YouTube (Phase 5).

`POST /process` accepts multipart file + metadata (or youtube_url for captions).
Dispatches by source_type: recording/audio_upload → Whisper+Qwen3;
image_upload → Qwen3-VL; pdf_upload → text PDF; youtube_link → captions + Qwen3.
"""
import asyncio
import logging
import time
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status

from app.models.lecture import (
    FlashcardsPayload,
    ImportantQuestionsPayload,
    LectureJobStatusResponse,
    LectureSourceType,
    MindMapPayload,
    ProcessedNotes,
    ProcessLectureRequest,
    ProcessLectureResponse,
    QuizPayload,
    RevisionPayload,
    TranscriptPayload,
)
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.lecture_service import LecturePipelineError, LectureService
from app.services.rag_index_service import RagIndexError, ensure_lecture_indexed

router = APIRouter(prefix="/api/v1/lectures", tags=["lectures"])
_service = LectureService()
_logger = logging.getLogger("examspark.pipeline_timing")


@router.post("/process", response_model=ProcessLectureResponse)
async def process_lecture(
    source_type: LectureSourceType = Form(...),
    subject: str | None = Form(default=None),
    topic: str | None = Form(default=None),
    duration_minutes: int | None = Form(default=None),
    lecture_id: str | None = Form(default=None),
    youtube_url: str | None = Form(default=None),
    file: UploadFile | None = File(default=None),
    user: AuthenticatedUser = Depends(get_current_user),
):
    request = ProcessLectureRequest(
        source_type=source_type,
        subject=subject,
        topic=topic,
        duration_minutes=duration_minutes,
    )
    upload_t0 = time.perf_counter()
    file_bytes = await file.read() if file else None
    upload_sec = round(time.perf_counter() - upload_t0, 3)
    _logger.info(
        "pipeline_timing lecture_id=%s label=upload upload=%.1fs upload_bytes=%s",
        lecture_id or "-",
        upload_sec,
        len(file_bytes) if file_bytes else 0,
    )

    try:
        return await _service.create_job(
            user_id=user.user_id,
            request=request,
            filename=file.filename if file else None,
            file_bytes=file_bytes,
            lecture_id=lecture_id,
            youtube_url=youtube_url,
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e
    except Exception as e:  # noqa: BLE001
        # Surface real cause in server logs (reload mid-request often shows as bare 500).
        _logger.exception(
            "process_lecture unexpected source_type=%s lecture_id=%s: %s",
            source_type,
            lecture_id,
            e,
        )
        raise HTTPException(
            status_code=500,
            detail=f"Processing failed: {type(e).__name__}: {e}",
        ) from e


@router.get("/{lecture_id}/notes", response_model=ProcessedNotes)
async def get_lecture_notes(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await asyncio.to_thread(
            _service.get_lecture_notes, user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/transcript", response_model=TranscriptPayload)
async def get_lecture_transcript(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Read-only clean transcript from R2 — free, no AI, no credits."""
    try:
        return _service.get_lecture_transcript(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


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


@router.get("/{lecture_id}/flashcards", response_model=FlashcardsPayload)
async def get_lecture_flashcards(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_flashcards_for_lecture(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/flashcards", response_model=FlashcardsPayload)
async def generate_lecture_flashcards(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_flashcards_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/quiz", response_model=QuizPayload)
async def get_lecture_quiz(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_quiz_for_lecture(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/quiz", response_model=QuizPayload)
async def generate_lecture_quiz(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_quiz_for_lecture(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/revision", response_model=RevisionPayload)
async def get_lecture_revision(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_revision_for_lecture(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/revision", response_model=RevisionPayload)
async def generate_lecture_revision(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_revision_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/five-min-revision", response_model=RevisionPayload)
async def get_lecture_five_min_revision(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_five_min_revision_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/five-min-revision", response_model=RevisionPayload)
async def generate_lecture_five_min_revision(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_five_min_revision_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/important-questions", response_model=ImportantQuestionsPayload)
async def get_lecture_important_questions(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_important_questions_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/important-questions", response_model=ImportantQuestionsPayload)
async def generate_lecture_important_questions(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_important_questions_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/{lecture_id}/mind-map", response_model=MindMapPayload)
async def get_lecture_mind_map(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return _service.get_mind_map_for_lecture(user.user_id, str(lecture_id))
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.post("/{lecture_id}/mind-map", response_model=MindMapPayload)
async def generate_lecture_mind_map(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return await _service.generate_mind_map_for_lecture(
            user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.delete("/{lecture_id}")
async def delete_lecture(
    lecture_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Permanent owner delete — R2 folder + DB row (cascade notes/RAG/extras)."""
    try:
        return await asyncio.to_thread(
            _service.delete_lecture_for_user, user.user_id, str(lecture_id)
        )
    except LecturePipelineError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=e.detail if e.detail is not None else str(e),
        ) from e


@router.get("/jobs/{job_id}", response_model=LectureJobStatusResponse)
async def get_job_status(
    job_id: uuid.UUID,
    user: AuthenticatedUser = Depends(get_current_user),
):
    result = await _service.get_job_status(job_id, user.user_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found.")
    return result
