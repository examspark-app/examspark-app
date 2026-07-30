"""Refund service — idempotent mark + cancel sub."""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.refund_service import RefundNotFoundError, RefundService


def _payment_row(**overrides):
    base = {
        "id": "11111111-1111-1111-1111-111111111111",
        "order_id": "ord_ref_1",
        "user_id": "22222222-2222-2222-2222-222222222222",
        "status": "verified",
        "plan_id": "plan_199",
        "credit_pack_id": None,
        "amount_paise": 19900,
        "currency": "INR",
        "gateway_payment_id": "pay_abc",
        "metadata": {"credits_allocated": 1500},
    }
    base.update(overrides)
    return base


@pytest.mark.asyncio
async def test_refund_missing_payment_raises():
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[]
    )
    with patch(
        "app.services.refund_service.get_supabase_admin", return_value=client
    ):
        with pytest.raises(RefundNotFoundError):
            await RefundService().process_refund(gateway_payment_id="missing")


@pytest.mark.asyncio
async def test_refund_idempotent_when_already_refunded():
    payment = _payment_row(status="refunded")
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[payment]
    )
    with patch(
        "app.services.refund_service.get_supabase_admin", return_value=client
    ):
        result = await RefundService().process_refund(
            gateway_payment_id="pay_abc"
        )
    assert result["status"] == "already_refunded"
    assert result["idempotent"] is True


@pytest.mark.asyncio
async def test_refund_cancels_sub_and_marks_refunded():
    payment = _payment_row()
    client = MagicMock()

    def table(name: str):
        mock = MagicMock()
        if name == "payments":
            mock.select.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(
                data=[payment]
            )
            mock.update.return_value.eq.return_value.execute.return_value = MagicMock()
        elif name == "user_subscriptions":
            mock.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(
                data=[{"id": "sub-1"}]
            )
            mock.update.return_value.eq.return_value.execute.return_value = MagicMock()
        elif name == "users":
            mock.select.return_value.eq.return_value.single.return_value.execute.return_value = MagicMock(
                data={"credits_balance": 1500}
            )
        else:
            mock.insert.return_value.execute.return_value = MagicMock()
        return mock

    client.table.side_effect = table
    client.rpc.return_value.execute.return_value = MagicMock(data=3)

    with patch(
        "app.services.refund_service.get_supabase_admin", return_value=client
    ), patch(
        "app.services.refund_service.deduct_credits", return_value=0
    ) as mock_deduct:
        result = await RefundService().process_refund(
            gateway_payment_id="pay_abc", reason="test"
        )

    assert result["status"] == "refunded"
    assert result["subscriptions_cancelled"] == 1
    assert result["credits_clawed"] == 1500
    assert result["groups_left"] == 3
    mock_deduct.assert_called_once()
    client.rpc.assert_called_with(
        "fn_trim_group_memberships",
        {"p_user_id": payment["user_id"]},
    )


def test_trim_group_memberships_calls_rpc():
    client = MagicMock()
    client.rpc.return_value.execute.return_value = MagicMock(data=2)
    with patch(
        "app.services.refund_service.get_supabase_admin", return_value=client
    ):
        left = RefundService()._trim_group_memberships("user-1")
    assert left == 2
    client.rpc.assert_called_once_with(
        "fn_trim_group_memberships",
        {"p_user_id": "user-1"},
    )


def test_trim_group_memberships_fail_closed_returns_zero():
    client = MagicMock()
    client.rpc.return_value.execute.side_effect = RuntimeError("rpc down")
    with patch(
        "app.services.refund_service.get_supabase_admin", return_value=client
    ):
        left = RefundService()._trim_group_memberships("user-1")
    assert left == 0


@pytest.mark.asyncio
async def test_razorpay_refund_webhook_routes():
    from app.services.webhook_service import WebhookService

    body = (
        b'{"event":"refund.processed","payload":'
        b'{"payment":{"entity":{"id":"pay_x"}}}}'
    )
    request = MagicMock()
    request.body = AsyncMock(return_value=body)
    request.headers = {
        "X-Razorpay-Signature": "ok",
        "X-Razorpay-Event-Id": "evt_ref_1",
    }

    mock_client = MagicMock()
    mock_client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(
        data=[]
    )
    mock_client.table.return_value.insert.return_value.execute.return_value = MagicMock()
    mock_client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock()

    with patch(
        "app.services.webhook_service.PaymentSecurity.verify_razorpay_signature",
        return_value=True,
    ), patch(
        "app.services.webhook_service.get_supabase_admin", return_value=mock_client
    ), patch(
        "app.services.webhook_service.RefundService.process_refund",
        new=AsyncMock(return_value={"status": "refunded"}),
    ):
        result = await WebhookService().handle_razorpay(request)

    assert result["status"] == "processed"
    assert result["event"] == "refund.processed"
