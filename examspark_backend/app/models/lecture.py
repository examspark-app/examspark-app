"""Pydantic models for the lecture processing pipeline — Phase 5 Session 1 skeleton.

Session 2 fills in the real Whisper -> Qwen3 -> credits -> R2 flow. This file
only defines the request/response shape so Flutter and FastAPI can agree on
a contract before the pipeline logic exists.
"""
from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class LectureSourceType(str, Enum):
    RECORDING = "recording"
    AUDIO_UPLOAD = "audio_upload"
    PDF_UPLOAD = "pdf_upload"
    IMAGE_UPLOAD = "image_upload"
    YOUTUBE_LINK = "youtube_link"


class LectureJobStatus(str, Enum):
    QUEUED = "queued"
    TRANSCRIBING = "transcribing"
    GENERATING_NOTES = "generating_notes"
    COMPLETE = "complete"
    FAILED = "failed"


class ProcessLectureRequest(BaseModel):
    """Metadata that accompanies the uploaded audio/file (multipart form).

    The actual file bytes travel as a multipart `UploadFile` in the route,
    not in this JSON body — this model documents the sidecar fields.
    """

    source_type: LectureSourceType
    subject: Optional[str] = None
    topic: Optional[str] = None
    duration_minutes: Optional[int] = Field(default=None, ge=0, le=180)


class ProcessedNotes(BaseModel):
    cleanNotes: str = ""
    keyPoints: list = Field(default_factory=list)
    shortSummary: str = ""
    importantTerms: list = Field(default_factory=list)


class ProcessLectureResponse(BaseModel):
    job_id: UUID
    lecture_id: Optional[UUID] = None
    status: LectureJobStatus
    credits_charged: Optional[int] = None
    message: str
    # Mirrors the old edge function's contract so lecture_service.dart's
    # callers keep working unchanged once this switches from Session 1's
    # skeleton to the real Session 2 pipeline.
    transcript: Optional[str] = None
    processedContent: Optional[ProcessedNotes] = None
    usedTurbo: Optional[bool] = None
    # Vision path: True when Qwen3-VL-Plus was used (Flash failed / escalated).
    usedVisionPlus: Optional[bool] = None


class LectureJobStatusResponse(BaseModel):
    job_id: UUID
    status: LectureJobStatus
    lecture_id: Optional[UUID] = None
    error: Optional[str] = None
    created_at: Optional[datetime] = None
