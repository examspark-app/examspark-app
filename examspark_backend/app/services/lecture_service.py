"""Lecture processing pipeline — audio (Session 2) + vision/PDF + YouTube.

Audio: Whisper → Qwen3 text → credits → R2
Image: plan-tier check → Qwen3-VL Flash (+ Plus escalate) → 25 credits → R2
PDF text: plan-tier (Free OK) → extract text → Qwen3 text → 20 credits → R2
YouTube: captions first → else temp audio + Whisper → Qwen3 notes → R2
Credits: Record/Audio = 1 credit/min (actual length, max 180). No permanent audio.
Scanned PDF (little text): clear 400 — upload JPG/PNG instead (no silent VL misroute).

Credits deducted only after AI succeeds (Rule 1). Tier check before credits (Rule 6).
"""
from __future__ import annotations

import asyncio
import io
import logging
import uuid
from datetime import datetime, timezone

from app.constants.credit_costs import (
    DIAGRAM_IMAGE,
    FIVE_MIN_REVISION,
    FLASHCARDS,
    IMPORTANT_QUESTIONS,
    MIND_MAP,
    PDF_ANALYSIS,
    QUIZ_20_MCQ,
    REVISION_NOTES,
    YOUTUBE_MAX_MINUTES,
    record_credits_for_duration_minutes,
    youtube_credits_for_duration_minutes,
)
from app.services.audio_chunk_service import (
    AudioChunkError,
    resolve_record_duration_minutes,
    should_chunk_audio,
    split_audio_into_chunks,
    stitch_transcript_parts,
)
from app.models.lecture import (
    FlashcardItem,
    FlashcardsPayload,
    ImportantQuestionItem,
    ImportantQuestionsPayload,
    LectureJobStatus,
    LectureJobStatusResponse,
    LectureSourceType,
    MindMapNode,
    MindMapPayload,
    ProcessedNotes,
    ProcessLectureRequest,
    ProcessLectureResponse,
    QuizPayload,
    QuizQuestionItem,
    RevisionPayload,
)
from app.models.visual_payload import parse_visual_payload
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.lecture_dedupe import (
    DUPLICATE_USER_MESSAGE,
    find_done_by_content_hash,
    find_done_by_youtube_video_id,
    find_near_duplicate_transcript_lecture,
    mark_lecture_as_duplicate,
    sha256_bytes,
    stamp_lecture_identity,
)
from app.services.pipeline_timing import PipelineTimer
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.qwen_service import (
    QwenGenerationError,
    generate_five_min_revision,
    generate_flashcards,
    generate_important_questions,
    generate_mind_map,
    generate_notes,
    generate_quiz_mcq,
    generate_revision_sheet,
)
from app.services.qwen_vision_service import QwenVisionError, analyze_image
from app.services.rag_index_service import ensure_lecture_indexed
from app.services.r2_storage_service import R2StorageError, R2StorageService
from app.services.supabase_admin import get_supabase_admin
from app.services.whisper_service import (
    NO_SPEECH_USER_MESSAGE,
    TranscriptionResult,
    WhisperTranscriptionError,
    transcript_too_short,
    transcribe_audio,
)
from app.services.youtube_audio_service import YoutubeAudioError, download_youtube_audio_bytes
from app.services.youtube_transcript_service import (
    YoutubeTranscriptError,
    extract_video_id,
    fetch_youtube_captions,
    fetch_youtube_title,
)

_PDF_MIN_TEXT_CHARS = 200

logger = logging.getLogger(__name__)


def _exc_detail(exc: BaseException) -> str:
    """Always return a non-empty error string for UI / DB error_message."""
    text = str(exc).strip()
    if text:
        return text
    return repr(exc) or type(exc).__name__


async def _eager_rag_index_after_persist(user_id: str, lecture_id: str | None) -> None:
    """Warm RAG index after notes persist so first Ask AI is fast.

    Best-effort only — never block/delay lecture completion. Any failure or
    slowness is swallowed; first Ask AI lazily indexes if this did not finish.
    """
    if not lecture_id:
        return
    try:
        await ensure_lecture_indexed(user_id, lecture_id)
    except Exception as e:  # noqa: BLE001
        logger.warning("Eager RAG index failed (safe to ignore): %s", e)


def _schedule_eager_rag_index(user_id: str, lecture_id: str | None) -> None:
    """Fire-and-forget RAG warm-up. Runs after 'done' so it never blocks results."""
    if not lecture_id:
        return
    try:
        loop = asyncio.get_running_loop()
        task = loop.create_task(_eager_rag_index_after_persist(user_id, lecture_id))
        # Keep a reference so the task is not garbage-collected mid-run.
        _BACKGROUND_INDEX_TASKS.add(task)
        task.add_done_callback(_BACKGROUND_INDEX_TASKS.discard)
    except RuntimeError as e:  # noqa: BLE001
        logger.warning("Could not schedule eager RAG index: %s", e)


_BACKGROUND_INDEX_TASKS: set = set()


async def _background_r2_then_rag(
    service: "LectureService",
    *,
    user_id: str,
    lecture_id: str | None,
    transcript_text: str,
    notes: dict,
    source_bytes: bytes | None = None,
    source_filename: str | None = None,
    source_content_type: str = "application/octet-stream",
) -> None:
    """P1: R2 + path rows after notes are already in Supabase and status=done."""
    if not lecture_id:
        return
    try:
        await asyncio.to_thread(
            service._persist_r2_transcript_sync,
            user_id,
            lecture_id,
            transcript_text,
            source_bytes=source_bytes,
            source_filename=source_filename,
            source_content_type=source_content_type,
        )
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "Background R2 after notes failed (notes still in Supabase): %s", e
        )
        return
    await _eager_rag_index_after_persist(user_id, lecture_id)


def _schedule_r2_then_rag(
    service: "LectureService",
    *,
    user_id: str,
    lecture_id: str | None,
    transcript_text: str,
    notes: dict,
    source_bytes: bytes | None = None,
    source_filename: str | None = None,
    source_content_type: str = "application/octet-stream",
) -> None:
    if not lecture_id:
        return
    try:
        loop = asyncio.get_running_loop()
        task = loop.create_task(
            _background_r2_then_rag(
                service,
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=transcript_text,
                notes=notes,
                source_bytes=source_bytes,
                source_filename=source_filename,
                source_content_type=source_content_type,
            )
        )
        _BACKGROUND_INDEX_TASKS.add(task)
        task.add_done_callback(_BACKGROUND_INDEX_TASKS.discard)
    except RuntimeError as e:  # noqa: BLE001
        logger.warning("Could not schedule background R2+RAG: %s", e)


def _update_lecture_title(lecture_id: str | None, title: str | None) -> None:
    if not lecture_id:
        return
    t = (title or "").strip()[:120]
    if not t:
        return
    try:
        get_supabase_admin().table("lectures").update({"title": t}).eq(
            "id", lecture_id
        ).execute()
    except Exception as e:  # noqa: BLE001
        logger.warning("update lecture title failed: %s", e)


def _visual_from_notes_dict(notes: dict) -> dict | None:
    raw = notes.get("visualPayload") or notes.get("visual_payload")
    if isinstance(raw, dict):
        return raw
    return None


def _processed_notes_from_row(notes_row: dict) -> ProcessedNotes | None:
    clean_notes = (notes_row.get("clean_notes") or "").strip()
    short_summary = (notes_row.get("short_summary") or "").strip()
    key_points = notes_row.get("key_points") or []
    important_terms = notes_row.get("important_terms") or []
    visual = parse_visual_payload(notes_row.get("visual_payload_json"))
    if not (clean_notes or short_summary or key_points or important_terms or visual):
        return None
    return ProcessedNotes(
        cleanNotes=clean_notes,
        keyPoints=key_points,
        shortSummary=short_summary,
        importantTerms=important_terms,
        visualPayload=visual,
    )


class LecturePipelineError(Exception):
    """Wraps any pipeline failure with an HTTP-status-appropriate hint."""

    def __init__(
        self,
        message: str,
        status_code: int = 500,
        *,
        detail: dict | None = None,
    ):
        super().__init__(message)
        self.status_code = status_code
        self.detail = detail


def _locked(err: FeatureLockedError) -> LecturePipelineError:
    return LecturePipelineError(
        str(err),
        status_code=403,
        detail=feature_locked_payload(err),
    )


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
        youtube_url: str | None = None,
    ) -> ProcessLectureResponse:
        job_id = uuid.uuid4()
        self._jobs[str(job_id)] = {
            "user_id": user_id,
            "status": LectureJobStatus.QUEUED,
            "lecture_id": lecture_id,
            "created_at": datetime.now(timezone.utc),
            "error": None,
        }

        source = request.source_type
        if source == LectureSourceType.YOUTUBE_LINK:
            return await self._run_youtube_pipeline(
                job_id, user_id, youtube_url or "", lecture_id
            )

        if not file_bytes:
            raise LecturePipelineError("No file received.", status_code=400)

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

    async def _db_set_status(
        self, lecture_id: str | None, status: str, error_message: str | None = None
    ) -> None:
        """Offload sync Supabase write so the event loop stays responsive."""
        await asyncio.to_thread(
            self._db_set_status_sync, lecture_id, status, error_message
        )

    def _db_set_status_sync(
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

    async def _precheck_balance(self, user_id: str, required_credits: int) -> None:
        await asyncio.to_thread(self._precheck_balance_sync, user_id, required_credits)

    def _precheck_balance_sync(self, user_id: str, required_credits: int) -> None:
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
        timer = PipelineTimer("audio", lecture_id=lecture_id)
        timer.set_meta("upload_bytes", len(audio_bytes or b""))
        try:
            with timer.stage("plan_gate"):
                await asyncio.to_thread(
                    require_feature_unlocked, user_id, GatedFeature.RECORD_LECTURE
                )
        except FeatureLockedError as e:
            timer.log_failure(e)
            self._fail_job(job_id, str(e))
            raise _locked(e) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.TRANSCRIBING
            await self._db_set_status(lecture_id, "transcribing")

            # Layer 1 — exact file hash (before any AI call).
            with timer.stage("dedupe_hash"):
                content_hash = sha256_bytes(audio_bytes)
                existing = await asyncio.to_thread(
                    find_done_by_content_hash, user_id, content_hash
                )
            if existing:
                timer.log_summary()
                return await self._complete_as_duplicate(
                    job_id=job_id,
                    user_id=user_id,
                    new_lecture_id=lecture_id,
                    original=existing,
                    content_hash=content_hash,
                    layer="hash",
                )

            try:
                with timer.stage("duration_probe"):
                    duration_minutes = await asyncio.to_thread(
                        resolve_record_duration_minutes,
                        client_minutes=request.duration_minutes,
                        audio_bytes=audio_bytes,
                        filename=filename or "audio.webm",
                    )
            except AudioChunkError as e:
                raise LecturePipelineError(str(e), status_code=400) from e

            required_credits = record_credits_for_duration_minutes(duration_minutes)
            with timer.stage("credit_precheck"):
                await self._precheck_balance(user_id, required_credits)

            try:
                with timer.stage("whisper"):
                    transcription = await self._transcribe_record_or_upload(
                        audio_bytes, filename or "audio.webm"
                    )
            except AudioChunkError as e:
                raise LecturePipelineError(str(e), status_code=503) from e

            # Silence / no-mic: Whisper often hallucinates; never charge or invent notes.
            if transcription.likely_no_speech or transcript_too_short(transcription.text):
                raise LecturePipelineError(NO_SPEECH_USER_MESSAGE, status_code=400)

            # Layer 2 — near-identical transcript vs this student's own RAG.
            with timer.stage("dedupe_transcript"):
                near = await find_near_duplicate_transcript_lecture(
                    user_id,
                    transcription.text,
                    exclude_lecture_id=lecture_id,
                )
            if near:
                # Whisper API may already have run; student is not charged again
                # for notes (bundled Record credits). No RAG re-index.
                timer.log_summary()
                return await self._complete_as_duplicate(
                    job_id=job_id,
                    user_id=user_id,
                    new_lecture_id=lecture_id,
                    original=near,
                    content_hash=content_hash,
                    layer="transcript",
                )

            await self._db_set_status(lecture_id, "generating")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            with timer.stage("openrouter_notes"):
                notes = await generate_notes(
                    transcription.text, duration_minutes=duration_minutes
                )

            with timer.stage("deduct_credits"):
                new_balance = await asyncio.to_thread(
                    deduct_credits,
                    user_id=user_id,
                    amount=required_credits,
                    description=(
                        f"Recording ({duration_minutes} min) — transcription + notes"
                    ),
                    lecture_id=lecture_id,
                    action="audio_transcription",
                )

            # Honest UX: Finalizing = notes in Supabase (student can open).
            await self._db_set_status(lecture_id, "almost_done")
            with timer.stage("database_notes"):
                await asyncio.to_thread(
                    self._persist_notes_supabase_sync,
                    user_id,
                    lecture_id,
                    notes,
                )
            await asyncio.to_thread(
                stamp_lecture_identity, lecture_id, content_hash=content_hash
            )

            await self._db_set_status(lecture_id, "done")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE
            timer.log_summary()
            # P1: R2 transcript + RAG after done — do not block Notes Workspace.
            _schedule_r2_then_rag(
                self,
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=transcription.text,
                notes=notes,
            )

            return ProcessLectureResponse(
                job_id=job_id,
                lecture_id=lecture_id,
                status=LectureJobStatus.COMPLETE,
                credits_charged=required_credits,
                message=f"Processed. New balance: {new_balance}. Notes ready; R2/RAG in background.",
                transcript=transcription.text,
                processedContent=ProcessedNotes(**notes),
                usedTurbo=transcription.used_turbo,
                usedVisionPlus=None,
            )
        except FeatureLockedError as e:
            timer.log_failure(e)
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            timer.log_failure(e)
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (WhisperTranscriptionError, QwenGenerationError, R2StorageError) as e:
            timer.log_failure(e)
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            timer.log_failure(e)
            self._fail_job(job_id, "pipeline error")
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            timer.log_failure(e)
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(f"Unexpected pipeline error: {e}", status_code=500) from e

    async def _transcribe_record_or_upload(
        self, audio_bytes: bytes, filename: str
    ) -> TranscriptionResult:
        """Whisper for Record / audio_upload — chunk long files, single-call otherwise."""
        need_chunks = await asyncio.to_thread(should_chunk_audio, audio_bytes, filename)
        if not need_chunks:
            return await transcribe_audio(audio_bytes, filename)

        chunks = await asyncio.to_thread(split_audio_into_chunks, audio_bytes, filename)
        total = len(chunks)
        logger.info(
            "Record/upload Whisper: %s chunks for %s bytes",
            total,
            len(audio_bytes),
        )
        parts: list[str] = []
        used_turbo_all = True
        low_conf_any = False
        notes: list[str] = [f"server_chunks={total}"]
        for i, (chunk_bytes, chunk_name) in enumerate(chunks, start=1):
            logger.info(
                "pipeline_timing label=whisper_chunk chunk=%s/%s bytes=%s",
                i,
                total,
                len(chunk_bytes),
            )
            result = await transcribe_audio(chunk_bytes, chunk_name)
            if (result.text or "").strip():
                parts.append(result.text.strip())
            used_turbo_all = used_turbo_all and result.used_turbo
            low_conf_any = low_conf_any or result.low_confidence
            notes.extend(result.notes)

        text = stitch_transcript_parts(parts)
        return TranscriptionResult(
            text=text,
            used_turbo=used_turbo_all,
            low_confidence=low_conf_any,
            notes=notes,
            # Per-chunk silence must not fail a long lecture; final length guard below.
            likely_no_speech=transcript_too_short(text),
        )

    async def _run_vision_pipeline(
        self,
        job_id: uuid.UUID,
        user_id: str,
        filename: str | None,
        image_bytes: bytes,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.DIAGRAM_ANALYSIS
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise _locked(e) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            await self._db_set_status(lecture_id, "generating")

            required_credits = DIAGRAM_IMAGE
            await self._precheck_balance(user_id, required_credits)

            vision = await analyze_image(image_bytes, filename=filename)
            notes = vision.notes

            new_balance = await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=required_credits,
                description=(
                    f"Diagram/Image — Qwen3-VL-{'Plus' if vision.used_plus else 'Flash'}"
                ),
                lecture_id=lecture_id,
                action="diagram_image",
            )

            r2_paths = await self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text="",
                notes=notes,
                source_bytes=image_bytes,
                source_filename=filename,
                source_content_type=_guess_image_content_type(filename),
            )

            await self._db_set_status(lecture_id, "done")
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
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (QwenVisionError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
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
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.PDF_ANALYSIS
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise _locked(e) from e

        try:
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            await self._db_set_status(lecture_id, "generating")

            text = await asyncio.to_thread(_extract_pdf_text, file_bytes)
            if len(text) < _PDF_MIN_TEXT_CHARS:
                raise LecturePipelineError(
                    "This PDF has little extractable text (likely a scan or image-only PDF). "
                    "Upload a JPG/PNG of the page for Diagram/Image analysis (₹199+), "
                    "or use a text-based PDF.",
                    status_code=400,
                )

            required_credits = PDF_ANALYSIS
            await self._precheck_balance(user_id, required_credits)

            notes = await generate_notes(text)

            new_balance = await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=required_credits,
                description="PDF Analysis — Qwen3 text",
                lecture_id=lecture_id,
                action="pdf_analysis",
            )

            r2_paths = await self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=text,
                notes=notes,
                source_bytes=file_bytes,
                source_filename=filename or "document.pdf",
                source_content_type="application/pdf",
            )

            await self._db_set_status(lecture_id, "done")
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
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (QwenGenerationError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(f"Unexpected PDF pipeline error: {e}", status_code=500) from e

    async def _run_youtube_pipeline(
        self,
        job_id: uuid.UUID,
        user_id: str,
        youtube_url: str,
        lecture_id: str | None,
    ) -> ProcessLectureResponse:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.YOUTUBE_LINK
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            raise _locked(e) from e

        try:
            if not (youtube_url or "").strip():
                raise LecturePipelineError("youtube_url is required.", status_code=400)

            self._jobs[str(job_id)]["status"] = LectureJobStatus.TRANSCRIBING
            await self._db_set_status(lecture_id, "transcribing")

            url = youtube_url.strip()
            try:
                video_id = extract_video_id(url)
            except YoutubeTranscriptError as e:
                raise LecturePipelineError(str(e), status_code=400) from e

            # Layer 1 — same YouTube video ID for this student (before fetch/AI).
            existing_yt = await asyncio.to_thread(
                find_done_by_youtube_video_id, user_id, video_id
            )
            if existing_yt:
                logger.info(
                    "Layer1 YouTube dedupe HIT video_id=%s user_id=%s original_lecture_id=%s",
                    video_id,
                    user_id,
                    existing_yt.get("id"),
                )
                return await self._complete_as_duplicate(
                    job_id=job_id,
                    user_id=user_id,
                    new_lecture_id=lecture_id,
                    original=existing_yt,
                    youtube_video_id=video_id,
                    layer="youtube",
                )
            logger.info(
                "Layer1 YouTube dedupe MISS video_id=%s user_id=%s",
                video_id,
                user_id,
            )

            transcript_text = ""
            duration_minutes = 1
            transcript_source = "captions"
            used_turbo: bool | None = None

            try:
                captions = await asyncio.to_thread(fetch_youtube_captions, url)
                transcript_text = captions.text
                duration_minutes = captions.duration_minutes
                transcript_source = "captions"
            except YoutubeTranscriptError as cap_err:
                # Fallback: temp audio → Whisper (no permanent storage).
                # Hard cap so YouTube 403 / stall does not hang the UI ~5 minutes.
                logger.info(
                    "YouTube captions unavailable (%s); trying Whisper fallback",
                    cap_err,
                )
                try:
                    audio_bytes, duration_minutes, audio_name = await asyncio.wait_for(
                        asyncio.to_thread(download_youtube_audio_bytes, url),
                        timeout=180.0,
                    )
                    transcription = await asyncio.wait_for(
                        transcribe_audio(
                            audio_bytes,
                            audio_name,
                            allow_non_turbo_fallback=False,
                        ),
                        timeout=180.0,
                    )
                    transcript_text = (transcription.text or "").strip()
                    used_turbo = transcription.used_turbo
                    transcript_source = "whisper"
                    # Drop reference so GC can free memory sooner
                    del audio_bytes
                except asyncio.TimeoutError as te:
                    raise LecturePipelineError(
                        "YouTube audio download timed out. Please try again — "
                        "non-CC videos use Whisper and can take a bit longer on slow networks.",
                        status_code=400,
                    ) from te
                except (YoutubeAudioError, WhisperTranscriptionError) as wh_err:
                    raise LecturePipelineError(
                        f"YouTube notes failed after captions + audio path: {wh_err}",
                        status_code=400,
                    ) from wh_err

            if len(transcript_text) < 40:
                raise LecturePipelineError(
                    "Transcript was too short to make study notes. Try another video.",
                    status_code=400,
                )

            yt_title = await asyncio.to_thread(fetch_youtube_title, url)
            if yt_title:
                await asyncio.to_thread(_update_lecture_title, lecture_id, yt_title)

            if duration_minutes > YOUTUBE_MAX_MINUTES:
                raise LecturePipelineError(
                    f"Video is about {duration_minutes} minutes — "
                    f"YouTube Notes supports up to {YOUTUBE_MAX_MINUTES} minutes. "
                    "No credits were charged.",
                    status_code=400,
                )

            # Layer 2 — near-identical transcript (rare for YouTube if Layer 1 missed).
            near = await find_near_duplicate_transcript_lecture(
                user_id,
                transcript_text,
                exclude_lecture_id=lecture_id,
            )
            if near:
                return await self._complete_as_duplicate(
                    job_id=job_id,
                    user_id=user_id,
                    new_lecture_id=lecture_id,
                    original=near,
                    youtube_video_id=video_id,
                    layer="transcript",
                )

            required_credits = youtube_credits_for_duration_minutes(duration_minutes)
            await self._precheck_balance(user_id, required_credits)

            await self._db_set_status(lecture_id, "generating")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.GENERATING_NOTES
            notes = await generate_notes(transcript_text)

            path_label = (
                "captions"
                if transcript_source == "captions"
                else "Whisper Turbo"
            )
            new_balance = await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=required_credits,
                description=(
                    f"YouTube Link → Notes ({duration_minutes} min, {path_label}) "
                    f"— Qwen3 text"
                ),
                lecture_id=lecture_id,
                action="youtube_link",
            )

            r2_paths = await self._persist_to_r2_and_db(
                user_id=user_id,
                lecture_id=lecture_id,
                transcript_text=transcript_text,
                notes=notes,
            )
            await asyncio.to_thread(
                stamp_lecture_identity, lecture_id, youtube_video_id=video_id
            )

            await self._db_set_status(lecture_id, "done")
            self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE
            # RAG warm-up in background — must NOT delay the "done" result.
            _schedule_eager_rag_index(user_id, lecture_id)

            return ProcessLectureResponse(
                job_id=job_id,
                lecture_id=lecture_id,
                status=LectureJobStatus.COMPLETE,
                credits_charged=required_credits,
                message=(
                    f"YouTube processed ({duration_minutes} min via {transcript_source}, "
                    f"{required_credits} credits). New balance: {new_balance}. R2: {r2_paths}"
                ),
                transcript=transcript_text,
                processedContent=ProcessedNotes(**notes),
                usedTurbo=used_turbo,
                usedVisionPlus=None,
            )
        except FeatureLockedError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise _locked(e) from e
        except YoutubeTranscriptError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=400) from e
        except YoutubeAudioError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=400) from e
        except WhisperTranscriptionError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except InsufficientCreditsError as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=402) from e
        except (QwenGenerationError, R2StorageError) as e:
            self._fail_job(job_id, str(e))
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError as e:
            self._fail_job(job_id, "pipeline error")
            await self._db_set_status(lecture_id, "error", error_message=str(e))
            raise
        except Exception as e:  # noqa: BLE001
            detail = _exc_detail(e)
            self._fail_job(job_id, detail)
            await self._db_set_status(lecture_id, "error", error_message=detail)
            raise LecturePipelineError(
                f"Unexpected YouTube pipeline error: {detail}", status_code=500
            ) from e

    async def _complete_as_duplicate(
        self,
        *,
        job_id: uuid.UUID,
        user_id: str,
        new_lecture_id: str | None,
        original: dict,
        content_hash: str | None = None,
        youtube_video_id: str | None = None,
        layer: str,
    ) -> ProcessLectureResponse:
        """Reuse existing notes — offload sync DB/R2 so the loop stays free."""

        def _run() -> ProcessLectureResponse:
            return self._complete_as_duplicate_sync(
                job_id=job_id,
                user_id=user_id,
                new_lecture_id=new_lecture_id,
                original=original,
                content_hash=content_hash,
                youtube_video_id=youtube_video_id,
                layer=layer,
            )

        return await asyncio.to_thread(_run)

    def _complete_as_duplicate_sync(
        self,
        *,
        job_id: uuid.UUID,
        user_id: str,
        new_lecture_id: str | None,
        original: dict,
        content_hash: str | None = None,
        youtube_video_id: str | None = None,
        layer: str,
    ) -> ProcessLectureResponse:
        """Reuse existing notes for this student — 0 credits, no RAG pollute."""
        original_id = str(original["id"])
        if new_lecture_id:
            mark_lecture_as_duplicate(
                new_lecture_id=new_lecture_id,
                original_lecture_id=original_id,
                content_hash=content_hash,
                youtube_video_id=youtube_video_id,
            )
            self._mirror_notes_row(new_lecture_id, original_id)

        notes = self.get_lecture_notes(user_id, original_id)
        transcript_text: str | None = None
        try:
            tp = self.get_lecture_transcript(user_id, original_id)
            transcript_text = (tp.transcript or "").strip() or None
        except Exception:  # noqa: BLE001
            transcript_text = None

        self._jobs[str(job_id)]["status"] = LectureJobStatus.COMPLETE
        reused = uuid.UUID(original_id)
        return ProcessLectureResponse(
            job_id=job_id,
            lecture_id=reused,
            status=LectureJobStatus.COMPLETE,
            credits_charged=0,
            message=DUPLICATE_USER_MESSAGE,
            transcript=transcript_text,
            processedContent=notes,
            usedTurbo=None,
            usedVisionPlus=None,
            is_duplicate=True,
            reused_lecture_id=reused,
            duplicate_layer=layer,
        )

    def _mirror_notes_row(self, new_lecture_id: str, original_lecture_id: str) -> None:
        """Copy short notes onto the duplicate row so either id can open Library."""
        try:
            db = get_supabase_admin()
            res = (
                db.table("notes")
                .select(
                    "clean_notes, short_summary, key_points, important_terms, "
                    "visual_payload_json, r2_notes_path"
                )
                .eq("lecture_id", original_lecture_id)
                .limit(1)
                .execute()
            )
            rows = list(res.data or [])
            if not rows:
                return
            row = dict(rows[0])
            row["lecture_id"] = new_lecture_id
            db.table("notes").upsert(row, on_conflict="lecture_id").execute()
        except Exception as e:  # noqa: BLE001
            logging.getLogger(__name__).warning("mirror notes for duplicate failed: %s", e)

    def _fail_job(self, job_id: uuid.UUID, error: str) -> None:
        job = self._jobs.get(str(job_id))
        if job:
            job["status"] = LectureJobStatus.FAILED
            job["error"] = error

    async def _persist_to_r2_and_db(
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
        """Offload boto3 + sync Supabase so one stuck R2 call cannot freeze health."""

        def _run() -> dict:
            return self._persist_to_r2_and_db_sync(
                user_id,
                lecture_id,
                transcript_text,
                notes,
                source_bytes=source_bytes,
                source_filename=source_filename,
                source_content_type=source_content_type,
            )

        return await asyncio.to_thread(_run)

    def _persist_notes_supabase_sync(
        self,
        user_id: str,
        lecture_id: str | None,
        notes: dict,
    ) -> None:
        """P1 fast path — notes in Supabase so Workspace can open before R2."""
        if not lecture_id:
            return
        db = get_supabase_admin()
        folder = self._r2.lecture_folder_path(user_id, lecture_id)
        db.table("lectures").update({"r2_folder_path": folder}).eq(
            "id", lecture_id
        ).execute()
        db.table("transcripts").upsert(
            {"lecture_id": lecture_id},
            on_conflict="lecture_id",
        ).execute()
        db.table("notes").upsert(
            {
                "lecture_id": lecture_id,
                "clean_notes": notes.get("cleanNotes", "") or "",
                "short_summary": notes.get("shortSummary", "") or "",
                "key_points": notes.get("keyPoints", []) or [],
                "important_terms": notes.get("importantTerms", []) or [],
                "visual_payload_json": _visual_from_notes_dict(notes),
            },
            on_conflict="lecture_id",
        ).execute()

    def _persist_r2_transcript_sync(
        self,
        user_id: str,
        lecture_id: str | None,
        transcript_text: str,
        *,
        source_bytes: bytes | None = None,
        source_filename: str | None = None,
        source_content_type: str = "application/octet-stream",
    ) -> dict:
        """Upload transcript (and optional source) to R2; patch path columns."""
        if not lecture_id:
            return {}

        from app.services.r2_storage_service import FILE_TRANSCRIPT

        db = get_supabase_admin()
        folder = self._r2.lecture_folder_path(user_id, lecture_id)
        paths: dict = {}

        if transcript_text:
            tr_path = self._r2.upload_text(
                f"{folder}/{FILE_TRANSCRIPT}", transcript_text
            )
            paths["transcript"] = tr_path
            paths["clean_transcript"] = tr_path

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

        db.table("lectures").update({"r2_folder_path": folder}).eq(
            "id", lecture_id
        ).execute()
        transcript_row: dict = {"lecture_id": lecture_id}
        if paths.get("transcript"):
            transcript_row["r2_transcript_path"] = paths["transcript"]
        if paths.get("clean_transcript"):
            transcript_row["clean_transcript_path"] = paths["clean_transcript"]
        db.table("transcripts").upsert(
            transcript_row,
            on_conflict="lecture_id",
        ).execute()
        return paths

    def _persist_to_r2_and_db_sync(
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
        """Full sync persist (PDF/vision/YouTube). Notes first, then R2."""
        if not lecture_id:
            return {}
        self._persist_notes_supabase_sync(user_id, lecture_id, notes)
        return self._persist_r2_transcript_sync(
            user_id,
            lecture_id,
            transcript_text,
            source_bytes=source_bytes,
            source_filename=source_filename,
            source_content_type=source_content_type,
        )

    def get_lecture_notes(self, user_id: str, lecture_id: str) -> ProcessedNotes:
        """Reads short notes from Supabase first; R2 only as last resort (timed)."""
        import concurrent.futures

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
            .select(
                "clean_notes, short_summary, key_points, important_terms, "
                "visual_payload_json, r2_notes_path"
            )
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        notes_rows = notes_result.data or []
        if not notes_rows:
            # Soft empty — UI shows "No notes yet" instead of hard error.
            return ProcessedNotes()
        notes_row = notes_rows[0]
        from_supabase = _processed_notes_from_row(notes_row)
        if from_supabase is not None:
            return from_supabase

        r2_path = notes_row.get("r2_notes_path")
        paths: list[str] = []
        if r2_path:
            paths.append(r2_path)
        # Fallback: lecture folder notes.json (older rows / path mismatch).
        lecture_full = (
            db.table("lectures")
            .select("r2_folder_path")
            .eq("id", lecture_id)
            .limit(1)
            .execute()
        )
        folder = ((lecture_full.data or [{}])[0].get("r2_folder_path") or "").rstrip("/")
        if folder:
            from app.services.r2_storage_service import FILE_NOTES

            candidate = f"{folder}/{FILE_NOTES}"
            if candidate not in paths:
                paths.append(candidate)

        if not paths:
            # Empty row, no R2 — not a hard crash for the UI.
            return ProcessedNotes()

        last_err: Exception | None = None
        for path in paths:
            try:
                with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                    fut = pool.submit(self._r2.download_json, path)
                    raw = fut.result(timeout=15)
                if not isinstance(raw, dict):
                    continue
                clean = (raw.get("cleanNotes") or raw.get("clean_notes") or "").strip()
                summary = (raw.get("shortSummary") or raw.get("short_summary") or "").strip()
                key_points = raw.get("keyPoints") or raw.get("key_points") or []
                important_terms = (
                    raw.get("importantTerms") or raw.get("important_terms") or []
                )
                vp_raw = raw.get("visualPayload") or raw.get("visual_payload")
                if not (clean or summary or key_points or important_terms or vp_raw):
                    continue
                return ProcessedNotes(
                    cleanNotes=clean,
                    keyPoints=key_points if isinstance(key_points, list) else [],
                    shortSummary=summary,
                    importantTerms=important_terms
                    if isinstance(important_terms, list)
                    else [],
                    visualPayload=parse_visual_payload(
                        vp_raw if isinstance(vp_raw, dict) else None
                    ),
                )
            except concurrent.futures.TimeoutError as e:
                last_err = e
            except R2StorageError as e:
                last_err = e

        if last_err is not None:
            if isinstance(last_err, concurrent.futures.TimeoutError):
                raise LecturePipelineError(
                    "Notes file is slow to load. Try again in a moment.",
                    status_code=504,
                ) from last_err
            raise LecturePipelineError(str(last_err), status_code=502) from last_err

        return ProcessedNotes()

    def get_lecture_transcript(self, user_id: str, lecture_id: str) -> "TranscriptPayload":
        """Read-only clean transcript from R2 — free, no AI, no credits."""
        from app.models.lecture import TranscriptPayload
        from app.services.r2_storage_service import FILE_CLEAN_TRANSCRIPT, FILE_TRANSCRIPT

        row = self._assert_lecture_owner(user_id, lecture_id)
        db = get_supabase_admin()
        transcript_result = (
            db.table("transcripts")
            .select("r2_transcript_path, clean_transcript_path")
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        t_rows = transcript_result.data or []
        paths: list[str] = []
        if t_rows:
            clean = t_rows[0].get("clean_transcript_path")
            raw = t_rows[0].get("r2_transcript_path")
            if clean:
                paths.append(clean)
            if raw and raw not in paths:
                paths.append(raw)

        folder = (row.get("r2_folder_path") or "").rstrip("/")
        if folder:
            for name in (FILE_CLEAN_TRANSCRIPT, FILE_TRANSCRIPT):
                candidate = f"{folder}/{name}"
                if candidate not in paths:
                    paths.append(candidate)

        text = ""
        for path in paths:
            try:
                text = self._r2.download_text(path).strip()
                if text:
                    break
            except R2StorageError:
                continue

        words = len(text.split()) if text else 0
        return TranscriptPayload(
            transcript=text,
            wordCount=words,
            available=bool(text),
        )

    def _assert_lecture_owner(self, user_id: str, lecture_id: str) -> dict:
        db = get_supabase_admin()
        lecture = (
            db.table("lectures")
            .select("id, user_id, status, r2_folder_path")
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
        return row

    def _load_lecture_source_text(self, user_id: str, lecture_id: str) -> str:
        """Notes-first source for extras generation."""
        from app.services.r2_storage_service import FILE_NOTES, FILE_TRANSCRIPT

        row = self._assert_lecture_owner(user_id, lecture_id)
        db = get_supabase_admin()
        folder = row.get("r2_folder_path") or self._r2.lecture_folder_path(
            user_id, lecture_id
        )

        notes_result = (
            db.table("notes")
            .select(
                "clean_notes, short_summary, key_points, important_terms, r2_notes_path"
            )
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        notes_rows = notes_result.data or []
        if notes_rows:
            notes_row = notes_rows[0]
            parts: list[str] = []
            clean = (notes_row.get("clean_notes") or "").strip()
            if clean:
                parts.append(clean)
            short_summary = (notes_row.get("short_summary") or "").strip()
            if short_summary:
                parts.append(short_summary)
            for kp in notes_row.get("key_points") or []:
                parts.append(str(kp))
            joined = "\n".join(p for p in parts if p).strip()
            if len(joined) >= 80:
                return joined
        r2_notes = notes_rows[0].get("r2_notes_path") if notes_rows else None
        if r2_notes:
            try:
                raw = self._r2.download_json(r2_notes)
                parts: list[str] = []
                clean = (raw.get("cleanNotes") or "").strip()
                if clean:
                    parts.append(clean)
                for kp in raw.get("keyPoints") or []:
                    parts.append(str(kp))
                joined = "\n".join(parts).strip()
                if len(joined) >= 80:
                    return joined
            except R2StorageError:
                pass

        transcript_result = (
            db.table("transcripts")
            .select("r2_transcript_path")
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        t_rows = transcript_result.data or []
        r2_transcript = t_rows[0].get("r2_transcript_path") if t_rows else None
        if r2_transcript:
            try:
                text = self._r2.download_text(r2_transcript).strip()
                if len(text) >= 80:
                    return text
            except R2StorageError:
                pass

        # Fallback: try canonical paths even if metadata row missing
        for path in (
            f"{folder}/{FILE_NOTES}",
            f"{folder}/{FILE_TRANSCRIPT}",
        ):
            try:
                if path.endswith(".json"):
                    raw = self._r2.download_json(path)
                    clean = (raw.get("cleanNotes") or "").strip()
                    if len(clean) >= 80:
                        return clean
                else:
                    text = self._r2.download_text(path).strip()
                    if len(text) >= 80:
                        return text
            except R2StorageError:
                continue

        raise LecturePipelineError(
            "Lecture notes are not ready yet — finish processing before generating extras.",
            status_code=400,
        )

    def _upsert_extra(
        self,
        lecture_id: str,
        extra_type: str,
        *,
        payload_json: dict | None = None,
        r2_path: str | None = None,
    ) -> None:
        update_data: dict = {}
        if payload_json is not None:
            update_data["payload_json"] = payload_json
        if r2_path is not None:
            update_data["r2_path"] = r2_path
        if not update_data:
            return

        db = get_supabase_admin()
        existing = (
            db.table("extras")
            .select("id")
            .eq("lecture_id", lecture_id)
            .eq("type", extra_type)
            .limit(1)
            .execute()
        )
        if existing.data:
            db.table("extras").update(update_data).eq(
                "id", existing.data[0]["id"]
            ).execute()
        else:
            db.table("extras").insert(
                {
                    "lecture_id": lecture_id,
                    "type": extra_type,
                    **update_data,
                }
            ).execute()

    def _get_extra_json(
        self, user_id: str, lecture_id: str, extra_type: str
    ) -> dict | None:
        self._assert_lecture_owner(user_id, lecture_id)
        db = get_supabase_admin()
        row = (
            db.table("extras")
            .select("id, payload_json, r2_path")
            .eq("lecture_id", lecture_id)
            .eq("type", extra_type)
            .limit(1)
            .execute()
        )
        data = row.data or []
        if not data:
            return None

        record = data[0]
        payload = record.get("payload_json")
        if payload:
            if isinstance(payload, dict):
                return payload
            return None

        r2_path = record.get("r2_path")
        if not r2_path:
            return None
        try:
            downloaded = self._r2.download_json(r2_path)
        except R2StorageError as e:
            raise LecturePipelineError(str(e), status_code=502) from e

        if isinstance(downloaded, dict) and record.get("id"):
            try:
                db.table("extras").update({"payload_json": downloaded}).eq(
                    "id", record["id"]
                ).execute()
            except Exception:  # noqa: BLE001
                pass
        return downloaded if isinstance(downloaded, dict) else None

    async def generate_flashcards_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> FlashcardsPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.FLASHCARDS
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, FLASHCARDS)
            generated = await generate_flashcards(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=FLASHCARDS,
                description="Flashcards generation — Qwen3",
                lecture_id=lecture_id,
                action="flashcards",
            )
            self._upsert_extra(
                lecture_id, "flashcards", payload_json=generated
            )

            cards = [
                FlashcardItem(
                    front=c.get("front", c.get("question", "")),
                    back=c.get("back", c.get("answer", "")),
                )
                for c in generated.get("cards", [])
                if isinstance(c, dict)
            ]
            return FlashcardsPayload(cards=cards, credits_charged=FLASHCARDS)
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(
                f"Flashcards generation failed: {e}", status_code=500
            ) from e

    def get_flashcards_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> FlashcardsPayload:
        raw = self._get_extra_json(user_id, lecture_id, "flashcards")
        if not raw:
            return FlashcardsPayload(cards=[])
        cards = [
            FlashcardItem(
                front=c.get("front", c.get("question", "")),
                back=c.get("back", c.get("answer", "")),
            )
            for c in raw.get("cards", [])
            if isinstance(c, dict)
        ]
        return FlashcardsPayload(cards=cards)

    async def generate_quiz_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> QuizPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.QUIZ
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, QUIZ_20_MCQ)
            generated = await generate_quiz_mcq(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=QUIZ_20_MCQ,
                description="Quiz (20 MCQ) generation — Qwen3",
                lecture_id=lecture_id,
                action="quiz",
            )
            self._upsert_extra(lecture_id, "quiz", payload_json=generated)

            questions = []
            for q in generated.get("questions", []):
                if not isinstance(q, dict):
                    continue
                questions.append(
                    QuizQuestionItem(
                        question=q.get("question", ""),
                        options=list(q.get("options") or []),
                        correctAnswer=str(q.get("correctAnswer", "")).strip().upper()[:1],
                        explanation=q.get("explanation"),
                    )
                )
            return QuizPayload(questions=questions, credits_charged=QUIZ_20_MCQ)
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(f"Quiz generation failed: {e}", status_code=500) from e

    def get_quiz_for_lecture(self, user_id: str, lecture_id: str) -> QuizPayload:
        raw = self._get_extra_json(user_id, lecture_id, "quiz")
        if not raw:
            return QuizPayload(questions=[])
        questions = []
        for q in raw.get("questions", []):
            if not isinstance(q, dict):
                continue
            questions.append(
                QuizQuestionItem(
                    question=q.get("question", ""),
                    options=list(q.get("options") or []),
                    correctAnswer=str(q.get("correctAnswer", "")).strip().upper()[:1],
                    explanation=q.get("explanation"),
                )
            )
        return QuizPayload(questions=questions)

    async def generate_revision_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> RevisionPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.REVISION
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, REVISION_NOTES)
            generated = await generate_revision_sheet(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=REVISION_NOTES,
                description="Revision sheet generation — Qwen3",
                lecture_id=lecture_id,
                action="revision",
            )
            self._upsert_extra(lecture_id, "revision", payload_json=generated)

            sheet = (
                generated.get("revisionSheet")
                or generated.get("revision_sheet")
                or ""
            ).strip()
            visual = parse_visual_payload(
                generated.get("visualPayload")
                if isinstance(generated.get("visualPayload"), dict)
                else None
            )
            return RevisionPayload(
                revisionSheet=sheet,
                visualPayload=visual,
                credits_charged=REVISION_NOTES,
            )
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(
                f"Revision sheet generation failed: {e}", status_code=500
            ) from e

    def get_revision_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> RevisionPayload:
        raw = self._get_extra_json(user_id, lecture_id, "revision")
        if not raw:
            return RevisionPayload(revisionSheet="")
        sheet = (raw.get("revisionSheet") or raw.get("revision_sheet") or "").strip()
        visual = parse_visual_payload(
            raw.get("visualPayload")
            if isinstance(raw.get("visualPayload"), dict)
            else None
        )
        return RevisionPayload(revisionSheet=sheet, visualPayload=visual)

    async def generate_five_min_revision_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> RevisionPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.REVISION
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, FIVE_MIN_REVISION)
            generated = await generate_five_min_revision(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=FIVE_MIN_REVISION,
                description="5 Minute Revision — Qwen3",
                lecture_id=lecture_id,
                action="five_min_revision",
            )
            self._upsert_extra(
                lecture_id, "five_min_revision", payload_json=generated
            )

            sheet = (
                generated.get("revisionSheet")
                or generated.get("revision_sheet")
                or ""
            ).strip()
            visual = parse_visual_payload(
                generated.get("visualPayload")
                if isinstance(generated.get("visualPayload"), dict)
                else None
            )
            return RevisionPayload(
                revisionSheet=sheet,
                visualPayload=visual,
                credits_charged=FIVE_MIN_REVISION,
            )
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(
                f"5 Minute Revision generation failed: {e}", status_code=500
            ) from e

    def get_five_min_revision_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> RevisionPayload:
        raw = self._get_extra_json(user_id, lecture_id, "five_min_revision")
        if not raw:
            return RevisionPayload(revisionSheet="")
        sheet = (raw.get("revisionSheet") or raw.get("revision_sheet") or "").strip()
        visual = parse_visual_payload(
            raw.get("visualPayload")
            if isinstance(raw.get("visualPayload"), dict)
            else None
        )
        return RevisionPayload(revisionSheet=sheet, visualPayload=visual)

    def _parse_mind_map_node(self, raw: dict | None) -> MindMapNode | None:
        if not isinstance(raw, dict):
            return None
        children = []
        for child in raw.get("children") or []:
            if isinstance(child, dict):
                parsed = self._parse_mind_map_node(child)
                if parsed is not None:
                    children.append(parsed)
        return MindMapNode(label=(raw.get("label") or "").strip(), children=children)

    async def generate_important_questions_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> ImportantQuestionsPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.IMPORTANT_QUESTIONS
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, IMPORTANT_QUESTIONS)
            generated = await generate_important_questions(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=IMPORTANT_QUESTIONS,
                description="Important questions generation — Qwen3",
                lecture_id=lecture_id,
                action="important_questions",
            )
            self._upsert_extra(
                lecture_id, "important_questions", payload_json=generated
            )

            questions = []
            for q in generated.get("questions", []):
                if not isinstance(q, dict):
                    continue
                questions.append(
                    ImportantQuestionItem(
                        question=q.get("question", ""),
                        type=q.get("type", "short_answer"),
                        marks=int(q.get("marks") or 2),
                        hint=q.get("hint"),
                    )
                )
            return ImportantQuestionsPayload(
                questions=questions, credits_charged=IMPORTANT_QUESTIONS
            )
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(
                f"Important questions generation failed: {e}", status_code=500
            ) from e

    def get_important_questions_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> ImportantQuestionsPayload:
        raw = self._get_extra_json(user_id, lecture_id, "important_questions")
        if not raw:
            return ImportantQuestionsPayload(questions=[])
        questions = []
        for q in raw.get("questions", []):
            if not isinstance(q, dict):
                continue
            questions.append(
                ImportantQuestionItem(
                    question=q.get("question", ""),
                    type=q.get("type", "short_answer"),
                    marks=int(q.get("marks") or 2),
                    hint=q.get("hint"),
                )
            )
        return ImportantQuestionsPayload(questions=questions)

    async def generate_mind_map_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> MindMapPayload:
        try:
            await asyncio.to_thread(
                require_feature_unlocked, user_id, GatedFeature.MIND_MAP
            )
        except FeatureLockedError as e:
            raise _locked(e) from e

        try:
            source = await asyncio.to_thread(
                self._load_lecture_source_text, user_id, lecture_id
            )
            await self._precheck_balance(user_id, MIND_MAP)
            generated = await generate_mind_map(source)
            await asyncio.to_thread(
                deduct_credits,
                user_id=user_id,
                amount=MIND_MAP,
                description="Mind map generation — Qwen3",
                lecture_id=lecture_id,
                action="mind_map",
            )
            self._upsert_extra(lecture_id, "mind_map", payload_json=generated)

            root = self._parse_mind_map_node(generated.get("root"))
            return MindMapPayload(
                title=(generated.get("title") or "").strip(),
                root=root,
                credits_charged=MIND_MAP,
            )
        except FeatureLockedError as e:
            raise _locked(e) from e
        except InsufficientCreditsError as e:
            raise LecturePipelineError(str(e), status_code=402) from e
        except QwenGenerationError as e:
            raise LecturePipelineError(str(e), status_code=502) from e
        except LecturePipelineError:
            raise
        except Exception as e:  # noqa: BLE001
            raise LecturePipelineError(
                f"Mind map generation failed: {e}", status_code=500
            ) from e

    def get_mind_map_for_lecture(
        self, user_id: str, lecture_id: str
    ) -> MindMapPayload:
        raw = self._get_extra_json(user_id, lecture_id, "mind_map")
        if not raw:
            return MindMapPayload(title="", root=None)
        root = self._parse_mind_map_node(raw.get("root"))
        return MindMapPayload(
            title=(raw.get("title") or "").strip(),
            root=root,
        )

    def delete_lecture_for_user(self, user_id: str, lecture_id: str) -> dict:
        """Owner-only permanent delete: R2 files first, then DB row (+ cascade).

        Duplicate child rows that point at this lecture are deleted first so
        ON DELETE SET NULL cannot resurface orphaned done-looking cards.
        If R2 cleanup fails, the DB row is kept so storage is not orphaned.
        """
        lid = (lecture_id or "").strip()
        if not lid:
            raise LecturePipelineError("Lecture id is required.", status_code=400)

        db = get_supabase_admin()
        owned = (
            db.table("lectures")
            .select("id, user_id, r2_folder_path")
            .eq("id", lid)
            .limit(1)
            .execute()
        )
        rows = list(owned.data or [])
        if not rows:
            raise LecturePipelineError("Lecture not found.", status_code=404)
        row = rows[0]
        if row.get("user_id") != user_id:
            raise LecturePipelineError(
                "Not allowed to delete this lecture.", status_code=403
            )

        folder = (row.get("r2_folder_path") or "").strip()
        if not folder:
            folder = self._r2.lecture_folder_path(user_id, lid)

        try:
            deleted_objects = self._r2.delete_prefix(folder)
        except R2StorageError as e:
            raise LecturePipelineError(
                "We couldn’t delete the lecture files. Please try again.",
                status_code=502,
            ) from e

        # Children that reference this lecture as original (SET NULL otherwise).
        try:
            db.table("lectures").delete().eq(
                "duplicate_of_lecture_id", lid
            ).execute()
        except Exception as e:  # noqa: BLE001
            logger.warning("duplicate-child cleanup failed for %s: %s", lid, e)
            raise LecturePipelineError(
                "We couldn’t finish deleting this lecture. Please try again.",
                status_code=502,
            ) from e

        try:
            db.table("lectures").delete().eq("id", lid).eq(
                "user_id", user_id
            ).execute()
        except Exception as e:  # noqa: BLE001
            logger.warning("lecture DB delete failed for %s: %s", lid, e)
            raise LecturePipelineError(
                "We couldn’t finish deleting this lecture. Please try again.",
                status_code=502,
            ) from e

        return {
            "lecture_id": lid,
            "deleted": True,
            "r2_objects_deleted": deleted_objects,
        }

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
