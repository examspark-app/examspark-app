"""Razorpay gateway — Web primary. TODO: live integration."""
from typing import Any

from app.config import PaymentConfig
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase


class RazorpayGateway(PaymentGatewayBase):
    gateway = PaymentGateway.RAZORPAY

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
        # TODO: Razorpay Integration
        # import razorpay
        # client = razorpay.Client(auth=(PaymentConfig.RAZORPAY_KEY_ID, PaymentConfig.RAZORPAY_KEY_SECRET))
        # order = client.order.create({...})
        if not PaymentConfig.razorpay_configured():
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.PENDING,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                gateway_order_id=None,
                message="Razorpay not configured — order recorded as pending",
            )
        return CreateOrderResponse(
            order_id=order_id,
            status=PaymentStatus.PENDING,
            amount_paise=amount_paise,
            gateway=self.gateway,
            message="TODO: Razorpay order.create()",
        )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        # TODO: Razorpay Integration — client.utility.verify_payment_signature(...)
        return False
