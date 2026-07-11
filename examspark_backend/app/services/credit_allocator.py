"""Credit allocation after verified payment."""
from uuid import UUID

from app.models.payment import AllocateCreditsRequest


class CreditAllocator:
    """Allocate monthly credits and log credit_history."""

    async def allocate_monthly_credits(
        self,
        user_id: UUID,
        plan_id: str,
        payment_id: UUID,
        idempotency_key: str,
    ) -> int:
        # TODO: Query subscription_plans for monthly_credits; update users.credits_balance
        # TODO: Insert credit_history row
        plan_credits = _plan_monthly_credits(plan_id)
        return plan_credits

    async def allocate_pack_credits(
        self,
        request: AllocateCreditsRequest,
    ) -> int:
        # TODO: credit_packs lookup; add to users.credits_balance; credit_history
        return request.credits


def _plan_monthly_credits(plan_id: str) -> int:
    credits_map = {
        "free": 50,
        "plan_199": 1300,
        "plan_299": 1300,  # legacy alias — same tier as plan_199
        "plan_499": 3500,
        "plan_999": 8000,
        "teacher": 20000,
    }
    return credits_map.get(plan_id, 0)
