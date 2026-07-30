"""Credit allocation after verified payment — plan package or pack only."""
from uuid import UUID

from app.constants.payment_catalog import credits_for_pack, credits_for_plan
from app.models.payment import AllocateCreditsRequest
from app.services.credits_service import grant_credits
from app.services.supabase_admin import get_supabase_admin


class CreditAllocator:
    """Allocate credits and log credit_history (idempotent by key)."""

    async def allocate_monthly_credits(
        self,
        user_id: UUID,
        plan_id: str,
        payment_id: UUID,
        idempotency_key: str,
    ) -> int:
        amount = credits_for_plan(plan_id)
        if amount <= 0:
            return 0
        return await self._grant_once(
            user_id=user_id,
            amount=amount,
            source="subscription_monthly",
            payment_id=payment_id,
            idempotency_key=idempotency_key,
            description=f"Plan {plan_id} monthly credits",
            action="subscription_monthly",
        )

    async def allocate_pack_credits(
        self,
        request: AllocateCreditsRequest,
        *,
        pack_id: str | None = None,
        payment_id: UUID | None = None,
    ) -> int:
        amount = request.credits
        if pack_id:
            amount = credits_for_pack(pack_id) or amount
        if amount <= 0:
            return 0
        return await self._grant_once(
            user_id=request.user_id,
            amount=amount,
            source="credit_pack",
            payment_id=payment_id or request.payment_id,
            idempotency_key=request.idempotency_key,
            description=f"Credit pack {pack_id or 'unknown'}",
            action="credit_pack",
        )

    async def _grant_once(
        self,
        *,
        user_id: UUID,
        amount: int,
        source: str,
        payment_id: UUID | None,
        idempotency_key: str,
        description: str,
        action: str,
    ) -> int:
        client = get_supabase_admin()
        existing = (
            client.table("credit_history")
            .select("delta, balance_after")
            .eq("idempotency_key", idempotency_key)
            .limit(1)
            .execute()
        )
        if existing.data:
            return int(existing.data[0].get("delta") or amount)

        balance_after = grant_credits(
            user_id=str(user_id),
            amount=amount,
            description=description,
            action=action,
        )

        row = {
            "user_id": str(user_id),
            "delta": amount,
            "balance_after": balance_after,
            "source": source,
            "payment_id": str(payment_id) if payment_id else None,
            "idempotency_key": idempotency_key,
            "description": description,
        }
        client.table("credit_history").insert(row).execute()
        return amount
