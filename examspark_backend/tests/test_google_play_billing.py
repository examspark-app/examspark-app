"""Google Play Billing — catalog map + verify fail-closed paths."""
from __future__ import annotations

from unittest.mock import patch

import pytest

from app.constants.payment_catalog import (
    PLAY_PRODUCT_TO_PACK,
    PLAN_TO_PLAY_PRODUCT,
    credits_for_plan,
    play_product_id_for,
    resolve_catalog_from_play_product,
)
from app.models.payment import PaymentGateway, PaymentPlatform, PaymentStatus
from app.services.gateways.google_play_gateway import GooglePlayGateway
from app.services.security import PaymentSecurity


def test_play_product_map_plans_and_packs():
    assert play_product_id_for(plan_id="plan_199", credit_pack_id=None) == (
        "examspark_plan_199"
    )
    assert play_product_id_for(plan_id=None, credit_pack_id="pack_100") == (
        "examspark_pack_100"
    )
    plan, pack = resolve_catalog_from_play_product("examspark_plan_499")
    assert plan == "plan_499" and pack is None
    plan2, pack2 = resolve_catalog_from_play_product("examspark_pack_500")
    assert plan2 is None and pack2 == "pack_500"
    assert credits_for_plan("plan_499") == 3500
    assert set(PLAN_TO_PLAY_PRODUCT.values()).isdisjoint(
        set(PLAY_PRODUCT_TO_PACK.keys())
    )


def test_play_product_rejects_unknown():
    with pytest.raises(ValueError):
        play_product_id_for(plan_id="free", credit_pack_id=None)
    with pytest.raises(ValueError):
        resolve_catalog_from_play_product("unknown_sku")


@pytest.mark.asyncio
async def test_gateway_create_order_returns_product_id():
    gw = GooglePlayGateway()
    resp = await gw.create_order(
        order_id="ord_test",
        amount_paise=19900,
        currency="INR",
        user_id="u1",
        plan_id="plan_199",
        platform=PaymentPlatform.ANDROID,
        metadata={},
    )
    assert resp.status == PaymentStatus.PENDING
    assert resp.google_play_product_id == "examspark_plan_199"
    assert resp.gateway_order_id == "examspark_plan_199"
    assert resp.gateway == PaymentGateway.GOOGLE_PLAY


@pytest.mark.asyncio
async def test_verify_rejects_missing_token():
    gw = GooglePlayGateway()
    ok = await gw.verify_payment(
        order_id="ord_x",
        gateway_payment_id=None,
        signature=None,
        payload={"product_id": "examspark_plan_199"},
    )
    assert ok is False


@pytest.mark.asyncio
async def test_verify_fails_closed_when_not_configured():
    gw = GooglePlayGateway()
    with patch(
        "app.services.gateways.google_play_gateway.PaymentConfig.google_play_configured",
        return_value=False,
    ):
        ok = await gw.verify_payment(
            order_id="ord_x",
            gateway_payment_id="token",
            signature=None,
            payload={"product_id": "examspark_plan_199", "purchase_token": "token"},
        )
    assert ok is False


@pytest.mark.asyncio
async def test_verify_calls_play_api_when_configured():
    gw = GooglePlayGateway()
    with patch(
        "app.services.gateways.google_play_gateway.PaymentConfig.google_play_configured",
        return_value=True,
    ), patch(
        "app.services.gateways.google_play_gateway.verify_play_purchase",
        return_value=True,
    ) as mock_verify:
        ok = await gw.verify_payment(
            order_id="ord_x",
            gateway_payment_id="tok_abc",
            signature=None,
            payload={
                "product_id": "examspark_plan_199",
                "purchase_token": "tok_abc",
            },
        )
    assert ok is True
    mock_verify.assert_called_once()


def test_security_verify_google_play_delegates():
    with patch(
        "app.services.security.PaymentConfig.google_play_configured",
        return_value=True,
    ), patch(
        "app.services.play_billing_verify.verify_play_purchase",
        return_value=True,
    ) as mock_v:
        assert PaymentSecurity.verify_google_play_purchase(
            "com.example.app", "examspark_plan_199", "tok"
        )
        mock_v.assert_called_once()


@pytest.mark.asyncio
async def test_orchestrator_android_rejects_razorpay():
    from app.models.payment import CreateOrderRequest
    from app.services.payment_orchestrator import PaymentOrchestrator
    from uuid import uuid4

    orch = PaymentOrchestrator()
    with patch.object(PaymentSecurity, "check_idempotency", return_value=None):
        resp = await orch.create_order(
            CreateOrderRequest(
                user_id=uuid4(),
                plan_id="plan_199",
                platform=PaymentPlatform.ANDROID,
                gateway=PaymentGateway.RAZORPAY,
                idempotency_key="idem_android_rzp_01",
            ),
            auth_user_id=uuid4(),
        )
    assert resp.status == PaymentStatus.FAILED
    assert "Google Play" in resp.message
