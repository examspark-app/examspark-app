"""Google Play Billing — Android subscriptions + one-time packs."""
from typing import Any

from app.config import PaymentConfig
from app.constants.payment_catalog import play_product_id_for
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase
from app.services.play_billing_verify import verify_play_purchase


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
        # Client launches BillingClient; server records pending + product_id.
        credit_pack_id = metadata.get("credit_pack_id")
        try:
            product_id = play_product_id_for(
                plan_id=plan_id or None,
                credit_pack_id=credit_pack_id,
            )
        except ValueError as e:
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                message=str(e),
            )

        package = PaymentConfig.GOOGLE_PLAY_PACKAGE_NAME or ""
        msg = (
            "Play purchase intent recorded — complete Billing on Android"
            if package
            else (
                "Play purchase intent recorded — set GOOGLE_PLAY_PACKAGE_NAME "
                "and service account before verify will succeed"
            )
        )
        return CreateOrderResponse(
            order_id=order_id,
            status=PaymentStatus.PENDING,
            amount_paise=amount_paise,
            currency=currency,
            gateway=self.gateway,
            gateway_order_id=product_id,
            google_play_product_id=product_id,
            message=msg,
        )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        purchase_token = (
            payload.get("purchase_token")
            or gateway_payment_id
            or payload.get("purchaseToken")
        )
        product_id = (
            payload.get("product_id")
            or payload.get("productId")
            or payload.get("gateway_order_id")
        )
        if not purchase_token or not product_id:
            return False
        if not PaymentConfig.google_play_configured():
            return False
        return verify_play_purchase(
            product_id=str(product_id),
            purchase_token=str(purchase_token),
        )
