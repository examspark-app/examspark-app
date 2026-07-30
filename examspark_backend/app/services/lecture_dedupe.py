"""Per-student lecture duplicate detection (Layer 1 hash/YouTube + Layer 2 transcript).

Privacy: never compare across users.
"""
from __future__ import annotations

import hashlib
import logging
from typing import Any

from app.services.embedding_service import EmbeddingError, embed_query
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

# Near-identical transcript (re-record / re-encode). Related topics score much lower.
TRANSCRIPT_NEAR_DUP_THRESHOLD = 0.95
_EMBED_SNIPPET_CHARS = 4000

DUPLICATE_USER_MESSAGE = (
    "This looks like content you've already added — here are your existing notes for it. "
    "No credits were charged."
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def find_done_by_youtube_video_id(user_id: str, video_id: str) -> dict[str, Any] | None:
    vid = (video_id or "").strip()
    if not vid:
        return None
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("lectures")
            .select("id,title,r2_folder_path,status")
            .eq("user_id", user_id)
            .eq("youtube_video_id", vid)
            .eq("status", "done")
            .is_("duplicate_of_lecture_id", "null")
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = list(res.data or [])
        if rows:
            logger.info(
                "YouTube dedupe lookup HIT video_id=%s user_id=%s lecture_id=%s",
                vid,
                user_id,
                rows[0].get("id"),
            )
            return rows[0]
        logger.info(
            "YouTube dedupe lookup MISS video_id=%s user_id=%s",
            vid,
            user_id,
        )
        return None
    except Exception as e:  # noqa: BLE001
        logger.warning("YouTube dedupe lookup failed (run lecture_dedupe_migration.sql?): %s", e)
        return None


def find_done_by_content_hash(user_id: str, content_hash: str) -> dict[str, Any] | None:
    h = (content_hash or "").strip()
    if not h:
        return None
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("lectures")
            .select("id,title,r2_folder_path,status")
            .eq("user_id", user_id)
            .eq("content_hash", h)
            .eq("status", "done")
            .is_("duplicate_of_lecture_id", "null")
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = list(res.data or [])
        return rows[0] if rows else None
    except Exception as e:  # noqa: BLE001
        logger.warning("Hash dedupe lookup failed (run lecture_dedupe_migration.sql?): %s", e)
        return None


async def find_near_duplicate_transcript_lecture(
    user_id: str,
    transcript_text: str,
    *,
    exclude_lecture_id: str | None = None,
    threshold: float = TRANSCRIPT_NEAR_DUP_THRESHOLD,
) -> dict[str, Any] | None:
    """Layer 2: embed transcript snippet → match own clean_transcript vectors."""
    text = (transcript_text or "").strip()
    if len(text) < 80:
        return None
    snippet = text[:_EMBED_SNIPPET_CHARS]
    try:
        embedding = await embed_query(snippet)
    except EmbeddingError as e:
        logger.warning("Layer 2 embed failed: %s", e)
        return None
    except Exception as e:  # noqa: BLE001
        logger.warning("Layer 2 embed unexpected: %s", e)
        return None

    try:
        sb = get_supabase_admin()
        res = sb.rpc(
            "match_own_transcript_near_dup",
            {
                "p_user_id": user_id,
                # Same list[float] shape as match_rag_documents (PostgREST coerces).
                "p_query_embedding": embedding,
                "p_exclude_lecture_id": exclude_lecture_id,
                "p_match_threshold": float(threshold),
                "p_match_count": 3,
            },
        ).execute()
        rows = list(res.data or [])
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "Layer 2 RPC failed (run lecture_dedupe_migration.sql?): %s", e
        )
        return None

    if not rows:
        return None
    best = rows[0]
    lid = best.get("lecture_id")
    if not lid:
        return None
    try:
        lec = (
            sb.table("lectures")
            .select("id,title,r2_folder_path,status")
            .eq("id", str(lid))
            .eq("user_id", user_id)
            .eq("status", "done")
            .limit(1)
            .execute()
        )
        data = list(lec.data or [])
        if not data:
            return None
        out = dict(data[0])
        out["similarity"] = best.get("similarity")
        return out
    except Exception as e:  # noqa: BLE001
        logger.warning("Layer 2 lecture fetch failed: %s", e)
        return None


def mark_lecture_as_duplicate(
    *,
    new_lecture_id: str,
    original_lecture_id: str,
    content_hash: str | None = None,
    youtube_video_id: str | None = None,
) -> None:
    """Point new row at original; do not index RAG for the duplicate."""
    sb = get_supabase_admin()
    update: dict[str, Any] = {
        "status": "done",
        "duplicate_of_lecture_id": original_lecture_id,
        "error_message": None,
    }
    if content_hash:
        update["content_hash"] = content_hash
    if youtube_video_id:
        update["youtube_video_id"] = youtube_video_id
    # Share original R2 folder pointer when available
    try:
        orig = (
            sb.table("lectures")
            .select("r2_folder_path")
            .eq("id", original_lecture_id)
            .limit(1)
            .execute()
        )
        folder = (list(orig.data or []) or [{}])[0].get("r2_folder_path")
        if folder:
            update["r2_folder_path"] = folder
    except Exception:  # noqa: BLE001
        pass
    sb.table("lectures").update(update).eq("id", new_lecture_id).execute()


def stamp_lecture_identity(
    lecture_id: str | None,
    *,
    content_hash: str | None = None,
    youtube_video_id: str | None = None,
) -> None:
    """Persist Layer 1 keys after a successful non-duplicate process."""
    if not lecture_id:
        return
    update: dict[str, Any] = {}
    if content_hash:
        update["content_hash"] = content_hash
    if youtube_video_id:
        update["youtube_video_id"] = youtube_video_id
    if not update:
        return
    try:
        get_supabase_admin().table("lectures").update(update).eq(
            "id", lecture_id
        ).execute()
        logger.info(
            "stamp_lecture_identity ok lecture_id=%s keys=%s",
            lecture_id,
            list(update.keys()),
        )
    except Exception as e:  # noqa: BLE001
        logger.warning("stamp_lecture_identity failed: %s", e)
