"""Lazy RAG index — chunk notes + transcript from R2 into rag_documents.

Does NOT touch the lecture process pipeline. Called on first Ask AI
(or POST /api/v1/lectures/{id}/index) for a lecture.

Founder lock (Jul 18, 2026): only audio (recorded / uploaded_audio) and
YouTube lectures are stored in RAG. PDF / photo uploads
(source_type=uploaded_document) stay out of rag_documents — Ask AI still
answers from that lecture's notes via direct fallback, and Home chips use
the Knowledge Object / notes, not the vector store.
"""
from __future__ import annotations

import logging

from app.services.chunk_service import chunk_hash, chunk_text
from app.services.embedding_service import EmbeddingError, embed_texts
from app.services.r2_storage_service import R2StorageError, R2StorageService
from app.services.supabase_admin import get_supabase_admin
from app.models.visual_payload import parse_visual_payload, visual_payload_to_plain_text

logger = logging.getLogger(__name__)

_EMBED_BATCH = 16

# Library RAG = long-term study memory from spoken / YouTube content only.
_RAG_INDEX_SOURCE_TYPES = frozenset(
    {
        "recorded",
        "uploaded_audio",
        "youtube_link",
    }
)


class RagIndexError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        self.status_code = status_code
        super().__init__(message)


def is_rag_indexable_source(source_type: str | None) -> bool:
    """True only for audio + YouTube. PDF/photo (uploaded_document) = False."""
    return (source_type or "").strip() in _RAG_INDEX_SOURCE_TYPES


def _lecture_owned(user_id: str, lecture_id: str) -> dict:
    db = get_supabase_admin()
    result = (
        db.table("lectures")
        .select("id, user_id, status, source_type")
        .eq("id", lecture_id)
        .limit(1)
        .execute()
    )
    rows = result.data or []
    if not rows:
        raise RagIndexError("Lecture not found.", status_code=404)
    row = rows[0]
    if row.get("user_id") != user_id:
        raise RagIndexError("Not allowed to index this lecture.", status_code=403)
    return row


def _already_indexed(lecture_id: str) -> bool:
    db = get_supabase_admin()
    result = (
        db.table("rag_documents")
        .select("id")
        .eq("lecture_id", lecture_id)
        .limit(1)
        .execute()
    )
    return bool(result.data)


def _load_notes_text(user_id: str, lecture_id: str, r2: R2StorageService) -> str:
    db = get_supabase_admin()
    notes = (
        db.table("notes")
        .select(
            "clean_notes, short_summary, key_points, important_terms, "
            "visual_payload_json, r2_notes_path"
        )
        .eq("lecture_id", lecture_id)
        .limit(1)
        .execute()
    )
    rows = notes.data or []
    if rows:
        row = rows[0]
        parts = [
            (row.get("clean_notes") or "").strip(),
            (row.get("short_summary") or "").strip(),
        ]
        key_points = row.get("key_points") or []
        if isinstance(key_points, list) and key_points:
            parts.append("Key points: " + "; ".join(str(p) for p in key_points))
        visual = parse_visual_payload(row.get("visual_payload_json"))
        visual_text = visual_payload_to_plain_text(visual)
        if visual_text:
            parts.append(visual_text)
        joined = "\n\n".join(p for p in parts if p).strip()
        if joined:
            return joined
    path = rows[0].get("r2_notes_path") if rows else None
    if not path:
        return ""
    try:
        data = r2.download_json(path)
    except R2StorageError as e:
        raise RagIndexError(str(e), status_code=502) from e
    parts = [
        (data.get("cleanNotes") or "").strip(),
        (data.get("shortSummary") or "").strip(),
    ]
    key_points = data.get("keyPoints") or []
    if isinstance(key_points, list) and key_points:
        parts.append("Key points: " + "; ".join(str(p) for p in key_points))
    visual = parse_visual_payload(
        data.get("visualPayload") if isinstance(data.get("visualPayload"), dict) else None
    )
    visual_text = visual_payload_to_plain_text(visual)
    if visual_text:
        parts.append(visual_text)
    return "\n\n".join(p for p in parts if p)


def _load_transcript_text(lecture_id: str, r2: R2StorageService) -> str:
    db = get_supabase_admin()
    tr = (
        db.table("transcripts")
        .select("r2_transcript_path, clean_transcript_path")
        .eq("lecture_id", lecture_id)
        .limit(1)
        .execute()
    )
    rows = tr.data or []
    if not rows:
        return ""
    path = rows[0].get("clean_transcript_path") or rows[0].get("r2_transcript_path")
    if not path:
        return ""
    try:
        return r2.download_text(path).strip()
    except R2StorageError as e:
        raise RagIndexError(str(e), status_code=502) from e


async def _index_source(
    *,
    user_id: str,
    lecture_id: str,
    source_type: str,
    text: str,
    r2: R2StorageService,
) -> int:
    chunks = chunk_text(text)
    if not chunks:
        return 0

    db = get_supabase_admin()
    inserted = 0
    # folder path still used only via rag_chunk_path helper

    for i in range(0, len(chunks), _EMBED_BATCH):
        batch = chunks[i : i + _EMBED_BATCH]
        try:
            vectors = await embed_texts(batch)
        except EmbeddingError as e:
            raise RagIndexError(str(e), status_code=502) from e

        for chunk, vector in zip(batch, vectors, strict=True):
            h = chunk_hash(chunk)
            existing = (
                db.table("rag_documents")
                .select("id")
                .eq("lecture_id", lecture_id)
                .eq("source_type", source_type)
                .eq("chunk_hash", h)
                .limit(1)
                .execute()
            )
            if existing.data:
                continue

            chunk_path = r2.rag_chunk_path(user_id, lecture_id, source_type, h)
            try:
                r2.upload_text(chunk_path, chunk)
            except R2StorageError as e:
                raise RagIndexError(str(e), status_code=502) from e

            # pgvector via PostgREST: pass embedding as list — supabase-py
            # serializes it for the vector column.
            db.table("rag_documents").insert(
                {
                    "user_id": user_id,
                    "lecture_id": lecture_id,
                    "source_type": source_type,
                    "r2_chunk_path": chunk_path,
                    "chunk_hash": h,
                    "embedding": vector,
                }
            ).execute()
            inserted += 1

    return inserted


async def ensure_lecture_indexed(user_id: str, lecture_id: str) -> dict:
    """Index notes + clean_transcript if no rag_documents yet. Idempotent.

    Skips PDF/photo uploads (uploaded_document) — never writes to rag_documents.
    """
    row = _lecture_owned(user_id, lecture_id)
    source_type = (row.get("source_type") or "").strip()

    if not is_rag_indexable_source(source_type):
        logger.info(
            "Skip RAG index for lecture %s (source_type=%s — PDF/photo not stored in RAG)",
            lecture_id,
            source_type or "?",
        )
        return {
            "lecture_id": lecture_id,
            "already_indexed": False,
            "skipped": True,
            "skip_reason": "pdf_photo_not_in_rag",
            "source_type": source_type,
            "chunks": 0,
            "notes_chunks": 0,
            "transcript_chunks": 0,
        }

    if _already_indexed(lecture_id):
        db = get_supabase_admin()
        count = (
            db.table("rag_documents")
            .select("id", count="exact")
            .eq("lecture_id", lecture_id)
            .execute()
        )
        return {
            "lecture_id": lecture_id,
            "already_indexed": True,
            "chunks": count.count or 0,
            "notes_chunks": 0,
            "transcript_chunks": 0,
        }

    r2 = R2StorageService()
    notes_text = _load_notes_text(user_id, lecture_id, r2)
    transcript_text = _load_transcript_text(lecture_id, r2)

    if not notes_text and not transcript_text:
        raise RagIndexError(
            "No notes or transcript content to index for this lecture.",
            status_code=400,
        )

    notes_n = 0
    tr_n = 0
    if notes_text:
        notes_n = await _index_source(
            user_id=user_id,
            lecture_id=lecture_id,
            source_type="notes",
            text=notes_text,
            r2=r2,
        )
    if transcript_text:
        tr_n = await _index_source(
            user_id=user_id,
            lecture_id=lecture_id,
            source_type="clean_transcript",
            text=transcript_text,
            r2=r2,
        )

    logger.info(
        "Indexed lecture %s: notes_chunks=%s transcript_chunks=%s",
        lecture_id,
        notes_n,
        tr_n,
    )
    return {
        "lecture_id": lecture_id,
        "already_indexed": False,
        "chunks": notes_n + tr_n,
        "notes_chunks": notes_n,
        "transcript_chunks": tr_n,
    }
