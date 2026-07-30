"""Home AI photo/diagram → chat answer (not Study Workspace lecture).

Uses Qwen3-VL like Diagram/Image, then formats a Home Study Coach reply,
persists Phase 4C Knowledge Object when SQL is present, charges HOME_AI_VISION (10).
"""
from __future__ import annotations

import logging
from typing import Any

from app.constants.ai_response_status import SUCCESS
from app.constants.credit_costs import HOME_AI_VISION
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.home_ai_knowledge import build_knowledge_object
from app.services.home_ai_response_store import persist_home_ai_response
from app.services.home_ai_session_service import ensure_session_for_turn
from app.services.home_ai_service import HomeAiError
from app.services.rag_ask_service import _credits_balance
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.qwen_vision_service import QwenVisionError, analyze_image

logger = logging.getLogger(__name__)

_MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB


def _format_home_vision_answer(notes: dict[str, Any], *, query: str) -> str:
    clean = (notes.get("cleanNotes") or "").strip()
    summary = (notes.get("shortSummary") or "").strip()
    key_points = notes.get("keyPoints") or []
    terms = notes.get("importantTerms") or []

    parts: list[str] = []
    first_para = clean.split("\n\n")[0][:500] if clean else ""
    direct = summary or first_para

    parts.append("## Direct Answer")
    if direct:
        parts.append(direct)
    else:
        parts.append("I analyzed your photo. See the explanation below.")

    if query.strip():
        parts.append(f"\n*(Your ask: {query.strip()[:200]})*")

    # Easy Explanation — only when clean adds real value beyond Direct Answer
    if clean:
        if summary and clean != summary:
            parts.append("\n## Easy Explanation")
            parts.append(clean)
        elif not summary and len(clean) > len(first_para) + 60:
            parts.append("\n## Easy Explanation")
            parts.append(clean)

    if isinstance(key_points, list) and key_points:
        bullets = [str(kp).strip() for kp in key_points[:10] if str(kp).strip()]
        if bullets:
            parts.append("\n## Key Points")
            for s in bullets:
                parts.append(f"- {s}")

    if isinstance(terms, list) and terms:
        term_lines: list[str] = []
        for t in terms[:8]:
            if isinstance(t, dict):
                term = (t.get("term") or "").strip()
                definition = (t.get("definition") or "").strip()
                if term and definition:
                    term_lines.append(f"- **{term}**: {definition}")
                elif term:
                    term_lines.append(f"- {term}")
            else:
                s = str(t).strip()
                if s:
                    term_lines.append(f"- {s}")
        if term_lines:
            parts.append("\n## Important Terms")
            parts.extend(term_lines)

    # No forced Exam Tip filler — omit low-value boilerplate
    return "\n".join(parts).strip()


async def home_ai_vision(
    user_id: str,
    image_bytes: bytes,
    *,
    filename: str | None = None,
    mime_type: str | None = None,
    query: str | None = None,
) -> dict[str, Any]:
    """Photo/diagram → Home chat answer. Does not create a lecture."""
    if not image_bytes:
        raise HomeAiError("No image received.", status_code=400)
    if len(image_bytes) > _MAX_IMAGE_BYTES:
        raise HomeAiError(
            "Image too large (max 8 MB). Try a smaller photo.",
            status_code=400,
        )

    try:
        require_feature_unlocked(user_id, GatedFeature.DIAGRAM_ANALYSIS)
    except FeatureLockedError as e:
        raise HomeAiError(
            str(e),
            status_code=403,
            result_status="FEATURE_LOCKED",
            detail=feature_locked_payload(e),
        ) from e

    balance = _credits_balance(user_id)
    if balance < HOME_AI_VISION:
        raise HomeAiError(
            f"Need {HOME_AI_VISION} credits for Photo / Image Ask.",
            status_code=402,
            result_status="INSUFFICIENT_CREDITS",
            detail={
                "status": "INSUFFICIENT_CREDITS",
                "required": HOME_AI_VISION,
                "balance": balance,
            },
        )

    hint = (query or "").strip() or (
        "Explain this educational photo/diagram for a student: what it shows, "
        "key concepts, and exam-ready notes."
    )
    display_query = (query or "").strip() or "Explain this photo / diagram"

    try:
        vision = await analyze_image(
            image_bytes,
            filename=filename,
            mime_type=mime_type,
            text_hint=hint,
        )
    except QwenVisionError as e:
        raise HomeAiError(
            f"Could not analyze image: {e}",
            status_code=502,
            result_status="API_ERROR",
        ) from e

    notes = vision.notes or {}
    answer = _format_home_vision_answer(notes, query=display_query)
    if not answer.strip():
        raise HomeAiError(
            "Image analysis returned empty notes. Try a clearer photo.",
            status_code=502,
            result_status="API_ERROR",
        )

    visual_payload = notes.get("visualPayload") or notes.get("visual_payload")
    if not isinstance(visual_payload, dict):
        visual_payload = None

    try:
        new_balance = deduct_credits(
            user_id=user_id,
            amount=HOME_AI_VISION,
            description="Home AI Photo / Image",
            action="home_ai_vision",
        )
    except InsufficientCreditsError as e:
        raise HomeAiError(
            str(e),
            status_code=402,
            result_status="INSUFFICIENT_CREDITS",
        ) from e

    knowledge = build_knowledge_object(
        query=display_query,
        answer=answer,
        visual_payload=visual_payload,
        answer_source="VISION",
        confidence="HIGH",
    )
    knowledge.setdefault("metadata", {})
    if isinstance(knowledge["metadata"], dict):
        knowledge["metadata"]["source"] = "home_ai_vision"
        knowledge["metadata"]["used_vision_plus"] = vision.used_plus

    rid = persist_home_ai_response(
        user_id=user_id,
        query=display_query,
        answer=answer,
        knowledge_json=knowledge,
        visual_payload=visual_payload,
        answer_source="VISION",
        confidence="HIGH",
        conversation_language=None,
        lecture_id=None,
        parent_response_id=None,
        knowledge_version=1,
    )

    session_id = None
    if rid:
        session_id = ensure_session_for_turn(
            user_id=user_id,
            query=display_query,
            answer=answer,
            response_id=rid,
            credits_used=HOME_AI_VISION,
            session_id=None,
            parent_response_id=None,
            conversation_language=None,
        )

    return {
        "answer": answer,
        "status": SUCCESS,
        "answer_source": "VISION",
        "confidence": "HIGH",
        "conversation_language": None,
        "sources": [{"source_type": "vision", "excerpt": "Photo / diagram"}],
        "credits_charged": HOME_AI_VISION,
        "new_balance": new_balance,
        "mode": "normal",
        "visual_payload": visual_payload,
        "response_id": rid,
        "session_id": session_id,
        "knowledge": {
            "summary": knowledge.get("summary"),
            "key_points": knowledge.get("key_points"),
            "formulas": knowledge.get("formulas"),
            "knowledge_version": 1,
        },
    }
