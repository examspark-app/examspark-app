"""Server-side plan-tier gating — Rule 6: check unlock BEFORE credits.

Mirrors examspark_frontend/lib/core/constants/plan_tier_gating.dart.
Uses Postgres `fn_user_plan_tier` (schema.sql). Full Session 5 polish can
expand this; vision/recording endpoints must already enforce here.
"""
from __future__ import annotations

from enum import Enum


class GatedFeature(str, Enum):
    ASK_AI = "ask_ai"
    PDF_ANALYSIS = "pdf_analysis"
    DIAGRAM_ANALYSIS = "diagram_analysis"
    RECORD_LECTURE = "record_lecture"


# CREDIT_ECONOMY.md: Free gets PDF text-only; Photo/Diagram needs ₹199+.
_MINIMUM_PLAN: dict[GatedFeature, str] = {
    GatedFeature.ASK_AI: "free",
    GatedFeature.PDF_ANALYSIS: "free",
    GatedFeature.DIAGRAM_ANALYSIS: "plan_199",
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


class FeatureLockedError(Exception):
    def __init__(self, feature: GatedFeature, current_plan: str, required_plan: str):
        self.feature = feature
        self.current_plan = current_plan
        self.required_plan = required_plan
        super().__init__(
            f"Feature locked: {feature.value} requires {required_plan}+ "
            f"(current plan: {current_plan})."
        )


def _rank(plan_id: str) -> int:
    try:
        return _PLAN_RANK.index(plan_id)
    except ValueError:
        return 0


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
