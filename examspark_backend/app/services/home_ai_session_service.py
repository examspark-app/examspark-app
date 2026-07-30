"""Phase 4D — Home AI Study Sessions (history). Soft-fail if SQL not run."""
from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from typing import Any

from app.services.home_ai_response_store import get_home_ai_response, list_tools_for_response
from app.services.home_ai_tools_service import list_tool_statuses
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _title_from_query(query: str, *, max_len: int = 72) -> str:
    t = re.sub(r"\s+", " ", (query or "").strip())
    if not t:
        return "Study session"
    if len(t) <= max_len:
        return t
    return t[: max_len - 1].rstrip() + "…"


def get_session(session_id: str, user_id: str) -> dict[str, Any] | None:
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_sessions")
            .select("*")
            .eq("id", session_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        rows = res.data or []
        return rows[0] if rows else None
    except Exception as e:
        logger.warning("get_session failed: %s", e)
        return None


def _find_session_for_response(response_id: str, user_id: str) -> str | None:
    try:
        sb = get_supabase_admin()
        # Prefer response.session_id if set
        master = get_home_ai_response(response_id, user_id)
        if master and master.get("session_id"):
            return str(master["session_id"])
        res = (
            sb.table("home_ai_messages")
            .select("session_id")
            .eq("response_id", response_id)
            .eq("user_id", user_id)
            .eq("role", "assistant")
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = res.data or []
        if rows and rows[0].get("session_id"):
            return str(rows[0]["session_id"])
    except Exception as e:
        logger.warning("_find_session_for_response failed: %s", e)
    return None


def _create_session(
    *,
    user_id: str,
    title: str,
    conversation_language: str | None,
) -> str | None:
    try:
        sb = get_supabase_admin()
        now = _now_iso()
        row: dict[str, Any] = {
            "user_id": user_id,
            "title": title,
            "status": "active",
            "created_at": now,
            "updated_at": now,
            "last_opened_at": now,
        }
        if conversation_language:
            row["conversation_language"] = conversation_language
        res = sb.table("home_ai_sessions").insert(row).execute()
        data = res.data or []
        if not data:
            return None
        return str(data[0]["id"])
    except Exception as e:
        logger.warning("_create_session failed: %s", e)
        return None


def _touch_session(session_id: str, user_id: str) -> None:
    try:
        sb = get_supabase_admin()
        now = _now_iso()
        sb.table("home_ai_sessions").update(
            {"updated_at": now, "last_opened_at": now}
        ).eq("id", session_id).eq("user_id", user_id).execute()
    except Exception as e:
        logger.warning("_touch_session failed: %s", e)


def _assistant_message_exists(session_id: str, response_id: str, user_id: str) -> bool:
    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_messages")
            .select("id")
            .eq("session_id", session_id)
            .eq("response_id", response_id)
            .eq("user_id", user_id)
            .eq("role", "assistant")
            .limit(1)
            .execute()
        )
        return bool(res.data)
    except Exception as e:
        logger.warning("_assistant_message_exists failed: %s", e)
        return False


def _link_response_session(response_id: str, session_id: str, user_id: str) -> None:
    try:
        sb = get_supabase_admin()
        sb.table("home_ai_responses").update({"session_id": session_id}).eq(
            "id", response_id
        ).eq("user_id", user_id).execute()
    except Exception as e:
        logger.warning("_link_response_session failed: %s", e)


def ensure_session_for_turn(
    *,
    user_id: str,
    query: str,
    answer: str,
    response_id: str,
    credits_used: int = 0,
    session_id: str | None = None,
    parent_response_id: str | None = None,
    conversation_language: str | None = None,
) -> str | None:
    """
    Append user + assistant messages to a Study Session.
    Idempotent on response_id (no duplicate assistant rows).
    Soft-fails → returns None if Phase 4D SQL not run.
    """
    rid = (response_id or "").strip()
    if not rid:
        return None
    q = (query or "").strip()
    a = (answer or "").strip()
    if not q or not a:
        return None

    sid = (session_id or "").strip() or None
    if sid and not get_session(sid, user_id):
        sid = None

    if not sid and parent_response_id:
        sid = _find_session_for_response(parent_response_id.strip(), user_id)

    if not sid:
        # Same response already linked somewhere → reuse that session
        sid = _find_session_for_response(rid, user_id)

    if not sid:
        sid = _create_session(
            user_id=user_id,
            title=_title_from_query(q),
            conversation_language=conversation_language,
        )
    if not sid:
        return None

    if _assistant_message_exists(sid, rid, user_id):
        _touch_session(sid, user_id)
        return sid

    try:
        sb = get_supabase_admin()
        sb.table("home_ai_messages").insert(
            [
                {
                    "session_id": sid,
                    "user_id": user_id,
                    "role": "user",
                    "message": q,
                    "credits_used": 0,
                },
                {
                    "session_id": sid,
                    "user_id": user_id,
                    "role": "assistant",
                    "message": a,
                    "response_id": rid,
                    "credits_used": max(0, int(credits_used or 0)),
                },
            ]
        ).execute()
    except Exception as e:
        logger.warning("ensure_session_for_turn insert failed: %s", e)
        return None

    _link_response_session(rid, sid, user_id)
    _touch_session(sid, user_id)
    return sid


def list_sessions(
    user_id: str,
    *,
    limit: int = 40,
    q: str | None = None,
) -> list[dict[str, Any]]:
    limit = max(1, min(int(limit or 40), 100))
    try:
        sb = get_supabase_admin()
        query = (
            sb.table("home_ai_sessions")
            .select(
                "id,title,conversation_language,status,pinned,bookmarked,"
                "created_at,updated_at,last_opened_at"
            )
            .eq("user_id", user_id)
            .eq("status", "active")
            .order("pinned", desc=True)
            .order("updated_at", desc=True)
            .limit(limit)
        )
        res = query.execute()
        rows = list(res.data or [])
    except Exception as e:
        logger.warning("list_sessions failed: %s", e)
        return []

    needle = (q or "").strip().lower()
    out: list[dict[str, Any]] = []
    for row in rows:
        title = (row.get("title") or "").strip()
        preview = title
        # Optional light search filter (title only for P0 speed)
        if needle and needle not in title.lower():
            continue
        out.append(
            {
                "id": row["id"],
                "title": title or "Study session",
                "preview": preview,
                "conversation_language": row.get("conversation_language"),
                "pinned": bool(row.get("pinned")),
                "bookmarked": bool(row.get("bookmarked")),
                "created_at": row.get("created_at"),
                "updated_at": row.get("updated_at"),
                "last_opened_at": row.get("last_opened_at"),
            }
        )
    return out


def restore_session(session_id: str, user_id: str) -> dict[str, Any] | None:
    """
    Full restore payload — 0 credits, no AI.
    Messages + response meta + tool statuses (chips) for each assistant turn.
    """
    session = get_session(session_id, user_id)
    if not session:
        return None
    _touch_session(session_id, user_id)

    try:
        sb = get_supabase_admin()
        res = (
            sb.table("home_ai_messages")
            .select("id,role,message,response_id,credits_used,created_at")
            .eq("session_id", session_id)
            .eq("user_id", user_id)
            .order("created_at", desc=False)
            .execute()
        )
        raw_msgs = list(res.data or [])
    except Exception as e:
        logger.warning("restore_session messages failed: %s", e)
        return None

    messages: list[dict[str, Any]] = []
    for m in raw_msgs:
        item: dict[str, Any] = {
            "id": m.get("id"),
            "role": m.get("role"),
            "message": m.get("message") or "",
            "response_id": m.get("response_id"),
            "credits_used": m.get("credits_used") or 0,
            "created_at": m.get("created_at"),
        }
        rid = m.get("response_id")
        if m.get("role") == "assistant" and rid:
            master = get_home_ai_response(str(rid), user_id)
            if master:
                item["visual_payload"] = master.get("visual_payload_json")
                item["answer_source"] = master.get("answer_source")
                item["confidence"] = master.get("confidence")
                item["conversation_language"] = master.get("conversation_language")
            try:
                item["tools"] = list_tool_statuses(str(rid), user_id)
            except Exception:
                # Soft: statuses optional; chips still open via response_id
                rows = list_tools_for_response(str(rid), user_id)
                item["tools"] = {
                    "response_id": str(rid),
                    "tools": {
                        r["tool_type"]: {
                            "status": r.get("status") or "ready",
                            "has_payload": bool(r.get("payload_json")),
                        }
                        for r in rows
                    },
                    "recommended": [],
                    "chip_credits": 0,
                }
        messages.append(item)

    return {
        "id": session["id"],
        "title": session.get("title") or "Study session",
        "conversation_language": session.get("conversation_language"),
        "pinned": bool(session.get("pinned")),
        "bookmarked": bool(session.get("bookmarked")),
        "created_at": session.get("created_at"),
        "updated_at": session.get("updated_at"),
        "last_opened_at": session.get("last_opened_at"),
        "messages": messages,
        "credits_charged": 0,
    }


def rename_session(session_id: str, user_id: str, title: str) -> dict[str, Any] | None:
    t = _title_from_query(title, max_len=120)
    if not get_session(session_id, user_id):
        return None
    try:
        sb = get_supabase_admin()
        sb.table("home_ai_sessions").update(
            {"title": t, "updated_at": _now_iso()}
        ).eq("id", session_id).eq("user_id", user_id).execute()
        return get_session(session_id, user_id)
    except Exception as e:
        logger.warning("rename_session failed: %s", e)
        return None


def delete_session(session_id: str, user_id: str) -> bool:
    if not get_session(session_id, user_id):
        return False
    try:
        sb = get_supabase_admin()
        sb.table("home_ai_sessions").delete().eq("id", session_id).eq(
            "user_id", user_id
        ).execute()
        return True
    except Exception as e:
        logger.warning("delete_session failed: %s", e)
        return False


def set_session_pinned(session_id: str, user_id: str, pinned: bool) -> bool:
    if not get_session(session_id, user_id):
        return False
    try:
        sb = get_supabase_admin()
        sb.table("home_ai_sessions").update(
            {"pinned": bool(pinned), "updated_at": _now_iso()}
        ).eq("id", session_id).eq("user_id", user_id).execute()
        return True
    except Exception as e:
        logger.warning("set_session_pinned failed: %s", e)
        return False
