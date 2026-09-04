"""Home AI photo/diagram → chat answer (not Study Workspace lecture).

Uses Qwen3-VL like Diagram/Image, then formats a Home Study Coach reply,
persists Phase 4C Knowledge Object when SQL is present, charges HOME_AI_VISION (10).
"""
from __future__ import annotations

import logging
import uuid
from typing import Any

from app.constants.ai_response_status import SUCCESS
from app.constants.credit_costs import HOME_AI_VISION
from app.services.credits_service import (
    InsufficientCreditsError,
    deduct_credits,
    get_credits_balance as _credits_balance,
)
from app.services.home_ai_knowledge import build_knowledge_object
from app.services.home_ai_response_store import persist_home_ai_response
from app.services.home_ai_session_service import ensure_session_for_turn
from app.services.home_ai_service import HomeAiError
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.home_ai_vision_model_service import analyze_image_with_fallback
from app.services.r2_storage_service import R2StorageService

logger = logging.getLogger(__name__)

_MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB


_QUESTION_TYPES = {"question_paper", "handwritten_work"}
_NOTES_TYPES = {"notes", "textbook", "document"}


def _format_home_vision_answer(notes: dict[str, Any], *, query: str) -> str:
    """Pedagogical formatter with OCR Perception & Intention Understanding."""
    content_type = (notes.get("contentType") or "other").strip().lower()
    intent = (notes.get("detectedIntent") or "solve_problem").strip().lower()
    recognized_topic = (notes.get("recognizedTopic") or "").strip()
    student_attempt = notes.get("studentAttempt") if isinstance(notes.get("studentAttempt"), dict) else None
    clean = (notes.get("cleanNotes") or "").strip()
    summary = (notes.get("shortSummary") or "").strip()
    key_points = notes.get("keyPoints") or []
    terms = notes.get("importantTerms") or []
    questions_found = notes.get("questionsFound") or []
    extracted = (notes.get("extractedText") or "").strip()

    parts: list[str] = []

    # 1. OCR Context Pill / Badge
    topic_pill = recognized_topic
    if not topic_pill and questions_found:
        topic_pill = str(questions_found[0])[:90].strip()
    if not topic_pill and summary:
        topic_pill = summary[:80].strip()
    if topic_pill:
        parts.append(f"> 📌 **Recognized:** {topic_pill}\n")

    if query.strip():
        parts.append(f"*(Your ask: {query.strip()[:200]})*\n")

    # 2. Intention: Student Attempt / Error Diagnosis
    if intent == "diagnose_error" or (student_attempt and student_attempt.get("attemptFound")):
        parts.append("### 🔍 Your Attempt Review")
        correct_steps = student_attempt.get("correctSteps") if student_attempt else []
        error_step = student_attempt.get("errorStep") if student_attempt else None
        advice = student_attempt.get("advice") if student_attempt else None

        if correct_steps:
            parts.append("**What you did right:**")
            for cs in correct_steps:
                parts.append(f"- ✅ {cs}")
        if error_step:
            parts.append(f"**Where the mistake happened:**\n- ⚠️ {error_step}")
        if advice:
            parts.append(f"💡 *Tip: {advice}*")

        parts.append("\n### 💡 Correct Step-by-Step Solution")
        parts.append(clean or summary or "See the correct working below.")
        return "\n".join(parts).strip()

    # 3. Intention: Question Paper / Problem Solving / Multi-Question
    if intent in ("solve_problem", "multi_question") or content_type in _QUESTION_TYPES or questions_found:
        if clean:
            parts.append(clean)
        elif extracted:
            parts.append(
                "I can see the following in the image:\n\n"
                f"{extracted}\n\n"
                "Could not generate full solutions — please retry with a clearer photo."
            )
        else:
            parts.append(summary or "I analyzed your photo. See the key points below.")

        if len(questions_found) > 1:
            remaining = [str(q).strip() for q in questions_found[1:4] if str(q).strip()]
            if remaining:
                parts.append("\n---")
                parts.append("*💡 Other questions detected on this page:*")
                for idx, q in enumerate(remaining, start=2):
                    parts.append(f"- **Q{idx}:** {q}")
                parts.append("\n*Tap the suggestion chips below to solve any of them!*")

        if key_points:
            bullets = [str(kp).strip() for kp in key_points[:8] if str(kp).strip()]
            if bullets:
                parts.append("\n**Key Points:**")
                for s in bullets:
                    parts.append(f"- {s}")
        return "\n".join(parts).strip()

    # 4. Intention: Diagram / Conceptual Explanation
    if intent == "explain_concept" or content_type == "diagram":
        parts.append("## What This Diagram Shows")
        parts.append(summary or clean or "I analyzed this diagram. See details below.")
        if key_points:
            bullets = [str(kp).strip() for kp in key_points[:8] if str(kp).strip()]
            if bullets:
                parts.append("\n## Key Points")
                for s in bullets:
                    parts.append(f"- {s}")
        return "\n".join(parts).strip()

    # 5. Intention: Notes / Summarize
    first_para = clean.split("\n\n")[0][:500] if clean else ""
    direct = summary or first_para

    parts.append("## Direct Answer")
    if direct:
        parts.append(direct)
    else:
        parts.append("I analyzed your photo. See the explanation below.")

    if clean and ((summary and clean != summary) or (not summary and len(clean) > len(first_para) + 60)):
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

    return "\n".join(parts).strip()


async def home_ai_vision(
    user_id: str,
    image_bytes: bytes,
    *,
    filename: str | None = None,
    mime_type: str | None = None,
    query: str | None = None,
    session_id: str | None = None,
    parent_response_id: str | None = None,
    vision_model: str = "qwen-vl",
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

    user_q = (query or "").strip()
    if user_q:
        hint = (
            f"User's request: {user_q}\n\n"
            "Analyze this image in full context of the user's request above. "
            "If the image contains questions or problems, answer them directly and completely. "
            "If the user asks to explain, explain clearly. "
            "Extract and use all readable text, numbers, diagrams, and labels from the image. "
            "Answer in the same language as the user's request."
        )
    else:
        hint = (
            "Analyze this image carefully. "
            "Identify what it contains: question paper, notes, diagram, textbook, or other. "
            "If there are questions or problems, answer them directly. "
            "Extract all readable text and explain what the image shows. "
            "Do not invent text, objects, or context not visible in the image. "
            "Use the dominant language of the readable content."
        )
    display_query = user_q

    try:
        vision = await analyze_image_with_fallback(
            image_bytes,
            filename=filename,
            mime_type=mime_type,
            text_hint=hint,
            selected_model=vision_model,
            user_id=user_id,
        )
    except Exception as e:
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
    if visual_payload is None:
        from app.services.visual_fallback import fallback_visual_payload
        visual_payload = fallback_visual_payload(
            display_query or (notes.get("recognizedTopic") or ""),
            answer,
        )

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

    extracted_text = (notes.get("extractedText") or "").strip()
    content_type = (notes.get("contentType") or "other").strip()
    questions_found = notes.get("questionsFound") or []

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
        knowledge["metadata"]["content_type"] = content_type
        if extracted_text:
            knowledge["metadata"]["extracted_text"] = extracted_text[:1200]
        if questions_found:
            knowledge["metadata"]["questions_found"] = questions_found[:10]

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

    # Build memory message: prefix extracted text so follow-up questions
    # can reference exact image content (questions, text, labels).
    memory_message = answer
    if extracted_text:
        memory_message = (
            f"[Image content ({content_type}): {extracted_text[:800]}]\n\n{answer}"
        )

    result_session_id = None
    if rid:
        image_path = R2StorageService().chat_image_path(
            "home-chat", user_id, str(uuid.uuid4()), filename=filename
        )
        R2StorageService().upload_bytes(image_path, image_bytes, mime_type or "image/jpeg")
        result_session_id = ensure_session_for_turn(
            user_id=user_id,
            query=display_query,
            answer=memory_message,
            response_id=rid,
            credits_used=HOME_AI_VISION,
            session_id=session_id,
            parent_response_id=parent_response_id,
            conversation_language=None,
            image_path=image_path,
        )

    suggested_questions: list[str] = []
    if len(questions_found) > 1:
        suggested_questions = [
            f"Solve: {str(q).strip()[:80]}"
            for q in questions_found[1:4]
            if str(q).strip()
        ]

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
        "suggested_questions": suggested_questions,
        "response_id": rid,
        "session_id": result_session_id,
        "model_name": getattr(vision, "model_name", ""),
        "knowledge": {
            "summary": knowledge.get("summary"),
            "key_points": knowledge.get("key_points"),
            "formulas": knowledge.get("formulas"),
            "knowledge_version": 1,
        },
    }
