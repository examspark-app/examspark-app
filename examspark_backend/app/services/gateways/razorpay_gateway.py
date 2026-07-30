"""Razorpay gateway — Web primary (test mode / live keys via .env)."""
from typing import Any

import httpx

from app.config import PaymentConfig
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase
from app.services.security import PaymentSecurity

_RAZORPAY_ORDERS_URL = "https://api.razorpay.com/v1/orders"


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
        if not PaymentConfig.razorpay_configured():
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                gateway_order_id=None,
                razorpay_key_id=None,
                message="Razorpay not configured — set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET",
            )

        notes = {
            "examspark_order_id": order_id,
            "user_id": user_id,
            "plan_id": plan_id or "",
            "credit_pack_id": str(metadata.get("credit_pack_id") or ""),
            "platform": platform.value,
        }
        body = {
            "amount": amount_paise,
            "currency": currency,
            "receipt": order_id[:40],
            "notes": notes,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(
                    _RAZORPAY_ORDERS_URL,
                    json=body,
                    auth=(PaymentConfig.RAZORPAY_KEY_ID, PaymentConfig.RAZORPAY_KEY_SECRET),
                )
            if resp.status_code >= 400:
                detail = resp.text[:300]
                return CreateOrderResponse(
                    order_id=order_id,
                    status=PaymentStatus.FAILED,
                    amount_paise=amount_paise,
                    currency=currency,
                    gateway=self.gateway,
                    message=f"Razorpay order.create failed: {detail}",
                )
            data = resp.json()
            gateway_order_id = data.get("id")
            if not gateway_order_id:
                return CreateOrderResponse(
                    order_id=order_id,
                    status=PaymentStatus.FAILED,
                    amount_paise=amount_paise,
                    currency=currency,
                    gateway=self.gateway,
                    message="Razorpay response missing order id",
                )
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.PENDING,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                gateway_order_id=gateway_order_id,
                razorpay_key_id=PaymentConfig.RAZORPAY_KEY_ID,
                message="Razorpay order created — complete checkout",
            )
        except httpx.HTTPError as e:
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                message=f"Razorpay network error: {e}",
            )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        gateway_order_id = (
            payload.get("razorpay_order_id")
            or payload.get("gateway_order_id")
            or ""
        )
        if not gateway_order_id or not gateway_payment_id or not signature:
            return False
        return PaymentSecurity.verify_razorpay_payment_signature(
            gateway_order_id=str(gateway_order_id),
            gateway_payment_id=str(gateway_payment_id),
            signature=str(signature),
        )
