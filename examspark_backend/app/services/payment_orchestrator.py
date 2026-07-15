"""Payment orchestration — order → pending → verify → activate → credits."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from app.config import PaymentConfig
from app.constants.payment_catalog import (
    credits_for_pack,
    credits_for_plan,
    resolve_amount_paise,
)
from app.models.payment import (
    AllocateCreditsRequest,
    CreateOrderRequest,
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
    SubscriptionStatus,
    VerifyPaymentRequest,
    VerifyPaymentResponse,
)
from app.services.credit_allocator import CreditAllocator
from app.services.gateways.google_play_gateway import GooglePlayGateway
from app.services.gateways.phonepe_gateway import PhonePeGateway
from app.services.gateways.razorpay_gateway import RazorpayGateway
from app.services.security import PaymentSecurity
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)


class PaymentOrchestrator:
    """
    Flow:
    User → Choose Plan/Pack → Create Order → Checkout → Verify
         → Activate Subscription (if plan) → Allocate Credits → Store Transaction
    """

    def __init__(self) -> None:
        self._razorpay = RazorpayGateway()
        self._phonepe = PhonePeGateway()
        self._google_play = GooglePlayGateway()
        self._credits = CreditAllocator()

    def _gateway_for(self, gateway: PaymentGateway):
        return {
            PaymentGateway.RAZORPAY: self._razorpay,
            PaymentGateway.PHONEPE: self._phonepe,
            PaymentGateway.GOOGLE_PLAY: self._google_play,
        }[gateway]

    def _validate_platform_gateway(
        self, platform: PaymentPlatform, gateway: PaymentGateway
    ) -> str | None:
        if platform == PaymentPlatform.ANDROID and gateway != PaymentGateway.GOOGLE_PLAY:
            return "Android subscriptions must use Google Play Billing (not Razorpay)"
        if platform == PaymentPlatform.WEB and gateway == PaymentGateway.GOOGLE_PLAY:
            return "Google Play is Android-only"
        return None

    async def create_order(
        self,
        request: CreateOrderRequest,
        *,
        auth_user_id: UUID | None = None,
    ) -> CreateOrderResponse:
        cached = PaymentSecurity.check_idempotency(request.idempotency_key)
        if cached:
            return CreateOrderResponse(**cached)

        user_id = auth_user_id or request.user_id
        if user_id is None:
            return CreateOrderResponse(
                order_id="",
                status=PaymentStatus.FAILED,
                amount_paise=0,
                gateway=request.gateway,
                message="user_id required",
            )

        err = self._validate_platform_gateway(request.platform, request.gateway)
        if err:
            return CreateOrderResponse(
                order_id="",
                status=PaymentStatus.FAILED,
                amount_paise=0,
                gateway=request.gateway,
                message=err,
            )

        if not request.plan_id and not request.credit_pack_id:
            return CreateOrderResponse(
                order_id="",
                status=PaymentStatus.FAILED,
                amount_paise=0,
                gateway=request.gateway,
                message="plan_id or credit_pack_id required",
            )

        try:
            amount = resolve_amount_paise(request.plan_id, request.credit_pack_id)
        except ValueError as e:
            return CreateOrderResponse(
                order_id="",
                status=PaymentStatus.FAILED,
                amount_paise=0,
                gateway=request.gateway,
                message=str(e),
            )

        order_id = f"ord_{uuid.uuid4().hex[:16]}"
        gw = self._gateway_for(request.gateway)
        response = await gw.create_order(
            order_id=order_id,
            amount_paise=amount,
            currency="INR",
            user_id=str(user_id),
            plan_id=request.plan_id or "",
            platform=request.platform,
            metadata={"credit_pack_id": request.credit_pack_id},
        )

        if response.status == PaymentStatus.FAILED:
            PaymentSecurity.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )
            return response

        try:
            client = get_supabase_admin()
            client.table("payments").insert(
                {
                    "user_id": str(user_id),
                    "order_id": order_id,
                    "plan_id": request.plan_id,
                    "credit_pack_id": request.credit_pack_id,
                    "gateway": request.gateway.value,
                    "platform": request.platform.value,
                    "amount_paise": amount,
                    "currency": "INR",
                    "status": "pending",
                    "gateway_order_id": response.gateway_order_id,
                    "idempotency_key": request.idempotency_key,
                    "metadata": {
                        "plan_id": request.plan_id,
                        "credit_pack_id": request.credit_pack_id,
                        "google_play_product_id": response.google_play_product_id,
                    },
                }
            ).execute()
            client.table("payment_logs").insert(
                {
                    "user_id": str(user_id),
                    "level": "info",
                    "event": "order_created",
                    "payload": {
                        "order_id": order_id,
                        "gateway_order_id": response.gateway_order_id,
                        "google_play_product_id": response.google_play_product_id,
                        "amount_paise": amount,
                    },
                }
            ).execute()
        except Exception as e:  # noqa: BLE001
            logger.exception("Failed to persist payment order")
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount,
                gateway=request.gateway,
                message=f"Order created at gateway but DB persist failed: {e}",
            )

        PaymentSecurity.store_idempotency(
            request.idempotency_key,
            response.model_dump(mode="json"),
        )
        return response

    async def verify_payment(
        self,
        request: VerifyPaymentRequest,
        *,
        auth_user_id: UUID | None = None,
    ) -> VerifyPaymentResponse:
        cached = PaymentSecurity.check_idempotency(request.idempotency_key)
        if cached:
            return VerifyPaymentResponse(**cached)

        user_id = auth_user_id or request.user_id
        client = get_supabase_admin()
        row_resp = (
            client.table("payments")
            .select("*")
            .eq("order_id", request.order_id)
            .limit(1)
            .execute()
        )
        if not row_resp.data:
            response = VerifyPaymentResponse(
                order_id=request.order_id,
                status=PaymentStatus.FAILED,
                credits_allocated=0,
                message="Unknown order_id",
            )
            PaymentSecurity.store_idempotency(
                request.idempotency_key, response.model_dump(mode="json")
            )
            return response

        payment = row_resp.data[0]
        if str(payment.get("user_id")) != str(user_id):
            response = VerifyPaymentResponse(
                order_id=request.order_id,
                status=PaymentStatus.FAILED,
                credits_allocated=0,
                message="Order does not belong to this user",
            )
            return response

        if PaymentSecurity.prevent_duplicate_payment(
            request.order_id, payment.get("status")
        ):
            response = VerifyPaymentResponse(
                order_id=request.order_id,
                status=PaymentStatus.VERIFIED,
                credits_allocated=int(
                    (payment.get("metadata") or {}).get("credits_allocated") or 0
                ),
                subscription_id=_parse_uuid(
                    (payment.get("metadata") or {}).get("subscription_id")
                ),
                message="Payment already verified (idempotent)",
            )
            PaymentSecurity.store_idempotency(
                request.idempotency_key, response.model_dump(mode="json")
            )
            return response

        payload = dict(request.gateway_payload or {})
        if payment.get("gateway_order_id") and "razorpay_order_id" not in payload:
            payload["razorpay_order_id"] = payment["gateway_order_id"]
        meta = payment.get("metadata") or {}
        if meta.get("google_play_product_id") and "product_id" not in payload:
            payload["product_id"] = meta["google_play_product_id"]
        if payment.get("gateway_order_id") and "product_id" not in payload:
            payload["product_id"] = payment["gateway_order_id"]

        gw = self._gateway_for(request.gateway)
        verified = await gw.verify_payment(
            order_id=request.order_id,
            gateway_payment_id=request.gateway_payment_id,
            signature=request.gateway_signature,
            payload=payload,
        )

        if not verified:
            not_cfg = (
                request.gateway == PaymentGateway.GOOGLE_PLAY
                and not PaymentConfig.google_play_configured()
            )
            response = VerifyPaymentResponse(
                order_id=request.order_id,
                status=PaymentStatus.FAILED,
                credits_allocated=0,
                message=(
                    "Google Play not configured — set GOOGLE_PLAY_PACKAGE_NAME "
                    "and GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
                    if not_cfg
                    else "Invalid payment signature / purchase token — not verified"
                ),
            )
            PaymentSecurity.store_idempotency(
                request.idempotency_key, response.model_dump(mode="json")
            )
            return response

        result = await self.fulfill_verified_payment(
            payment=payment,
            gateway_payment_id=request.gateway_payment_id,
            fulfillment_idempotency_key=f"fulfill_{payment['order_id']}",
        )
        PaymentSecurity.store_idempotency(
            request.idempotency_key, result.model_dump(mode="json")
        )
        return result

    async def fulfill_verified_payment(
        self,
        *,
        payment: dict[str, Any],
        gateway_payment_id: str | None,
        fulfillment_idempotency_key: str,
    ) -> VerifyPaymentResponse:
        """Shared by checkout verify + webhook — idempotent on payment status."""
        client = get_supabase_admin()
        order_id = payment["order_id"]

        if payment.get("status") == "verified":
            return VerifyPaymentResponse(
                order_id=order_id,
                status=PaymentStatus.VERIFIED,
                credits_allocated=int(
                    (payment.get("metadata") or {}).get("credits_allocated") or 0
                ),
                subscription_id=_parse_uuid(
                    (payment.get("metadata") or {}).get("subscription_id")
                ),
                message="Already fulfilled",
            )

        payment_uuid = UUID(str(payment["id"]))
        user_id = UUID(str(payment["user_id"]))
        plan_id = payment.get("plan_id")
        credit_pack_id = payment.get("credit_pack_id")
        platform = PaymentPlatform(payment["platform"])
        gateway = PaymentGateway(payment["gateway"])

        subscription_id: UUID | None = None
        credits = 0

        if credit_pack_id:
            credits = await self._credits.allocate_pack_credits(
                AllocateCreditsRequest(
                    user_id=user_id,
                    credits=credits_for_pack(credit_pack_id),
                    source="credit_pack",
                    payment_id=payment_uuid,
                    idempotency_key=fulfillment_idempotency_key,
                ),
                pack_id=credit_pack_id,
                payment_id=payment_uuid,
            )
            tx_type = "credit_pack"
        else:
            activated = await self.activate_subscription(
                user_id=user_id,
                plan_id=str(plan_id),
                payment_id=payment_uuid,
                platform=platform,
                gateway=gateway,
            )
            subscription_id = _parse_uuid(activated.get("subscription_id"))
            credits = await self._credits.allocate_monthly_credits(
                user_id=user_id,
                plan_id=str(plan_id),
                payment_id=payment_uuid,
                idempotency_key=fulfillment_idempotency_key,
            )
            tx_type = "charge"

        meta = dict(payment.get("metadata") or {})
        meta["credits_allocated"] = credits
        if subscription_id:
            meta["subscription_id"] = str(subscription_id)

        now = datetime.now(timezone.utc).isoformat()
        client.table("payments").update(
            {
                "status": "verified",
                "gateway_payment_id": gateway_payment_id,
                "verified_at": now,
                "metadata": meta,
            }
        ).eq("id", str(payment_uuid)).execute()

        client.table("payment_transactions").insert(
            {
                "payment_id": str(payment_uuid),
                "user_id": str(user_id),
                "type": tx_type,
                "amount_paise": payment["amount_paise"],
                "currency": payment.get("currency") or "INR",
                "status": "verified",
            }
        ).execute()

        client.table("payment_logs").insert(
            {
                "payment_id": str(payment_uuid),
                "user_id": str(user_id),
                "level": "info",
                "event": "payment_verified",
                "payload": {
                    "credits_allocated": credits,
                    "plan_id": plan_id,
                    "credit_pack_id": credit_pack_id,
                },
            }
        ).execute()

        return VerifyPaymentResponse(
            order_id=order_id,
            status=PaymentStatus.VERIFIED,
            subscription_id=subscription_id,
            credits_allocated=credits,
            message=(
                f"Verified — allocated {credits} credits"
                + (f" for {plan_id}" if plan_id and not credit_pack_id else "")
                + (f" pack {credit_pack_id}" if credit_pack_id else "")
            ),
        )

    async def activate_subscription(
        self,
        user_id: uuid.UUID,
        plan_id: str,
        payment_id: uuid.UUID,
        platform: PaymentPlatform,
        gateway: PaymentGateway,
    ) -> dict[str, Any]:
        client = get_supabase_admin()
        now = datetime.now(timezone.utc)
        expires = now + timedelta(days=30)

        # End any currently active subscriptions for this user.
        active = (
            client.table("user_subscriptions")
            .select("id")
            .eq("user_id", str(user_id))
            .eq("status", "active")
            .execute()
        )
        for row in active.data or []:
            client.table("user_subscriptions").update(
                {"status": "cancelled", "updated_at": now.isoformat()}
            ).eq("id", row["id"]).execute()

        inserted = (
            client.table("user_subscriptions")
            .insert(
                {
                    "user_id": str(user_id),
                    "plan_id": plan_id,
                    "status": SubscriptionStatus.ACTIVE.value,
                    "platform": platform.value,
                    "gateway": gateway.value,
                    "current_period_start": now.isoformat(),
                    "current_period_end": expires.isoformat(),
                }
            )
            .select("id")
            .single()
            .execute()
        )
        sub_id = inserted.data["id"]

        if plan_id == "teacher":
            client.table("teacher_subscriptions").insert(
                {
                    "user_subscription_id": sub_id,
                    "teacher_id": str(user_id),
                }
            ).execute()

        return {
            "status": SubscriptionStatus.ACTIVE.value,
            "plan_id": plan_id,
            "subscription_id": sub_id,
            "expires_at": expires.isoformat(),
            "platform": platform.value,
            "gateway": gateway.value,
            "payment_id": str(payment_id),
            "monthly_credits": credits_for_plan(plan_id),
        }

    async def get_payment_status(
        self, order_id: str, *, user_id: UUID | None = None
    ) -> dict[str, Any]:
        client = get_supabase_admin()
        row = (
            client.table("payments")
            .select(
                "order_id, user_id, status, amount_paise, plan_id, "
                "credit_pack_id, verified_at, metadata"
            )
            .eq("order_id", order_id)
            .limit(1)
            .execute()
        )
        if not row.data:
            return {"order_id": order_id, "status": "not_found"}
        data = row.data[0]
        if user_id is not None and str(data.get("user_id")) != str(user_id):
            return {"order_id": order_id, "status": "not_found"}
        data.pop("user_id", None)
        return data


def _parse_uuid(value: Any) -> UUID | None:
    if not value:
        return None
    try:
        return UUID(str(value))
    except (ValueError, TypeError):
        return None
