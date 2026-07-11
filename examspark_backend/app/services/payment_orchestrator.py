"""Payment orchestration — order → pending → verify → activate → credits."""
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from app.models.payment import (
    CreateOrderRequest,
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
    PlanTier,
    SubscriptionStatus,
    VerifyPaymentRequest,
    VerifyPaymentResponse,
)
from app.services.credit_allocator import CreditAllocator
from app.services.gateways.google_play_gateway import GooglePlayGateway
from app.services.gateways.phonepe_gateway import PhonePeGateway
from app.services.gateways.razorpay_gateway import RazorpayGateway
from app.services.security import PaymentSecurity

PLAN_PRICES_PAISE: dict[str, int] = {
    PlanTier.FREE.value: 0,
    "plan_199": 199_00,
    "plan_299": 299_00,  # optional re-entry tier
    "plan_499": 499_00,
    "plan_999": 999_00,
    PlanTier.TEACHER.value: 1999_00,
}


class PaymentOrchestrator:
    """
    Flow:
    User → Choose Plan → Create Order → Pending Payment → Verify Payment
         → Activate Subscription → Allocate Monthly Credits → Store Transaction
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

    def _resolve_amount(self, plan_id: str, credit_pack_id: str | None) -> int:
        if credit_pack_id:
            # TODO: load from credit_packs table
            return 0
        return PLAN_PRICES_PAISE.get(plan_id, 0)

    def _validate_platform_gateway(
        self, platform: PaymentPlatform, gateway: PaymentGateway
    ) -> str | None:
        if platform == PaymentPlatform.ANDROID and gateway != PaymentGateway.GOOGLE_PLAY:
            return "Android subscriptions must use Google Play Billing (not Razorpay)"
        if platform == PaymentPlatform.WEB and gateway == PaymentGateway.GOOGLE_PLAY:
            return "Google Play is Android-only"
        return None

    async def create_order(self, request: CreateOrderRequest) -> CreateOrderResponse:
        cached = PaymentSecurity.check_idempotency(request.idempotency_key)
        if cached:
            return CreateOrderResponse(**cached)

        err = self._validate_platform_gateway(request.platform, request.gateway)
        if err:
            return CreateOrderResponse(
                order_id="",
                status=PaymentStatus.FAILED,
                amount_paise=0,
                gateway=request.gateway,
                message=err,
            )

        order_id = f"ord_{uuid.uuid4().hex[:16]}"
        amount = self._resolve_amount(request.plan_id, request.credit_pack_id)

        gw = self._gateway_for(request.gateway)
        response = await gw.create_order(
            order_id=order_id,
            amount_paise=amount,
            currency="INR",
            user_id=str(request.user_id),
            plan_id=request.plan_id,
            platform=request.platform,
            metadata={"credit_pack_id": request.credit_pack_id},
        )

        # TODO: INSERT INTO payments (status=pending), payment_logs
        PaymentSecurity.store_idempotency(
            request.idempotency_key,
            response.model_dump(mode="json"),
        )
        return response

    async def verify_payment(self, request: VerifyPaymentRequest) -> VerifyPaymentResponse:
        cached = PaymentSecurity.check_idempotency(request.idempotency_key)
        if cached:
            return VerifyPaymentResponse(**cached)

        # TODO: Load payment from DB; check duplicate via PaymentSecurity.prevent_duplicate_payment
        gw = self._gateway_for(request.gateway)
        verified = await gw.verify_payment(
            order_id=request.order_id,
            gateway_payment_id=request.gateway_payment_id,
            signature=request.gateway_signature,
            payload=request.gateway_payload,
        )

        if not verified:
            response = VerifyPaymentResponse(
                order_id=request.order_id,
                status=PaymentStatus.PENDING,
                credits_allocated=0,
                message="Payment not verified — gateway integration pending (TODO)",
            )
            PaymentSecurity.store_idempotency(
                request.idempotency_key,
                response.model_dump(mode="json"),
            )
            return response

        # TODO: Activate subscription, allocate credits, store transaction
        payment_uuid = uuid.uuid4()
        credits = await self._credits.allocate_monthly_credits(
            user_id=request.user_id,
            plan_id=request.gateway_payload.get("plan_id", "entry"),
            payment_id=payment_uuid,
            idempotency_key=request.idempotency_key,
        )

        response = VerifyPaymentResponse(
            order_id=request.order_id,
            status=PaymentStatus.VERIFIED,
            subscription_id=uuid.uuid4(),
            credits_allocated=credits,
            message="Verified — DB persistence TODO until live gateway",
        )
        PaymentSecurity.store_idempotency(
            request.idempotency_key,
            response.model_dump(mode="json"),
        )
        return response

    async def activate_subscription(
        self,
        user_id: uuid.UUID,
        plan_id: str,
        payment_id: uuid.UUID,
        platform: PaymentPlatform,
        gateway: PaymentGateway,
    ) -> dict[str, Any]:
        # TODO: INSERT user_subscriptions / teacher_subscriptions
        expires = datetime.now(timezone.utc) + timedelta(days=30)
        return {
            "status": SubscriptionStatus.ACTIVE.value,
            "plan_id": plan_id,
            "expires_at": expires.isoformat(),
            "platform": platform.value,
            "gateway": gateway.value,
        }
