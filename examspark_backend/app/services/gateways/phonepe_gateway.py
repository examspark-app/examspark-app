"""PhonePe gateway — Web optional future. TODO: live integration."""
from typing import Any

from app.config import PaymentConfig
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase


class PhonePeGateway(PaymentGatewayBase):
    gateway = PaymentGateway.PHONEPE

    async def create_order(
        self,
        order_id: str,
        amount_paise: int,
        currency: str,
        user_id: str,
        plan_id: str,
        platform: PaymentPlatform,
        metadata: dict[str, Any],
    ) -> CreateOrderResponse:
        # TODO: PhonePe Integration
        return CreateOrderResponse(
            order_id=order_id,
            status=PaymentStatus.PENDING,
            amount_paise=amount_paise,
            currency=currency,
            gateway=self.gateway,
            message="TODO: PhonePe pay API — not configured",
        )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        # TODO: PhonePe Integration — status check + signature verify
        return False
