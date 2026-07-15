"""Lecture processing pipeline — audio (Session 2) + vision/PDF (Vision Session).

Audio: Whisper → Qwen3 text → credits → R2
Image: plan-tier check → Qwen3-VL Flash (+ Plus escalate) → 25 credits → R2
PDF text: plan-tier (Free OK) → extract text → Qwen3 text → 20 credits → R2
Scanned PDF (little text): clear 400 — upload JPG/PNG instead (no silent VL misroute).

Credits deducted only after AI succeeds (Rule 1). Tier check before credits (Rule 6).
"""
from __future__ import annotations

import io
import uuid
from datetime import datetime, timezone

from app.constants.credit_costs import (
    DIAGRAM_IMAGE,
    PDF_ANALYSIS,
    record_credits_for_duration_minutes,
)
from app.models.lecture import (
    LectureJobStatus,
    LectureJobStatusResponse,
    LectureSourceType,
    ProcessedNotes,
    ProcessLectureRequest,
    ProcessLectureResponse,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    require_feature_unlocked,
)
from app.services.qwen_service import QwenGenerationError, generate_notes
from app.services.qwen_vision_service import QwenVisionError, analyze_image
from app.services.r2_storage_service import R2StorageError, R2StorageService
from app.services.supabase_admin import get_supabase_admin
from app.services.whisper_service import WhisperTranscriptionError, transcribe_audio

_PDF_MIN_TEXT_CHARS = 200


class LecturePipelineError(Exception):
    """Wraps any pipeline failure with an HTTP-status-appropriate hint."""

    def __init__(self, message: str, status_code: int = 500):
        super().__init__(message)
        self.status_code = status_code


def _extract_pdf_text(file_bytes: bytes) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as e:
        raise LecturePipelineError(
            "PDF support requires pypdf — install backend requirements.",
            status_code=500,
        ) from e

    try:
        reader = PdfReader(io.BytesIO(file_bytes))
        parts: list[str] = []
        for page in reader.pages:
            parts.append(page.extract_text() or "")
        return "\n".join(parts).strip()
    except Exception as e:  # noqa: BLE001
        raise LecturePipelineError(f"Failed to read PDF: {e}", status_code=400) from e


def _is_image_filename(filename: str | None) -> bool:
    name = (filename or "").lower()
    return name.endswith((".jpg", ".jpeg", ".png", ".webp", ".gif"))


def _guess_image_content_type(filename: str | None) -> str:
    name = (filename or "").lower()
    if name.endswith(".png"):
        return "image/png"
    if name.endswith(".webp"):
        return "image/webp"
    if name.endswith(".gif"):
        return "image/gif"
    return "image/jpeg"


class LectureService:
    _jobs: dict[str, dict] = {}

    def __init__(self):
        self._r2 = R2StorageService()

    async def create_job(
        self,
        user_id: str,
        request: ProcessLectureRequest,
        filename: str | None,
        file_bytes: bytes | None,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        job_id = uuid.uuid4()
        self._jobs[str(job_id)] = {
            "user_id": user_id,
            "status": LectureJobStatus.QUEUED,
            "lecture_id": lecture_id,
            "created_at": datetime.now(timezone.utc),
            "error": None,
        }

        if not file_bytes:
            raise LecturePipelineError("No file received.", status_code=400)

        source = request.source_type
        if source in (LectureSourceType.RECORDING, LectureSourceType.AUDIO_UPLOAD):
            return await self._run_audio_pipeline(
                job_id, user_id, request, filename, file_bytes, lecture_id
            )
        if source == LectureSourceType.IMAGE_UPLOAD:
            return await self._run_vision_pipeline(
                job_id, user_id, filename, file_bytes, lecture_id
            )
        if source == LectureSourceType.PDF_UPLOAD:
            return await self._run_pdf_pipeline(
                job_id, user_id, filename, file_bytes, lecture_id
            )

        raise LecturePipelineError(
            f"source_type '{source}' is not handled by this endpoint yet.",
            status_code=400,
        )

    def _db_set_status(
        self, lecture_id: str | None, status: str, error_message: str | None = None
    ) -> None:
        """Writes `status` (+ `error_message` when the pipeline failed) so
        ProcessingScreen's realtime listener can show the real failure reason
        instead of a generic "network problem" message. Cleared back to NULL
        on any non-error status so a later retry doesn't show a stale error.
        """
        if not lecture_id:
            return
        db = get_supabase_admin()
        update: dict = {
            "status": status,
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "error_message": error_message if status == "error" else None,
        }
        db.table("lectures").update(update).eq("id", lecture_id).execute()

    def _precheck_balance(self, user_id: str, required_credits: int) -> None:
        db = get_supabase_admin()
        profile = db.table("users").select("credits_balance").eq("id", user_id).single().execute()
        balance = (profile.data or {}).get("credits_balance", 0)
        if balance < required_credits:
            raise LecturePipelineError(
                f"Insufficient credits: balance {balance} < required {required_credits}",
                status_code=402,
            )

    async def _run_audio_pipeline(
        self,
        job_id: uuid.UUID,
        user_id: str,
        request: ProcessLectureRequest,
        filename: str | None,
        audio_bytes: bytes,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        try:
            require_feature_unlocked(user_id, GatedFeature.RECORD_LECTURE)
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise LecturePipelineError(str(e), status_code=403) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.TRANSCRIBING
            self._db_set_status(lecture_id, "transcribing")

            required_credits = record_credits_for_duration_minutes(request.duration_minutes or 60)
            self._precheck_balance(user_id, required_credits)

            transcription = await transcribe_audio(audio_bytes, filename or "audio.webm")

            self._db_set_status(lecture_id, "generating")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            notes = await generate_notes(transcription.text)

            new_balance = deduct_credits(
                user_id=user_id,
                amount=required_credits,
                description=(
                    f"Recording ({request.duration_minutes or '?'} min) — "
                    f"{'Turbo' if transcription.used_turbo else 'Non-Turbo'} Whisper + Qwen3 notes"
                ),
                lecture_id=lecture_id,
                action="audio_transcription",
            )

            r2_paths = self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=transcription.text,
                notes=notes,
            )

            self._db_set_status(lecture_id, "done")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE

            return ProcessLectureResponse(
                job_id=job_id,
                lecture_id=lecture_id,
                status=LectureJobStatus.COMPLETE,
                credits_charged=required_credits,
                message=f"Processed. New balance: {new_balance}. R2: {r2_paths}",
                transcript=transcription.text,
                processedContent=ProcessedNotes(**notes),
                usedTurbo=transcription.used_turbo,
                usedVisionPlus=None,
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=403) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (WhisperTranscriptionError, QwenGenerationError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(f"Unexpected pipeline error: {e}", status_code=500) from e

    async def _run_vision_pipeline(
        self,
        job_id: uuid.UUID,
        user_id: str,
        filename: str | None,
        image_bytes: bytes,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        try:
            require_feature_unlocked(user_id, GatedFeature.DIAGRAM_ANALYSIS)
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise LecturePipelineError(str(e), status_code=403) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            self._db_set_status(lecture_id, "generating")

            required_credits = DIAGRAM_IMAGE
            self._precheck_balance(user_id, required_credits)

            vision = await analyze_image(image_bytes, filename=filename)
            notes = vision.notes

            new_balance = deduct_credits(
                user_id=user_id,
                amount=required_credits,
                description=(
                    f"Diagram/Image — Qwen3-VL-{'Plus' if vision.used_plus else 'Flash'}"
                ),
                lecture_id=lecture_id,
                action="diagram_image",
            )

            r2_paths = self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text="",
                notes=notes,
                source_bytes=image_bytes,
                source_filename=filename,
                source_content_type=_guess_image_content_type(filename),
            )

            self._db_set_status(lecture_id, "done")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE

            return ProcessLectureResponse(
                job_id=job_id,
                lecture_id=lecture_id,
                status=LectureJobStatus.COMPLETE,
                credits_charged=required_credits,
                message=f"Vision processed. New balance: {new_balance}. R2: {r2_paths}",
                transcript=None,
                processedContent=ProcessedNotes(**notes),
                usedTurbo=None,
                usedVisionPlus=vision.used_plus,
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=403) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (QwenVisionError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(f"Unexpected vision pipeline error: {e}", status_code=500) from e

    async def _run_pdf_pipeline(
        self,
        job_id: uuid.UUID,
        user_id: str,
        filename: str | None,
        file_bytes: bytes,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        # Image mislabeled as pdf_upload — route to vision.
        if _is_image_filename(filename):
            return await self._run_vision_pipeline(
                job_id, user_id, filename, file_bytes, lecture_id
            )

        try:
            require_feature_unlocked(user_id, GatedFeature.PDF_ANALYSIS)
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise LecturePipelineError(str(e), status_code=403) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            self._db_set_status(lecture_id, "generating")

            text = _extract_pdf_text(file_bytes)
            if len(text) < _PDF_MIN_TEXT_CHARS:
                raise LecturePipelineError(
                    "This PDF has little extractable text (likely a scan or image-only PDF). "
                    "Upload a JPG/PNG of the page for Diagram/Image analysis (₹199+), "
                    "or use a text-based PDF.",
                    status_code=400,
                )

            required_credits = PDF_ANALYSIS
            self._precheck_balance(user_id, required_credits)

            notes = await generate_notes(text)

            new_balance = deduct_credits(
                user_id=user_id,
                amount=required_credits,
                description="PDF Analysis — Qwen3 text",
                lecture_id=lecture_id,
                action="pdf_analysis",
            )

            r2_paths = self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=text,
                notes=notes,
                source_bytes=file_bytes,
                source_filename=filename or "document.pdf",
                source_content_type="application/pdf",
            )

            self._db_set_status(lecture_id, "done")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE

            return ProcessLectureResponse(
                job_id=job_id,
                lecture_id=lecture_id,
                status=LectureJobStatus.COMPLETE,
                credits_charged=required_credits,
                message=f"PDF processed. New balance: {new_balance}. R2: {r2_paths}",
                transcript=text,
                processedContent=ProcessedNotes(**notes),
                usedTurbo=None,
                usedVisionPlus=None,
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=403) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (QwenGenerationError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            self._fail_job(job_id, str(e))
            self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(f"Unexpected PDF pipeline error: {e}", status_code=500) from e

    def _fail_job(self, job_id: uuid.UUID, error: str) -> None:
        job = self._jobs.get(str(job_id))
        if job:
            job["status"] = LectureJobStatus.FAILED
            job["error"] = error

    def _persist_to_r2_and_db(
        self,
        user_id: str,
        lecture_id: str | None,
        transcript_text: str,
        notes: dict,
        *,
        source_bytes: bytes | None = None,
        source_filename: str | None = None,
        source_content_type: str = "application/octet-stream",
    ) -> dict:
        if not lecture_id:
            return {}

        from app.services.r2_storage_service import (
            FILE_CLEAN_TRANSCRIPT,
            FILE_IMPORTANT_TERMS,
            FILE_KEY_POINTS,
            FILE_NOTES,
            FILE_SUMMARY,
            FILE_TRANSCRIPT,
        )

        db = get_supabase_admin()
        folder = self._r2.lecture_folder_path(user_id, lecture_id)
        paths: dict = {}

        if transcript_text:
            paths["transcript"] = self._r2.upload_text(
                f"{folder}/{FILE_TRANSCRIPT}", transcript_text
            )
            # Cleaner pipeline not separate yet — same text for RAG until
            # Session extras; still store a dedicated clean_transcript path.
            paths["clean_transcript"] = self._r2.upload_text(
                f"{folder}/{FILE_CLEAN_TRANSCRIPT}", transcript_text
            )
        notes_path = self._r2.upload_json(f"{folder}/{FILE_NOTES}", notes)
        summary_path = self._r2.upload_text(
            f"{folder}/{FILE_SUMMARY}", notes.get("shortSummary", "")
        )
        key_points_path = self._r2.upload_json(
            f"{folder}/{FILE_KEY_POINTS}", {"keyPoints": notes.get("keyPoints", [])}
        )
        important_terms_path = self._r2.upload_json(
            f"{folder}/{FILE_IMPORTANT_TERMS}",
            {"importantTerms": notes.get("importantTerms", [])},
        )
        paths["notes"] = notes_path

        if source_bytes:
            source_path = self._r2.source_document_path(
                user_id, lecture_id, source_filename
            )
            paths["source"] = self._r2.upload_bytes(
                source_path, source_bytes, content_type=source_content_type
            )
            existing = (
                db.table("extras")
                .select("id")
                .eq("lecture_id", lecture_id)
                .eq("type", "source_document")
                .limit(1)
                .execute()
            )
            if existing.data:
                db.table("extras").update({"r2_path": paths["source"]}).eq(
                    "id", existing.data[0]["id"]
                ).execute()
            else:
                db.table("extras").insert(
                    {
                        "lecture_id": lecture_id,
                        "type": "source_document",
                        "r2_path": paths["source"],
                    }
                ).execute()

        db.table("lectures").update({"r2_folder_path": folder}).eq("id", lecture_id).execute()
        transcript_row: dict = {"lecture_id": lecture_id}
        if paths.get("transcript"):
            transcript_row["r2_transcript_path"] = paths["transcript"]
        if paths.get("clean_transcript"):
            transcript_row["clean_transcript_path"] = paths["clean_transcript"]
        db.table("transcripts").upsert(transcript_row).execute()
        db.table("notes").upsert(
            {
                "lecture_id": lecture_id,
                "r2_notes_path": notes_path,
                "r2_summary_path": summary_path,
                "r2_key_points_path": key_points_path,
                "r2_important_terms_path": important_terms_path,
            }
        ).execute()

        return paths

    def get_lecture_notes(self, user_id: str, lecture_id: str) -> ProcessedNotes:
        """Reads notes.json from R2 using the path stored in Postgres metadata.

        Postgres holds paths only (PROJECT_CORE_RULES.md); Flutter must not
        expect short_summary/clean_notes columns on the `notes` table.
        """
        db = get_supabase_admin()
        lecture = (
            db.table("lectures")
            .select("id, user_id, status")
            .eq("id", lecture_id)
            .limit(1)
            .execute()
        )
        rows = lecture.data or []
        if not rows:
            raise LecturePipelineError("Lecture not found.", status_code=404)
        row = rows[0]
        if row.get("user_id") != user_id:
            raise LecturePipelineError("Not allowed to view this lecture.", status_code=403)

        notes_result = (
            db.table("notes")
            .select("r2_notes_path")
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        notes_rows = notes_result.data or []
        r2_path = notes_rows[0].get("r2_notes_path") if notes_rows else None
        if not r2_path:
            raise LecturePipelineError(
                "Notes not ready yet — processing may still be running.",
                status_code=404,
            )

        try:
            raw = self._r2.download_json(r2_path)
        except R2StorageError as e:
            raise LecturePipelineError(str(e), status_code=502) from e

        return ProcessedNotes(
            cleanNotes=raw.get("cleanNotes", "") or "",
            keyPoints=raw.get("keyPoints", []) or [],
            shortSummary=raw.get("shortSummary", "") or "",
            importantTerms=raw.get("importantTerms", []) or [],
        )

    async def get_job_status(self, job_id: uuid.UUID, user_id: str) -> LectureJobStatusResponse | None:
        job = self._jobs.get(str(job_id))
        if job is None or job["user_id"] != user_id:
            return None
        return LectureJobStatusResponse(
            job_id=job_id,
            status=job["status"],
            lecture_id=job["lecture_id"],
            error=job["error"],
            created_at=job["created_at"],
        )
