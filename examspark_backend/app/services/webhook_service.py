"""Webhook handlers — Razorpay + Play fulfill / refund."""
from __future__ import annotations

import base64
import json
import logging

from fastapi import HTTPException, Request

from app.models.payment import PaymentGateway
from app.services.payment_orchestrator import PaymentOrchestrator
from app.services.refund_service import RefundNotFoundError, RefundService
from app.services.security import PaymentSecurity
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

_RAZORPAY_CAPTURE_EVENTS = {
    "payment.captured",
    "payment.authorized",
    "order.paid",
}
_RAZORPAY_REFUND_EVENTS = {
    "refund.processed",
    "refund.failed",  # record only
    "payment.refunded",
}


class WebhookService:
    _processed_events: set[str] = set()

    def __init__(self) -> None:
        self._orchestrator = PaymentOrchestrator()
        self._refunds = RefundService()

    async def handle_razorpay(self, request: Request) -> dict:
        body = await request.body()
        signature = request.headers.get("X-Razorpay-Signature", "")
        if not PaymentSecurity.verify_razorpay_signature(body, signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")

        try:
            payload = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=400, detail="Invalid JSON body") from e

        event_type = str(payload.get("event") or "")
        event_id = (
            request.headers.get("X-Razorpay-Event-Id")
            or payload.get("id")
            or PaymentSecurity.hash_payload(body)
        )
        event_id = str(event_id)

        client = get_supabase_admin()
        existing = (
            client.table("payment_webhooks")
            .select("id, status")
            .eq("gateway", "razorpay")
            .eq("event_id", event_id)
            .limit(1)
            .execute()
        )
        if existing.data:
            return {"status": "duplicate_ignored", "event_id": event_id}

        if PaymentSecurity.is_replay(event_id, self._processed_events):
            return {"status": "duplicate_ignored", "event_id": event_id}

        client.table("payment_webhooks").insert(
            {
                "gateway": "razorpay",
                "event_id": event_id,
                "event_type": event_type or "unknown",
                "payload_hash": PaymentSecurity.hash_payload(body),
                "payload": payload,
                "status": "received",
            }
        ).execute()

        if event_type in _RAZORPAY_REFUND_EVENTS and event_type != "refund.failed":
            result = await self._handle_razorpay_refund(payload)
            client.table("payment_webhooks").update(
                {"status": "processed", "processed_at": _utcnow_iso()}
            ).eq("gateway", "razorpay").eq("event_id", event_id).execute()
            return {
                "status": "processed",
                "event": event_type,
                "gateway": PaymentGateway.RAZORPAY.value,
                "refund": result,
            }

        if event_type not in _RAZORPAY_CAPTURE_EVENTS:
            client.table("payment_webhooks").update({"status": "processed"}).eq(
                "gateway", "razorpay"
            ).eq("event_id", event_id).execute()
            return {
                "status": "ignored",
                "event": event_type,
                "gateway": PaymentGateway.RAZORPAY.value,
            }

        entity = (
            (payload.get("payload") or {}).get("payment") or {}
        ).get("entity") or {}
        gateway_order_id = entity.get("order_id")
        gateway_payment_id = entity.get("id")
        if not gateway_order_id:
            order_entity = (
                (payload.get("payload") or {}).get("order") or {}
            ).get("entity") or {}
            gateway_order_id = order_entity.get("id")

        if not gateway_order_id:
            logger.warning("Razorpay webhook missing order_id event=%s", event_type)
            client.table("payment_webhooks").update({"status": "failed"}).eq(
                "gateway", "razorpay"
            ).eq("event_id", event_id).execute()
            return {"status": "failed", "message": "missing order_id"}

        payment_resp = (
            client.table("payments")
            .select("*")
            .eq("gateway_order_id", gateway_order_id)
            .limit(1)
            .execute()
        )
        if not payment_resp.data:
            client.table("payment_webhooks").update({"status": "failed"}).eq(
                "gateway", "razorpay"
            ).eq("event_id", event_id).execute()
            return {"status": "unknown_order", "gateway_order_id": gateway_order_id}

        payment = payment_resp.data[0]
        result = await self._orchestrator.fulfill_verified_payment(
            payment=payment,
            gateway_payment_id=gateway_payment_id,
            fulfillment_idempotency_key=f"fulfill_{payment['order_id']}",
        )

        client.table("payment_webhooks").update(
            {
                "status": "processed",
                "processed_at": _utcnow_iso(),
            }
        ).eq("gateway", "razorpay").eq("event_id", event_id).execute()

        return {
            "status": "processed",
            "gateway": PaymentGateway.RAZORPAY.value,
            "order_id": result.order_id,
            "payment_status": result.status.value,
            "credits_allocated": result.credits_allocated,
        }

    async def _handle_razorpay_refund(self, payload: dict) -> dict:
        payment_entity = (
            (payload.get("payload") or {}).get("payment") or {}
        ).get("entity") or {}
        refund_entity = (
            (payload.get("payload") or {}).get("refund") or {}
        ).get("entity") or {}

        gateway_payment_id = payment_entity.get("id") or refund_entity.get("payment_id")
        try:
            return await self._refunds.process_refund(
                gateway_payment_id=gateway_payment_id,
                reason=f"razorpay_{(payload.get('event') or 'refund')}",
            )
        except RefundNotFoundError as e:
            logger.warning("Razorpay refund payment not found: %s", e)
            return {"status": "unknown_payment", "gateway_payment_id": gateway_payment_id}

    async def handle_phonepe(self, request: Request) -> dict:
        body = await request.body()
        signature = request.headers.get("X-VERIFY", "")
        if not PaymentSecurity.verify_phonepe_signature(body, signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")
        return {"status": "received", "gateway": PaymentGateway.PHONEPE.value, "todo": True}

    async def handle_google_play(self, request: Request) -> dict:
        """Play RTDN (Pub/Sub push) or JSON test payload with purchaseToken."""
        body = await request.body()
        try:
            payload = json.loads(body.decode("utf-8")) if body else {}
        except json.JSONDecodeError as e:
            raise HTTPException(status_code=400, detail="Invalid JSON body") from e

        event_id = str(
            payload.get("message", {}).get("messageId")
            or payload.get("event_id")
            or PaymentSecurity.hash_payload(body or b"{}")
        )

        client = get_supabase_admin()
        existing = (
            client.table("payment_webhooks")
            .select("id")
            .eq("gateway", "google_play")
            .eq("event_id", event_id)
            .limit(1)
            .execute()
        )
        if existing.data:
            return {"status": "duplicate_ignored", "event_id": event_id}

        client.table("payment_webhooks").insert(
            {
                "gateway": "google_play",
                "event_id": event_id,
                "event_type": str(payload.get("event") or "rtdn"),
                "payload_hash": PaymentSecurity.hash_payload(body or b"{}"),
                "payload": payload,
                "status": "received",
            }
        ).execute()

        notification = self._decode_play_notification(payload)
        # voidedPurchaseNotification / refund-like
        voided = notification.get("voidedPurchaseNotification") or {}
        one_time = notification.get("oneTimeProductNotification") or {}
        sub_n = notification.get("subscriptionNotification") or {}

        purchase_token = (
            voided.get("purchaseToken")
            or payload.get("purchase_token")
            or payload.get("purchaseToken")
        )
        # subscriptionNotification type 12/13 often cancel; voided is clearest refund signal
        is_voided = bool(voided) or payload.get("event") in (
            "voided_purchase",
            "refund",
            "subscription_revoked",
        )
        # Also treat explicit refund flag from test/harness
        if payload.get("refund") is True:
            is_voided = True

        if not is_voided:
            client.table("payment_webhooks").update(
                {"status": "processed", "processed_at": _utcnow_iso()}
            ).eq("gateway", "google_play").eq("event_id", event_id).execute()
            return {
                "status": "ignored",
                "gateway": PaymentGateway.GOOGLE_PLAY.value,
                "note": "No voided/refund notification — Pub/Sub configure for voided purchases",
                "has_subscription_notification": bool(sub_n),
                "has_one_time_notification": bool(one_time),
            }

        try:
            result = await self._refunds.process_refund(
                gateway_payment_id=purchase_token,
                order_id=payload.get("order_id"),
                reason="google_play_voided_or_refund",
            )
        except RefundNotFoundError:
            client.table("payment_webhooks").update({"status": "failed"}).eq(
                "gateway", "google_play"
            ).eq("event_id", event_id).execute()
            return {
                "status": "unknown_payment",
                "gateway": PaymentGateway.GOOGLE_PLAY.value,
                "purchase_token": purchase_token,
            }

        client.table("payment_webhooks").update(
            {"status": "processed", "processed_at": _utcnow_iso()}
        ).eq("gateway", "google_play").eq("event_id", event_id).execute()

        return {
            "status": "processed",
            "gateway": PaymentGateway.GOOGLE_PLAY.value,
            "refund": result,
        }

    def _decode_play_notification(self, payload: dict) -> dict:
        """Decode Pub/Sub message.data if present (base64 JSON)."""
        message = payload.get("message") or {}
        data_b64 = message.get("data")
        if not data_b64:
            return payload.get("notification") or payload
        try:
            raw = base64.b64decode(data_b64)
            return json.loads(raw.decode("utf-8"))
        except Exception:  # noqa: BLE001
            logger.warning("Could not decode Play RTDN message.data")
            return {}


def _utcnow_iso() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()
