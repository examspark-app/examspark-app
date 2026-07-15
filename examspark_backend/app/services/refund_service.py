"""Refund handler — honour store/Razorpay refunds (idempotent).

Does NOT refund money itself. Marks payment refunded, cancels subscription,
best-effort credit clawback. See REFUND_POLICY_AND_PROCESS.md.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)


class RefundNotFoundError(Exception):
    pass


class RefundService:
    async def process_refund(
        self,
        *,
        payment_id: str | None = None,
        gateway_payment_id: str | None = None,
        order_id: str | None = None,
        reason: str = "gateway_refund",
    ) -> dict[str, Any]:
        client = get_supabase_admin()
        payment = self._load_payment(
            client,
            payment_id=payment_id,
            gateway_payment_id=gateway_payment_id,
            order_id=order_id,
        )
        if not payment:
            raise RefundNotFoundError(
                "Payment not found for refund "
                f"(payment_id={payment_id}, gateway_payment_id={gateway_payment_id}, "
                f"order_id={order_id})"
            )

        if payment.get("status") == "refunded":
            return {
                "status": "already_refunded",
                "order_id": payment.get("order_id"),
                "payment_id": payment.get("id"),
                "idempotent": True,
            }

        payment_uuid = str(payment["id"])
        user_id = str(payment["user_id"])
        meta = dict(payment.get("metadata") or {})
        credits_to_claw = int(meta.get("credits_allocated") or 0)
        now = datetime.now(timezone.utc).isoformat()

        client.table("payments").update({"status": "refunded"}).eq(
            "id", payment_uuid
        ).execute()

        client.table("payment_transactions").insert(
            {
                "payment_id": payment_uuid,
                "user_id": user_id,
                "type": "refund",
                "amount_paise": payment.get("amount_paise") or 0,
                "currency": payment.get("currency") or "INR",
                "status": "refunded",
            }
        ).execute()

        cancelled_subs = 0
        if payment.get("plan_id") and not payment.get("credit_pack_id"):
            cancelled_subs = self._cancel_active_subscriptions(client, user_id)

        clawed = 0
        if credits_to_claw > 0:
            clawed = self._clawback_credits(user_id, credits_to_claw, payment_uuid)

        # After plan cancel → Free (0 groups): leave all / trim to new max.
        groups_left = 0
        if cancelled_subs > 0 or (
            payment.get("plan_id") and not payment.get("credit_pack_id")
        ):
            groups_left = self._trim_group_memberships(user_id)

        meta["refunded_at"] = now
        meta["refund_reason"] = reason
        meta["credits_clawed_back"] = clawed
        meta["groups_left_after_trim"] = groups_left
        client.table("payments").update({"metadata": meta}).eq(
            "id", payment_uuid
        ).execute()

        client.table("payment_logs").insert(
            {
                "payment_id": payment_uuid,
                "user_id": user_id,
                "level": "info",
                "event": "payment_refunded",
                "payload": {
                    "reason": reason,
                    "credits_clawed": clawed,
                    "subscriptions_cancelled": cancelled_subs,
                    "groups_left": groups_left,
                },
            }
        ).execute()

        return {
            "status": "refunded",
            "order_id": payment.get("order_id"),
            "payment_id": payment_uuid,
            "credits_clawed": clawed,
            "subscriptions_cancelled": cancelled_subs,
            "groups_left": groups_left,
            "idempotent": False,
        }

    def _load_payment(
        self,
        client: Any,
        *,
        payment_id: str | None,
        gateway_payment_id: str | None,
        order_id: str | None,
    ) -> dict[str, Any] | None:
        if payment_id:
            row = (
                client.table("payments")
                .select("*")
                .eq("id", payment_id)
                .limit(1)
                .execute()
            )
            if row.data:
                return row.data[0]
        if gateway_payment_id:
            row = (
                client.table("payments")
                .select("*")
                .eq("gateway_payment_id", gateway_payment_id)
                .limit(1)
                .execute()
            )
            if row.data:
                return row.data[0]
        if order_id:
            row = (
                client.table("payments")
                .select("*")
                .eq("order_id", order_id)
                .limit(1)
                .execute()
            )
            if row.data:
                return row.data[0]
        return None

    def _cancel_active_subscriptions(self, client: Any, user_id: str) -> int:
        now = datetime.now(timezone.utc).isoformat()
        active = (
            client.table("user_subscriptions")
            .select("id")
            .eq("user_id", user_id)
            .eq("status", "active")
            .execute()
        )
        count = 0
        for row in active.data or []:
            client.table("user_subscriptions").update(
                {"status": "cancelled", "updated_at": now}
            ).eq("id", row["id"]).execute()
            count += 1
        return count

    def _trim_group_memberships(self, user_id: str) -> int:
        """Leave groups beyond new plan max via fn_trim_group_memberships."""
        client = get_supabase_admin()
        try:
            response = client.rpc(
                "fn_trim_group_memberships",
                {"p_user_id": user_id},
            ).execute()
            data = response.data
            if isinstance(data, int):
                return data
            if data is None:
                return 0
            return int(data)
        except Exception:  # noqa: BLE001
            logger.exception("Group membership trim failed user=%s", user_id)
            return 0

    def _clawback_credits(
        self, user_id: str, credits_allocated: int, payment_id: str
    ) -> int:
        """Deduct min(allocated, current balance). Never invents negative without RPC."""
        client = get_supabase_admin()
        try:
            bal_row = (
                client.table("users")
                .select("credits_balance")
                .eq("id", user_id)
                .single()
                .execute()
            )
            balance = int((bal_row.data or {}).get("credits_balance") or 0)
        except Exception:  # noqa: BLE001
            logger.exception("Could not read balance for clawback user=%s", user_id)
            return 0

        amount = min(credits_allocated, balance)
        if amount <= 0:
            return 0

        try:
            balance_after = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Refund clawback payment {payment_id}",
                action="refund",
            )
            client.table("credit_history").insert(
                {
                    "user_id": user_id,
                    "delta": -amount,
                    "balance_after": balance_after,
                    "source": "refund",
                    "payment_id": payment_id,
                    "idempotency_key": f"refund_claw_{payment_id}",
                    "description": f"Clawback after refund ({amount} credits)",
                }
            ).execute()
            return amount
        except InsufficientCreditsError:
            logger.warning(
                "Clawback skipped insufficient credits user=%s want=%s",
                user_id,
                amount,
            )
            return 0
        except Exception:  # noqa: BLE001
            logger.exception("Clawback failed user=%s", user_id)
            return 0
