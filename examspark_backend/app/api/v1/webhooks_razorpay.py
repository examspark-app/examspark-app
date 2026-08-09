"""Razorpay webhook — payment.refunded / refund.processed → RefundService."""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os

from fastapi import APIRouter, HTTPException, Request

from app.services.refund_service import RefundNotFoundError, RefundService

logger = logging.getLogger(__name__)
router = APIRouter()

RAZORPAY_WEBHOOK_SECRET = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")


def _verify_signature(raw_body: bytes, signature: str) -> bool:
    if not RAZORPAY_WEBHOOK_SECRET or not signature:
        return False
    expected = hmac.new(
        RAZORPAY_WEBHOOK_SECRET.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


@router.post("/webhooks/razorpay")
async def razorpay_webhook(request: Request):
    raw_body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature", "")

    if not _verify_signature(raw_body, signature):
        logger.warning("Razorpay webhook: bad signature")
        raise HTTPException(status_code=400, detail="Invalid signature")

    try:
        payload = json.loads(raw_body)
    except Exception:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid JSON")

    event = payload.get("event", "")
    logger.info("Razorpay webhook event=%s", event)

    if event not in ("payment.refunded", "refund.processed"):
        return {"status": "ignored", "event": event}

    entity_payload = payload.get("payload", {})
    payment_entity = entity_payload.get("payment", {}).get("entity", {})
    refund_entity = entity_payload.get("refund", {}).get("entity", {})

    # payment.refunded → payment entity carries the id.
    # refund.processed → payment_id is on the refund entity.
    razorpay_payment_id = (
        payment_entity.get("id") or refund_entity.get("payment_id")
    )
    if not razorpay_payment_id:
        logger.warning("Razorpay webhook: no payment id in payload")
        return {"status": "ignored", "reason": "no_payment_id"}

    try:
        result = await RefundService().process_refund(
            gateway_payment_id=razorpay_payment_id,
            reason=f"razorpay_webhook_{event}",
        )
        return {"status": "ok", "result": result}
    except RefundNotFoundError:
        logger.warning(
            "Razorpay webhook: payment not found gateway_payment_id=%s",
            razorpay_payment_id,
        )
        # 200 so Razorpay doesn't retry forever for a payment we never had.
        return {"status": "not_found", "gateway_payment_id": razorpay_payment_id}
    except Exception:  # noqa: BLE001
        logger.exception("Razorpay webhook: refund processing failed")
        raise HTTPException(status_code=500, detail="Refund processing failed")