"""Google Play Billing — Android subscriptions only. TODO: live integration."""
from typing import Any

from app.config import PaymentConfig
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase


class GooglePlayGateway(PaymentGatewayBase):
    gateway = PaymentGateway.GOOGLE_PLAY

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
        # TODO: Google Play Billing
        # Android: no server order — client launches BillingClient purchase flow
        # Server records pending subscription by product_id + user_id
        return CreateOrderResponse(
            order_id=order_id,
            status=PaymentStatus.PENDING,
            amount_paise=amount_paise,
            currency=currency,
            gateway=self.gateway,
            message="TODO: Google Play — use BillingClient on Android; verify token server-side",
        )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        # TODO: Google Play Billing — purchases.subscriptions.get via Play Developer API
        purchase_token = payload.get("purchase_token")
        product_id = payload.get("product_id")
        if not purchase_token or not product_id:
            return False
        if not PaymentConfig.google_play_configured():
            return False
        return False
