from unittest.mock import patch

import pytest

from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    require_feature_unlocked,
)


@pytest.mark.parametrize("plan", ["plan_499", "plan_999"])
def test_claude_is_available_on_student_premium_plans(plan):
    with patch(
        "app.services.plan_tier_service.get_user_plan_tier",
        return_value=plan,
    ):
        assert require_feature_unlocked("user-1", GatedFeature.PREMIUM_CHAT_MODEL) == plan


@pytest.mark.parametrize("plan", ["free", "plan_199", "teacher"])
def test_claude_is_blocked_without_eligible_student_plan(plan):
    with patch(
        "app.services.plan_tier_service.get_user_plan_tier",
        return_value=plan,
    ):
        with pytest.raises(FeatureLockedError):
            require_feature_unlocked("user-1", GatedFeature.PREMIUM_CHAT_MODEL)
