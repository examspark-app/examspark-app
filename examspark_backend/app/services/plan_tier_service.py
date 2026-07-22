"""Server-side plan-tier gating — Rule 6: check unlock BEFORE credits.

Mirrors examspark_frontend/lib/core/constants/plan_tier_gating.dart.
Uses Postgres `fn_user_plan_tier` (schema.sql).

Founder Jul 15, 2026: Free = credit pool; audio record/upload needs ₹499+.
"""
from __future__ import annotations

from enum import Enum
from typing import Any


class GatedFeature(str, Enum):
    ASK_AI = "ask_ai"
    PDF_ANALYSIS = "pdf_analysis"
    DIAGRAM_ANALYSIS = "diagram_analysis"
    YOUTUBE_LINK = "youtube_link"
    RECORD_LECTURE = "record_lecture"
    FLASHCARDS = "flashcards"
    QUIZ = "quiz"
    REVISION = "revision"
    IMPORTANT_QUESTIONS = "important_questions"
    MIND_MAP = "mind_map"


# Free monthly credits; Ask/PDF/Photo/YouTube = credits. Audio record/upload = ₹499+.
_MINIMUM_PLAN: dict[GatedFeature, str] = {
    GatedFeature.ASK_AI: "free",
    GatedFeature.PDF_ANALYSIS: "free",
    GatedFeature.DIAGRAM_ANALYSIS: "free",
    GatedFeature.YOUTUBE_LINK: "free",
    GatedFeature.FLASHCARDS: "free",
    GatedFeature.QUIZ: "free",
    GatedFeature.REVISION: "free",
    GatedFeature.IMPORTANT_QUESTIONS: "free",
    GatedFeature.MIND_MAP: "free",
    GatedFeature.RECORD_LECTURE: "plan_499",
}

_PLAN_RANK = [
    "free",
    "plan_199",
    "plan_299",
    "plan_499",
    "plan_999",
    "teacher",
]

_PLAN_LABEL = {
    "free": "Free",
    "plan_199": "₹199",
    "plan_299": "₹299",
    "plan_499": "₹499",
    "plan_999": "₹999",
    "teacher": "Teacher",
}


class FeatureLockedError(Exception):
    def __init__(self, feature: GatedFeature, current_plan: str, required_plan: str):
        self.feature = feature
        self.current_plan = current_plan
        self.required_plan = required_plan
        super().__init__(lock_user_message(feature, required_plan))


def _rank(plan_id: str) -> int:
    try:
        return _PLAN_RANK.index(plan_id)
    except ValueError:
        return 0


def lock_user_message(feature: GatedFeature, required_plan: str) -> str:
    """Student-facing lock copy (aligned with Flutter PlanTierGating.lockMessage)."""
    label = _PLAN_LABEL.get(required_plan, required_plan)
    if feature == GatedFeature.RECORD_LECTURE:
        return (
            "This feature needs the ₹499+ Plan. "
            "Audio recording and audio upload unlock from the ₹499 Plan."
        )
    if feature == GatedFeature.PDF_ANALYSIS:
        return "PDF Analysis is available on Free and all paid plans (uses credits)."
    if feature in (
        GatedFeature.DIAGRAM_ANALYSIS,
        GatedFeature.YOUTUBE_LINK,
        GatedFeature.FLASHCARDS,
        GatedFeature.QUIZ,
        GatedFeature.REVISION,
        GatedFeature.IMPORTANT_QUESTIONS,
        GatedFeature.MIND_MAP,
        GatedFeature.ASK_AI,
    ):
        return "Available on Free and all paid plans (uses credits)."
    return f"Feature locked. Upgrade to {label}+ to continue."


def feature_locked_payload(exc: FeatureLockedError) -> dict[str, Any]:
    """HTTP 403 detail — Flutter reads detail.message / detail.code."""
    return {
        "code": "FEATURE_LOCKED",
        "status": "FEATURE_LOCKED",
        "message": str(exc),
        "feature": exc.feature.value,
        "current_plan": exc.current_plan,
        "required_plan": exc.required_plan,
    }


def get_user_plan_tier(user_id: str) -> str:
    # Lazy import so unit tests of gating logic don't require supabase installed.
    from app.services.supabase_admin import get_supabase_admin

    client = get_supabase_admin()
    response = client.rpc("fn_user_plan_tier", {"p_user_id": user_id}).execute()
    return response.data or "free"


def require_feature_unlocked(user_id: str, feature: GatedFeature) -> str:
    """Returns current plan tier. Raises FeatureLockedError if locked."""
    current = get_user_plan_tier(user_id)
    required = _MINIMUM_PLAN[feature]
    if _rank(current) < _rank(required):
        raise FeatureLockedError(feature, current, required)
    return current
