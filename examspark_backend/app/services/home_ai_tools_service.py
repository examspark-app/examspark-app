"""Home AI chip tools — generate from Knowledge Object (Phase 4C).

Client sends only response_id + tool_type. Never accepts full prior answer.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from app.constants.credit_costs import (
    ASK_AI_NORMAL,
    FIVE_MIN_REVISION,
    FLASHCARDS,
    HOME_CHIP_IMPORTANT_QUESTIONS,
    HOME_CHIP_MIND_MAP,
    QUIZ_20_MCQ,
    REVISION_NOTES,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.home_ai_knowledge import knowledge_to_source_text
from app.services.home_ai_tool_derive import derive_tool_payload, recommend_tool_types
from app.services.home_ai_response_store import (
    VALID_TOOL_TYPES,
    clear_tool_for_regenerate,
    get_home_ai_response,
    get_tool_row,
    list_tools_for_response,
    mark_tool_failed,
    mark_tool_generated,
    try_claim_generating,
)
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
    generate_quiz_mcq,
    generate_revision_sheet,
)
from app.services.pyq_retrieve import (
    format_exam_focus_block,
    match_pyqs_for_query,
)
from app.services.rag_ask_service import _credits_balance

logger = logging.getLogger(__name__)


class HomeAiToolError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        *,
        detail: dict | None = None,
    ):
        self.status_code = status_code
        self.detail = detail
        super().__init__(message)


def home_tool_credit_cost(tool_type: str, *, regenerate: bool = False) -> int:
    """Founder lock: first chip open from KO = 0. Only Regenerate is paid."""
    if not regenerate:
        return 0
    key = (tool_type or "").strip().lower()
    if key in ("mind_map", "mind-map"):
        return HOME_CHIP_MIND_MAP
    if key in ("important_questions", "important-questions"):
        return HOME_CHIP_IMPORTANT_QUESTIONS
    if key in ("flashcards",):
        return FLASHCARDS
    if key in ("quiz",):
        return QUIZ_20_MCQ
    if key in ("revision", "learn_more", "memory_tricks", "visual"):
        return REVISION_NOTES
    if key in ("cheat_sheet",):
        return ASK_AI_NORMAL
    if key in ("five_min_revision", "five-min-revision"):
        return FIVE_MIN_REVISION
    return ASK_AI_NORMAL


def _normalize_tool_type(tool_type: str) -> str:
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
    }
    key = aliases.get(key, key)
    if key not in VALID_TOOL_TYPES:
        raise HomeAiToolError(f"Unknown tool_type: {tool_type}", status_code=400)
    return key


async def _generate_learn_more(source: str) -> dict[str, Any]:
    from app.constants.visual_notes_prompt import STUDY_CONTENT_LANGUAGE_RULE
    from app.services.qwen_service import _chat_json

    system = (
        STUDY_CONTENT_LANGUAGE_RULE
        + "\nYou are ExamSpark Learn More. Return JSON only: "
        '{"markdown":"...","sections":[{"title":"...","body":"..."}]} '
        "Exactly 3 short sections (What students miss / Analogy / Deeper exam angle). "
        "No essay. No Suggested Study Actions. Keep total under ~400 words."
    )
    parsed = await _chat_json(system, source, max_tokens=1600)
    md = (parsed.get("markdown") or "").strip()
    if len(md) < 80:
        raise QwenGenerationError("Learn More returned too little content.")
    return {"markdown": md, "sections": parsed.get("sections") or []}


async def _generate_cheat_sheet(source: str) -> dict[str, Any]:
    from app.constants.visual_notes_prompt import STUDY_CONTENT_LANGUAGE_RULE
    from app.services.qwen_service import _chat_json

    system = (
        STUDY_CONTENT_LANGUAGE_RULE
        + "\nYou are ExamSpark Cheat Sheet. Return JSON only: "
        '{"markdown":"...","formulas":["..."],"quick_facts":["..."],'
        '"mistakes":["..."],"memory_tricks":["..."]} '
        "One-page exam cheat sheet only — ultra compact, not a full essay."
    )
    parsed = await _chat_json(system, source, max_tokens=3072)
    md = (parsed.get("markdown") or "").strip()
    if len(md) < 40:
        raise QwenGenerationError("Cheat sheet returned too little content.")
    return parsed


async def _generate_memory_tricks(source: str) -> dict[str, Any]:
    from app.constants.visual_notes_prompt import STUDY_CONTENT_LANGUAGE_RULE
    from app.services.qwen_service import _chat_json

    system = (
        STUDY_CONTENT_LANGUAGE_RULE
        + "\nYou are ExamSpark Memory Tricks. Return JSON only: "
        '{"tricks":[{"trigger":"...","mnemonic":"...","why_it_works":"..."}],'
        '"markdown":"..."} '
        "Mnemonics / memory tricks ONLY — no full re-explanation of the topic."
    )
    parsed = await _chat_json(system, source, max_tokens=2048)
    tricks = parsed.get("tricks") or []
    if not isinstance(tricks, list) or len(tricks) < 2:
        raise QwenGenerationError("Memory tricks returned too few items.")
    return parsed


async def _run_generator(tool_type: str, source: str) -> dict[str, Any]:
    if tool_type == "flashcards":
        return await generate_flashcards(source)
    if tool_type == "quiz":
        return await generate_quiz_mcq(source)
    if tool_type == "revision":
        return await generate_revision_sheet(source)
    if tool_type == "five_min_revision":
        return await generate_five_min_revision(source)
    if tool_type == "important_questions":
        return await generate_important_questions(source)
    if tool_type == "mind_map":
        return await generate_mind_map(source)
    if tool_type == "learn_more":
        return await _generate_learn_more(source)
    if tool_type == "cheat_sheet":
        return await _generate_cheat_sheet(source)
    if tool_type == "memory_tricks":
        return await _generate_memory_tricks(source)
    raise HomeAiToolError(f"Unsupported tool: {tool_type}", status_code=400)


def list_tool_statuses(response_id: str, user_id: str) -> dict[str, Any]:
    master = get_home_ai_response(response_id, user_id)
    if not master:
        raise HomeAiToolError("Home AI response not found.", status_code=404)
    rows = list_tools_for_response(response_id, user_id)
    tools = {
        r["tool_type"]: {
            "status": r.get("status") or "ready",
            "has_payload": bool(r.get("payload_json")),
            "error_message": r.get("error_message"),
            "updated_at": r.get("updated_at"),
        }
        for r in rows
    }
    for t in VALID_TOOL_TYPES:
        tools.setdefault(t, {"status": "ready", "has_payload": False})
    knowledge = master.get("knowledge_json") or {}
    if not isinstance(knowledge, dict):
        knowledge = {}
    recommended = recommend_tool_types(knowledge, query=master.get("query") or "")
    return {
        "response_id": response_id,
        "query": master.get("query"),
        "tools": tools,
        "recommended": recommended,
        "chip_credits": 0,
    }


def get_tool_payload(
    response_id: str, user_id: str, tool_type: str
) -> dict[str, Any]:
    tool_type = _normalize_tool_type(tool_type)
    master = get_home_ai_response(response_id, user_id)
    if not master:
        raise HomeAiToolError("Home AI response not found.", status_code=404)
    row = get_tool_row(response_id, user_id, tool_type)
    if not row or row.get("status") != "generated" or not row.get("payload_json"):
        raise HomeAiToolError(
            "Tool not generated yet. POST to generate first.",
            status_code=404,
        )
    return {
        "response_id": response_id,
        "tool_type": tool_type,
        "status": "generated",
        "payload": row["payload_json"],
        "credits_charged": 0,
        "new_balance": _credits_balance(user_id),
        "cached": True,
    }


async def generate_or_get_tool(
    *,
    user_id: str,
    response_id: str,
    tool_type: str,
    regenerate: bool = False,
) -> dict[str, Any]:
    """Open chip: derive from Knowledge Object (0 credits, no AI).

    Regenerate: paid AI refresh of that tool only.
    """
    tool_type = _normalize_tool_type(tool_type)

    try:
        require_feature_unlocked(user_id, GatedFeature.ASK_AI)
    except FeatureLockedError as e:
        raise HomeAiToolError(
            str(e),
            status_code=403,
            detail=feature_locked_payload(e),
        ) from e

    master = get_home_ai_response(response_id, user_id)
    if not master:
        raise HomeAiToolError(
            "Home AI response not found. Run Phase 4C SQL migration if tables are missing.",
            status_code=404,
        )

    existing = get_tool_row(response_id, user_id, tool_type)
    # Old generic cache (pre smart-derive) has no "format" — refresh free once.
    if (
        not regenerate
        and existing
        and existing.get("status") == "generated"
        and existing.get("payload_json")
    ):
        payload = existing["payload_json"]
        if isinstance(payload, dict) and payload.get("format"):
            # Bad Visual chip cache: section-title boxes without real diagram
            if tool_type == "visual":
                fmt = payload.get("format")
                has_vp = bool(
                    payload.get("visual_payload") or payload.get("visualPayload")
                )
                if fmt in ("flow_boxes", "no_visual") or not has_vp:
                    clear_tool_for_regenerate(
                        response_id=response_id,
                        user_id=user_id,
                        tool_type=tool_type,
                    )
                    existing = None
                else:
                    return {
                        "response_id": response_id,
                        "tool_type": tool_type,
                        "status": "generated",
                        "payload": payload,
                        "credits_charged": 0,
                        "new_balance": _credits_balance(user_id),
                        "cached": True,
                    }
            else:
                return {
                    "response_id": response_id,
                    "tool_type": tool_type,
                    "status": "generated",
                    "payload": payload,
                    "credits_charged": 0,
                    "new_balance": _credits_balance(user_id),
                    "cached": True,
                }
        if existing is not None:
            # Legacy generic payload → clear row so re-derive can claim
            clear_tool_for_regenerate(
                response_id=response_id, user_id=user_id, tool_type=tool_type
            )
            existing = None

    # Stale after Knowledge V2 — re-derive free from current KO (no AI).
    if (
        not regenerate
        and existing
        and existing.get("status") == "stale"
    ):
        clear_tool_for_regenerate(
            response_id=response_id, user_id=user_id, tool_type=tool_type
        )
        existing = None

    if existing and existing.get("status") == "generating" and not regenerate:
        return {
            "response_id": response_id,
            "tool_type": tool_type,
            "status": "generating",
            "payload": None,
            "credits_charged": 0,
            "new_balance": _credits_balance(user_id),
            "cached": False,
        }

    amount = home_tool_credit_cost(tool_type, regenerate=regenerate)
    if amount > 0:
        balance = _credits_balance(user_id)
        if balance < amount:
            raise HomeAiToolError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    if regenerate and existing:
        clear_tool_for_regenerate(
            response_id=response_id, user_id=user_id, tool_type=tool_type
        )
    else:
        claimed = try_claim_generating(
            response_id=response_id, user_id=user_id, tool_type=tool_type
        )
        if (
            claimed
            and claimed.get("status") == "generated"
            and claimed.get("payload_json")
            and not regenerate
        ):
            return {
                "response_id": response_id,
                "tool_type": tool_type,
                "status": "generated",
                "payload": claimed["payload_json"],
                "credits_charged": 0,
                "new_balance": _credits_balance(user_id),
                "cached": True,
            }

    knowledge = master.get("knowledge_json") or {}
    if not isinstance(knowledge, dict):
        knowledge = {}
    meta = dict(knowledge.get("metadata") or {})
    meta.setdefault("query", master.get("query") or "")
    knowledge["metadata"] = meta
    if not knowledge.get("explanation") and master.get("answer"):
        knowledge["explanation"] = master["answer"][:4000]
    if not knowledge.get("visual_payload") and master.get("visual_payload_json"):
        knowledge["visual_payload"] = master.get("visual_payload_json")

    # Important Qs: PYQ metadata hints (weightage = chance bias). Soft-fail empty.
    pyq_matches: list = []
    if tool_type == "important_questions":
        try:
            q = (master.get("query") or "").strip()
            if not q:
                q = str((knowledge.get("metadata") or {}).get("query") or "").strip()
            if not q:
                q = str(knowledge.get("summary") or "topic").strip()
            pyq_matches = await match_pyqs_for_query(q, limit=5)
        except Exception as e:  # noqa: BLE001
            logger.warning("Important Qs PYQ match skipped: %s", e)
            pyq_matches = []
        if pyq_matches:
            knowledge["exam_focus"] = pyq_matches

    # --- Founder lock: first open = derive from KO (no AI, 0 credits) ---
    if not regenerate:
        try:
            payload = derive_tool_payload(tool_type, knowledge)
        except Exception as e:
            mark_tool_failed(
                response_id=response_id,
                user_id=user_id,
                tool_type=tool_type,
                error_message=str(e),
            )
            raise HomeAiToolError(
                f"Could not build {tool_type} from Knowledge Object: {e}",
                status_code=502,
            ) from e

        try:
            from app.services.supabase_admin import get_supabase_admin

            get_supabase_admin().table("home_ai_tools").update(
                {
                    "status": "generated",
                    "payload_json": payload,
                    "error_message": None,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            ).eq("response_id", response_id).eq("user_id", user_id).eq(
                "tool_type", tool_type
            ).execute()
        except Exception:
            mark_tool_generated(
                response_id=response_id,
                user_id=user_id,
                tool_type=tool_type,
                payload=payload,
            )

        return {
            "response_id": response_id,
            "tool_type": tool_type,
            "status": "generated",
            "payload": payload,
            "credits_charged": 0,
            "new_balance": _credits_balance(user_id),
            "cached": False,
            "derived": True,
        }

    # --- Explicit Regenerate: paid AI ---
    source = knowledge_to_source_text(knowledge)
    if len(source) < 40:
        source = (
            f"Topic / Question:\n{master.get('query') or ''}\n\n"
            f"Answer:\n{(master.get('answer') or '')[:2500]}"
        )
    focus_block = format_exam_focus_block(pyq_matches)
    if focus_block:
        source = f"{source}\n\n{focus_block}"

    try:
        if tool_type == "visual":
            payload = derive_tool_payload("visual", knowledge)
        else:
            payload = await _run_generator(tool_type, source)
        if (
            tool_type == "important_questions"
            and isinstance(payload, dict)
            and pyq_matches
        ):
            # Keep student-facing focus tags (no similarity numbers).
            from app.services.pyq_retrieve import format_exam_focus_line

            payload.setdefault(
                "exam_focus",
                [
                    format_exam_focus_line(m).replace("Focus: ", "")
                    for m in pyq_matches
                    if isinstance(m, dict)
                ],
            )
    except QwenGenerationError as e:
        mark_tool_failed(
            response_id=response_id,
            user_id=user_id,
            tool_type=tool_type,
            error_message=str(e),
        )
        raise HomeAiToolError(str(e), status_code=502) from e
    except Exception as e:
        mark_tool_failed(
            response_id=response_id,
            user_id=user_id,
            tool_type=tool_type,
            error_message=str(e),
        )
        raise HomeAiToolError(
            f"Tool generation failed: {e}", status_code=502
        ) from e

    new_balance = _credits_balance(user_id)
    if amount > 0:
        try:
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Home AI tool regenerate: {tool_type}",
                lecture_id=master.get("lecture_id"),
                action=f"home_ai_tool_regen_{tool_type}",
            )
        except InsufficientCreditsError as e:
            mark_tool_failed(
                response_id=response_id,
                user_id=user_id,
                tool_type=tool_type,
                error_message=str(e),
            )
            raise HomeAiToolError(str(e), status_code=402) from e

    try:
        from app.services.supabase_admin import get_supabase_admin

        get_supabase_admin().table("home_ai_tools").update(
            {
                "status": "generated",
                "payload_json": payload,
                "error_message": None,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("response_id", response_id).eq("user_id", user_id).eq(
            "tool_type", tool_type
        ).execute()
    except Exception:
        mark_tool_generated(
            response_id=response_id,
            user_id=user_id,
            tool_type=tool_type,
            payload=payload,
        )

    return {
        "response_id": response_id,
        "tool_type": tool_type,
        "status": "generated",
        "payload": payload,
        "credits_charged": amount,
        "new_balance": new_balance,
        "cached": False,
        "derived": False,
    }
