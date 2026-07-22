"""Persist / load Home AI master responses + chip tools (Phase 4C)."""
from __future__ import annotations

import logging
from typing import Any

from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

VALID_TOOL_TYPES = frozenset(
    {
        "learn_more",
        "flashcards",
        "quiz",
        "revision",
        "mind_map",
        "cheat_sheet",
        "five_min_revision",
        "important_questions",
        "memory_tricks",
        "visual",
        "exam_booster",
        "common_mistakes",
        "teacher_tips",
    }
)


def persist_home_ai_response(
    *,
    user_id: str,
    query: str,
    answer: str,
    knowledge_json: dict[str, Any],
    visual_payload: dict[str, Any] | None = None,
    answer_source: str | None = None,
    confidence: str | None = None,
    conversation_language: str | None = None,
    lecture_id: str | None = None,
    parent_response_id: str | None = None,
    knowledge_version: int = 1,
) -> str | None:
    """Insert master response. Returns response_id or None if DB unavailable."""
    try:
        sb = get_supabase_admin()
        row: dict[str, Any] = {
            "user_id": user_id,
            "query": query,
            "answer": answer,
            "knowledge_json": knowledge_json,
            "answer_source": answer_source,
            "confidence": confidence,
            "conversation_language": conversation_language,
            "knowledge_version": knowledge_version,
        }
        if visual_payload is not None:
            row["visual_payload_json"] = visual_payload
        if lecture_id:
            row["lecture_id"] = lecture_id
        if parent_response_id:
            row["parent_response_id"] = parent_response_id
        res = sb.table("home_ai_responses").insert(row).execute()
        data = res.data or []
        if not data:
            logger.warning("home_ai_responses insert returned empty data")
            return None
        return str(data[0]["id"])
    except Exception as e:
        # Soft-fail until founder runs migration — Home AI still works.
        logger.warning("persist_home_ai_response failed: %s", e)
        return None


def get_home_ai_response(response_id: str, user_id: str) -> dict[str, Any] | None:
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_responses")
            .select("*")
            .eq("id", response_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        rows = res.data or []
        return rows[0] if rows else None
    except Exception as e:
        logger.warning("get_home_ai_response failed: %s", e)
        return None


def list_tools_for_response(response_id: str, user_id: str) -> list[dict[str, Any]]:
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_tools")
            .select("tool_type,status,payload_json,error_message,updated_at")
            .eq("response_id", response_id)
            .eq("user_id", user_id)
            .execute()
        )
        return list(res.data or [])
    except Exception as e:
        logger.warning("list_tools_for_response failed: %s", e)
        return []


def get_tool_row(
    response_id: str, user_id: str, tool_type: str
) -> dict[str, Any] | None:
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_tools")
            .select("*")
            .eq("response_id", response_id)
            .eq("user_id", user_id)
            .eq("tool_type", tool_type)
            .limit(1)
            .execute()
        )
        rows = res.data or []
        return rows[0] if rows else None
    except Exception as e:
        logger.warning("get_tool_row failed: %s", e)
        return None


def try_claim_generating(
    *,
    response_id: str,
    user_id: str,
    tool_type: str,
) -> dict[str, Any] | None:
    """Insert generating row. Returns existing row if already present (race)."""
    sb = get_supabase_admin()
    existing = get_tool_row(response_id, user_id, tool_type)
    if existing:
        return existing
    try:
        res = (
            sb.table("home_ai_tools")
            .insert(
                {
                    "response_id": response_id,
                    "user_id": user_id,
                    "tool_type": tool_type,
                    "status": "generating",
                    "payload_json": None,
                }
            )
            .execute()
        )
        data = res.data or []
        if data:
            return data[0]
    except Exception:
        # Unique race — fetch winner
        return get_tool_row(response_id, user_id, tool_type)
    return get_tool_row(response_id, user_id, tool_type)


def mark_tool_generated(
    *,
    response_id: str,
    user_id: str,
    tool_type: str,
    payload: dict[str, Any],
) -> None:
    sb = get_supabase_admin()
    sb.table("home_ai_tools").update(
        {
            "status": "generated",
            "payload_json": payload,
            "error_message": None,
            "updated_at": "now()",
        }
    ).eq("response_id", response_id).eq("user_id", user_id).eq(
        "tool_type", tool_type
    ).execute()


def mark_tool_failed(
    *,
    response_id: str,
    user_id: str,
    tool_type: str,
    error_message: str,
) -> None:
    sb = get_supabase_admin()
    sb.table("home_ai_tools").update(
        {
            "status": "failed",
            "error_message": error_message[:500],
            "updated_at": "now()",
        }
    ).eq("response_id", response_id).eq("user_id", user_id).eq(
        "tool_type", tool_type
    ).execute()


def clear_tool_for_regenerate(
    *,
    response_id: str,
    user_id: str,
    tool_type: str,
) -> None:
    """Reset to generating for explicit regenerate."""
    sb = get_supabase_admin()
    sb.table("home_ai_tools").update(
        {
            "status": "generating",
            "payload_json": None,
            "error_message": None,
            "updated_at": "now()",
        }
    ).eq("response_id", response_id).eq("user_id", user_id).eq(
        "tool_type", tool_type
    ).execute()


def mark_tools_stale_for_response(response_id: str, user_id: str) -> None:
    """Follow-up Knowledge V2 — mark prior chips stale (must reopen / regenerate)."""
    try:
        sb = get_supabase_admin()
        sb.table("home_ai_tools").update(
            {
                "status": "stale",
                "error_message": "Knowledge updated — reopen chip to refresh",
                "updated_at": "now()",
            }
        ).eq("response_id", response_id).eq("user_id", user_id).eq(
            "status", "generated"
        ).execute()
    except Exception as e:
        logger.warning("mark_tools_stale_for_response failed: %s", e)


def next_knowledge_version(parent_response_id: str, user_id: str) -> int:
    parent = get_home_ai_response(parent_response_id, user_id)
    if not parent:
        return 1
    try:
        return int(parent.get("knowledge_version") or 1) + 1
    except (TypeError, ValueError):
        return 2
