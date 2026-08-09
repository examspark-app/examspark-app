"""PhonePe Standard Checkout — order create + status verify.

Requires env: PHONEPE_MERCHANT_ID, PHONEPE_SALT_KEY, PHONEPE_SALT_INDEX,
PHONEPE_BASE_URL (sandbox: https://api-preprod.phonepe.com/apis/pg-sandbox,
prod: https://api.phonepe.com/apis/hermes), PHONEPE_REDIRECT_URL,
PHONEPE_CALLBACK_URL. Soft-fails (isConfigured=False) until all are set.
"""
import base64
import hashlib
import json
import logging
import os

import httpx

from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase

logger = logging.getLogger(__name__)


def _configured() -> bool:
    return all([
        os.getenv("PHONEPE_MERCHANT_ID"),
        os.getenv("PHONEPE_SALT_KEY"),
        os.getenv("PHONEPE_SALT_INDEX"),
        os.getenv("PHONEPE_BASE_URL"),
    ])


def _checksum(payload_b64: str, path: str) -> str:
    salt_key = os.getenv("PHONEPE_SALT_KEY", "")
    salt_index = os.getenv("PHONEPE_SALT_INDEX", "1")
    raw = f"{payload_b64}{path}{salt_key}"
    digest = hashlib.sha256(raw.encode()).hexdigest()
    return f"{digest}###{salt_index}"


def _status_checksum(path: str) -> str:
    salt_key = os.getenv("PHONEPE_SALT_KEY", "")
    salt_index = os.getenv("PHONEPE_SALT_INDEX", "1")
    digest = hashlib.sha256(f"{path}{salt_key}".encode()).hexdigest()
    return f"{digest}###{salt_index}"


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
        metadata: dict,
    ) -> CreateOrderResponse:
        if not _configured():
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                message="PhonePe not configured — set PHONEPE_* env vars",
            )

        merchant_id = os.getenv("PHONEPE_MERCHANT_ID")
        base_url = os.getenv("PHONEPE_BASE_URL")
        redirect_url = os.getenv("PHONEPE_REDIRECT_URL", "")
        callback_url = os.getenv("PHONEPE_CALLBACK_URL", "")

        body = {
            "merchantId": merchant_id,
            "merchantTransactionId": order_id,
            "merchantUserId": user_id,
            "amount": amount_paise,
            "redirectUrl": redirect_url,
            "redirectMode": "REDIRECT",
            "callbackUrl": callback_url,
            "paymentInstrument": {"type": "PAY_PAGE"},
        }
        payload_b64 = base64.b64encode(json.dumps(body).encode()).decode()
        checksum = _checksum(payload_b64, "/pg/v1/pay")

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    f"{base_url}/pg/v1/pay",
                    json={"request": payload_b64},
                    headers={
                        "Content-Type": "application/json",
                        "X-VERIFY": checksum,
                    },
                )
            data = resp.json()
            if not data.get("success"):
                return CreateOrderResponse(
                    order_id=order_id,
                    status=PaymentStatus.FAILED,
                    amount_paise=amount_paise,
                    currency=currency,
                    gateway=self.gateway,
                    message=data.get("message", "PhonePe order create failed"),
                )
            redirect = (
                data.get("data", {})
                .get("instrumentResponse", {})
                .get("redirectInfo", {})
                .get("url")
            )
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.PENDING,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                gateway_order_id=redirect,  # redirect URL carried here
                message="Redirect to PhonePe checkout",
            )
        except Exception as e:  # noqa: BLE001
            logger.exception("PhonePe create_order failed")
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                message=f"PhonePe error: {e}",
            )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict,
    ) -> bool:
        if not _configured():
            return False
        merchant_id = os.getenv("PHONEPE_MERCHANT_ID")
        base_url = os.getenv("PHONEPE_BASE_URL")
        path = f"/pg/v1/status/{merchant_id}/{order_id}"
        checksum = _status_checksum(path)
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.get(
                    f"{base_url}{path}",
                    headers={
                        "X-VERIFY": checksum,
                        "X-MERCHANT-ID": merchant_id,
                    },
                )
            data = resp.json()
            return (
                data.get("success") is True
                and data.get("data", {}).get("state") == "COMPLETED"
            )
        except Exception as e:  # noqa: BLE001
            logger.exception("PhonePe verify_payment failed")
            return False