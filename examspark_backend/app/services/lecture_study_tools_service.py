"""Study Workspace chips — generate Home-style tools from a recording's notes.

Unlike Home AI (first open free from Knowledge Object), recording chips always
charge lecture credit costs and save into `extras` for share-to-group.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any

from app.constants.credit_costs import (
    FIVE_MIN_REVISION,
    FLASHCARDS,
    IMPORTANT_QUESTIONS,
    MIND_MAP,
    QUIZ_20_MCQ,
    REVISION_NOTES,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.home_ai_response_store import VALID_TOOL_TYPES
from app.services.home_ai_tools_service import (
    HomeAiToolError,
    generate_tool_from_source,
    home_tool_credit_cost,
)
from app.services.lecture_service import LecturePipelineError, LectureService
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.pyq_retrieve import format_exam_focus_block, match_pyqs_for_query
from app.services.qwen_service import QwenGenerationError
from app.services.rag_ask_service import _credits_balance
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

_lecture = LectureService()


def lecture_tool_credit_cost(tool_type: str) -> int:
    """Recording generate costs — CREDIT_ECONOMY lecture bands (not Home free-open)."""
    key = (tool_type or "").strip().lower().replace("-", "_")
    if key in ("flashcards", "flashcard"):
        return FLASHCARDS
    if key in ("quiz", "mcq"):
        return QUIZ_20_MCQ
    if key in ("important_questions",):
        return IMPORTANT_QUESTIONS
    if key in ("mind_map",):
        return MIND_MAP
    if key in ("five_min_revision", "five_minute_revision", "5_min_revision"):
        return FIVE_MIN_REVISION
    if key in (
        "revision",
        "learn_more",
        "memory_tricks",
        "visual",
        "cheat_sheet",
        "common_mistakes",
        "teacher_tips",
        "exam_booster",
    ):
        return REVISION_NOTES
    # Fallback — same as Home regenerate fallback.
    return home_tool_credit_cost(key, regenerate=True)


def _gate_for_tool(tool_type: str) -> GatedFeature:
    key = (tool_type or "").strip().lower().replace("-", "_")
    if key in ("flashcards", "flashcard"):
        return GatedFeature.FLASHCARDS
    if key in ("quiz", "mcq"):
        return GatedFeature.QUIZ
    if key in ("important_questions",):
        return GatedFeature.IMPORTANT_QUESTIONS
    if key in ("mind_map",):
        return GatedFeature.MIND_MAP
    return GatedFeature.REVISION


def _normalize(tool_type: str) -> str:
    key = (tool_type or "").strip().lower().replace("-", "_")
    aliases = {
        "revision_sheet": "revision",
        "cheat": "cheat_sheet",
        "five_minute_revision": "five_min_revision",
        "5_min_revision": "five_min_revision",
        "memory": "memory_tricks",
        "memory_trick": "memory_tricks",
        "diagram": "visual",
        "visuals": "visual",
        "flashcard": "flashcards",
        "mcq": "quiz",
    }
    key = aliases.get(key, key)
    if key not in VALID_TOOL_TYPES:
        raise LecturePipelineError(f"Unknown study chip: {tool_type}", status_code=400)
    return key


def list_lecture_tool_statuses(user_id: str, lecture_id: str) -> dict[str, Any]:
    _lecture._assert_lecture_owner_or_group_member(user_id, lecture_id)
    db = get_supabase_admin()
    rows = (
        db.table("extras")
        .select("type, payload_json")
        .eq("lecture_id", lecture_id)
        .execute()
    )
    present: set[str] = set()
    for r in rows.data or []:
        t = (r.get("type") or "").strip().lower()
        if t and r.get("payload_json"):
            present.add(t)
    # Notes visual counts as visual chip ready.
    try:
        notes = (
            db.table("notes")
            .select("visual_payload_json")
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        if notes.data and notes.data[0].get("visual_payload_json"):
            present.add("visual")
    except Exception:  # noqa: BLE001
        pass

    tools: dict[str, Any] = {}
    for t in VALID_TOOL_TYPES:
        has = t in present
        tools[t] = {
            "status": "generated" if has else "ready",
            "has_payload": has,
            "credits": lecture_tool_credit_cost(t),
        }
    return {
        "lecture_id": lecture_id,
        "tools": tools,
        "chip_credits_note": "Recording chips charge on first generate (not free like Home).",
    }


def get_lecture_tool(
    user_id: str, lecture_id: str, tool_type: str
) -> dict[str, Any]:
    tool_type = _normalize(tool_type)
    raw = _lecture._get_extra_json(user_id, lecture_id, tool_type)
    if not raw and tool_type == "visual":
        # Fall back to notes visual_payload.
        db = get_supabase_admin()
        notes = (
            db.table("notes")
            .select("visual_payload_json")
            .eq("lecture_id", lecture_id)
            .limit(1)
            .execute()
        )
        if notes.data and notes.data[0].get("visual_payload_json"):
            raw = {
                "format": "notes_visual",
                "visual_payload": notes.data[0]["visual_payload_json"],
                "visualPayload": notes.data[0]["visual_payload_json"],
            }
    if not raw:
        raise LecturePipelineError(
            "Tool not generated yet. Generate from Study Workspace chips first.",
            status_code=404,
        )
    return {
        "lecture_id": lecture_id,
        "tool_type": tool_type,
        "status": "generated",
        "payload": raw,
        "credits_charged": 0,
        "new_balance": _credits_balance(user_id),
        "cached": True,
    }


async def _enrich_source_for_exam_tools(
    *,
    user_id: str,
    lecture_id: str,
    tool_type: str,
    source: str,
) -> str:
    """Teacher quality: Quiz / Important Qs bias to high-probability PYQ chapters.

    First generate already runs AI (paid). We prepend EXAM FOCUS metadata from
    PYQ bank (tags only — never paper text) so questions match exam likelihood.
    Soft-fail if PYQ bank empty / RPC fails.
    """
    if tool_type not in ("quiz", "important_questions"):
        return source

    query = ""
    try:
        row = (
            get_supabase_admin()
            .table("lectures")
            .select("title, subject, topic")
            .eq("id", lecture_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        if row.data:
            r = row.data[0]
            parts = [
                (r.get("subject") or "").strip(),
                (r.get("topic") or "").strip(),
                (r.get("title") or "").strip(),
            ]
            query = " — ".join(p for p in parts if p)
    except Exception as e:  # noqa: BLE001
        logger.warning("lecture meta for PYQ focus skipped: %s", e)

    if not query:
        # Fall back to notes head so retrieval still has a topic signal.
        query = (source or "")[:400].strip() or "exam topic"

    pyq_matches: list = []
    try:
        pyq_matches = await match_pyqs_for_query(query, limit=6)
    except Exception as e:  # noqa: BLE001
        logger.warning("lecture chip PYQ match skipped: %s", e)
        pyq_matches = []

    focus = format_exam_focus_block(pyq_matches)
    quality = (
        "TEACHER PRODUCT QUALITY (recording Study chips):\n"
        "Generate ORIGINAL high-exam-probability practice first. "
        "Prefer topics that match EXAM FOCUS weightage and the strongest "
        "ideas in the lecture notes below. Never copy copyrighted PYQ text.\n\n"
    )
    if focus:
        return f"{quality}{focus}\n\nLECTURE NOTES:\n{source}"
    return f"{quality}LECTURE NOTES:\n{source}"


async def generate_lecture_tool(
    *,
    user_id: str,
    lecture_id: str,
    tool_type: str,
    regenerate: bool = False,
) -> dict[str, Any]:
    tool_type = _normalize(tool_type)

    try:
        require_feature_unlocked(user_id, _gate_for_tool(tool_type))
    except FeatureLockedError as e:
        raise LecturePipelineError(
            str(e),
            status_code=403,
            detail=feature_locked_payload(e),
        ) from e

    # Owner-only generate (students read-only via share).
    _lecture._assert_lecture_owner(user_id, lecture_id)

    if not regenerate:
        try:
            return get_lecture_tool(user_id, lecture_id, tool_type)
        except LecturePipelineError as e:
            if e.status_code != 404:
                raise

    amount = lecture_tool_credit_cost(tool_type)
    balance = _credits_balance(user_id)
    if balance < amount:
        raise LecturePipelineError(
            f"Insufficient credits: balance {balance} < required {amount}",
            status_code=402,
        )

    try:
        source = await asyncio.to_thread(
            _lecture._load_lecture_source_text, user_id, lecture_id
        )
        source = await _enrich_source_for_exam_tools(
            user_id=user_id,
            lecture_id=lecture_id,
            tool_type=tool_type,
            source=source,
        )
        payload = await generate_tool_from_source(tool_type, source)
        await asyncio.to_thread(
            deduct_credits,
            user_id=user_id,
            amount=amount,
            description=f"Recording study chip — {tool_type}",
            lecture_id=lecture_id,
            action=f"lecture_chip_{tool_type}",
        )
        await asyncio.to_thread(
            lambda: _lecture._upsert_extra(
                lecture_id, tool_type, payload_json=payload
            )
        )
        return {
            "lecture_id": lecture_id,
            "tool_type": tool_type,
            "status": "generated",
            "payload": payload,
            "credits_charged": amount,
            "new_balance": _credits_balance(user_id),
            "cached": False,
        }
    except FeatureLockedError as e:
        raise LecturePipelineError(
            str(e),
            status_code=403,
            detail=feature_locked_payload(e),
        ) from e
    except InsufficientCreditsError as e:
        raise LecturePipelineError(str(e), status_code=402) from e
    except QwenGenerationError as e:
        raise LecturePipelineError(str(e), status_code=502) from e
    except HomeAiToolError as e:
        raise LecturePipelineError(str(e), status_code=e.status_code) from e
    except LecturePipelineError:
        raise
    except Exception as e:  # noqa: BLE001
        logger.exception("lecture study tool failed")
        raise LecturePipelineError(
            f"Study chip generation failed: {e}", status_code=500
        ) from e
