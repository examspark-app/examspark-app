"""Session 6 — Razorpay signature + catalog + idempotent webhook paths."""
from __future__ import annotations

import hashlib
import hmac
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.constants.payment_catalog import (
    resolve_amount_paise,
    credits_for_pack,
    credits_for_plan,
)
from app.services.security import PaymentSecurity


def _sign_payment(order_id: str, payment_id: str, secret: str) -> str:
    msg = f"{order_id}|{payment_id}".encode("utf-8")
    return hmac.new(secret.encode("utf-8"), msg, hashlib.sha256).hexdigest()


def _sign_webhook(body: bytes, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


def test_catalog_plan_and_pack_amounts():
    assert resolve_amount_paise("plan_199", None) == 19_900
    assert resolve_amount_paise("plan_499", None) == 49_900
    assert resolve_amount_paise(None, "pack_100") == 2_500
    assert credits_for_plan("plan_199") == 1500
    assert credits_for_plan("plan_499") == 3500
    assert credits_for_pack("pack_500") == 500
    # Paid package only — never invent Free-50 add-on
    assert credits_for_plan("plan_199") == 1500


def test_catalog_rejects_free_and_unknown():
    with pytest.raises(ValueError):
        resolve_amount_paise("free", None)
    with pytest.raises(ValueError):
        resolve_amount_paise("plan_nope", None)
    with pytest.raises(ValueError):
        resolve_amount_paise(None, "pack_nope")


def test_payment_signature_accepts_valid_rejects_bad():
    secret = "test_key_secret"
    order_id = "order_ABC"
    payment_id = "pay_XYZ"
    good = _sign_payment(order_id, payment_id, secret)
    assert PaymentSecurity.verify_razorpay_payment_signature(
        order_id, payment_id, good, key_secret=secret
    )
    assert not PaymentSecurity.verify_razorpay_payment_signature(
        order_id, payment_id, "deadbeef", key_secret=secret
    )
    assert not PaymentSecurity.verify_razorpay_payment_signature(
        order_id, payment_id, good, key_secret="wrong"
    )


def test_webhook_signature_accepts_valid_rejects_bad():
    secret = "whsec_test"
    body = b'{"event":"payment.captured"}'
    good = _sign_webhook(body, secret)
    assert PaymentSecurity.verify_razorpay_webhook_signature(
        body, good, webhook_secret=secret
    )
    assert not PaymentSecurity.verify_razorpay_webhook_signature(
        body, "nope", webhook_secret=secret
    )


@pytest.mark.asyncio
async def test_razorpay_gateway_verify_uses_payment_signature():
    from app.services.gateways.razorpay_gateway import RazorpayGateway

    gw = RazorpayGateway()
    secret = "sk_test"
    order = "order_1"
    pay = "pay_1"
    sig = _sign_payment(order, pay, secret)
    with patch(
        "app.services.security.PaymentConfig.RAZORPAY_KEY_SECRET",
        secret,
    ):
        ok = await gw.verify_payment(
            order_id="ord_local",
            gateway_payment_id=pay,
            signature=sig,
            payload={"razorpay_order_id": order},
        )
        bad = await gw.verify_payment(
            order_id="ord_local",
            gateway_payment_id=pay,
            signature="bad",
            payload={"razorpay_order_id": order},
        )
    assert ok is True
    assert bad is False


@pytest.mark.asyncio
async def test_webhook_rejects_bad_signature():
    from app.services.webhook_service import WebhookService

    request = MagicMock()
    request.body = AsyncMock(return_value=b'{"event":"payment.captured"}')
    request.headers = {"X-Razorpay-Signature": "invalid"}

    with patch(
        "app.services.webhook_service.PaymentSecurity.verify_razorpay_signature",
        return_value=False,
    ):
        with pytest.raises(HTTPException) as exc:
            await WebhookService().handle_razorpay(request)
        assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_webhook_duplicate_event_ignored():
    from app.services.webhook_service import WebhookService

    body = json.dumps(
        {
            "event": "payment.captured",
            "id": "evt_dup_1",
            "payload": {
                "payment": {
                    "entity": {"id": "pay_1", "order_id": "order_rzp_1"}
                }
            },
        }
    ).encode()
    request = MagicMock()
    request.body = AsyncMock(return_value=body)
    request.headers = {
        "X-Razorpay-Signature": "ok",
        "X-Razorpay-Event-Id": "evt_dup_1",
    }

    mock_client = MagicMock()
    # First select finds existing webhook row → duplicate
    mock_client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[{"id": "wh_1", "status": "processed"}]
    )

    with patch(
        "app.services.webhook_service.PaymentSecurity.verify_razorpay_signature",
        return_value=True,
    ), patch(
        "app.services.webhook_service.get_supabase_admin",
        return_value=mock_client,
    ):
        result = await WebhookService().handle_razorpay(request)

    assert result["status"] == "duplicate_ignored"


@pytest.mark.asyncio
async def test_fulfill_skips_second_grant_when_already_verified():
    from app.services.payment_orchestrator import PaymentOrchestrator

    orch = PaymentOrchestrator()
    payment = {
        "id": "11111111-1111-1111-1111-111111111111",
        "order_id": "ord_already",
        "user_id": "22222222-2222-2222-2222-222222222222",
        "status": "verified",
        "metadata": {"credits_allocated": 1500},
        "amount_paise": 19900,
        "platform": "web",
        "gateway": "razorpay",
        "plan_id": "plan_199",
        "credit_pack_id": None,
    }
    result = await orch.fulfill_verified_payment(
        payment=payment,
        gateway_payment_id="pay_x",
        fulfillment_idempotency_key="fulfill_ord_already",
    )
    assert result.status.value == "verified"
    assert result.credits_allocated == 1500
    assert "Already" in result.message or "fulfilled" in result.message.lower()
