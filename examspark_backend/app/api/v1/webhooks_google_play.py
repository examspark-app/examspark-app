"""Google Play Real-time Developer Notifications (RTDN) webhook.

Receives Pub/Sub push messages for voided purchases and revoked
subscriptions → RefundService. Verifies the push request is really
from Google Pub/Sub via the OIDC bearer token Google attaches.
"""
from __future__ import annotations

import base64
import json
import logging
import os

from fastapi import APIRouter, HTTPException, Request
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from app.services.refund_service import RefundNotFoundError, RefundService

logger = logging.getLogger(__name__)
router = APIRouter()

# The full public URL of this endpoint, e.g.
# https://api.yourapp.com/api/v1/payments/webhooks/google-play
GOOGLE_PLAY_WEBHOOK_AUDIENCE = os.getenv("GOOGLE_PLAY_WEBHOOK_AUDIENCE", "")

# notificationType values that mean "money given back / access revoked".
_SUBSCRIPTION_REVOKED = 12  # SUBSCRIPTION_REVOKED
_SUBSCRIPTION_EXPIRED = 13  # not a refund by itself — ignored


def _verify_pubsub_token(auth_header: str) -> bool:
    if not GOOGLE_PLAY_WEBHOOK_AUDIENCE:
        logger.warning("GOOGLE_PLAY_WEBHOOK_AUDIENCE not configured")
        return False
    if not auth_header.startswith("Bearer "):
        return False
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=GOOGLE_PLAY_WEBHOOK_AUDIENCE,
        )
        return True
    except Exception:  # noqa: BLE001
        logger.warning("Google Play webhook: token verification failed", exc_info=True)
        return False


@router.post("/webhooks/google-play")
async def google_play_webhook(request: Request):
    auth_header = request.headers.get("Authorization", "")
    if not _verify_pubsub_token(auth_header):
        raise HTTPException(status_code=401, detail="Invalid Pub/Sub token")

    body = await request.json()
    message = body.get("message", {})
    data_b64 = message.get("data", "")
    if not data_b64:
        return {"status": "ignored", "reason": "no_data"}

    try:
        decoded = base64.b64decode(data_b64).decode("utf-8")
        notification = json.loads(decoded)
    except Exception:  # noqa: BLE001
        logger.exception("Google Play webhook: could not decode message")
        raise HTTPException(status_code=400, detail="Bad message payload")

    logger.info("Google Play RTDN: %s", notification)

    purchase_token: str | None = None
    is_refund_event = False

    # One-time products voided (refund/chargeback on a credit pack).
    voided = notification.get("voidedPurchaseNotification")
    if voided:
        purchase_token = voided.get("purchaseToken")
        is_refund_event = True

    # Subscriptions revoked (refund on a plan).
    sub_notif = notification.get("subscriptionNotification")
    if sub_notif and sub_notif.get("notificationType") == _SUBSCRIPTION_REVOKED:
        purchase_token = sub_notif.get("purchaseToken")
        is_refund_event = True

    if not is_refund_event or not purchase_token:
        return {"status": "ignored", "reason": "not_a_refund_event"}

    try:
        result = await RefundService().process_refund(
            gateway_payment_id=purchase_token,
            reason="google_play_rtdn",
        )
        return {"status": "ok", "result": result}
    except RefundNotFoundError:
        logger.warning(
            "Google Play webhook: payment not found purchase_token=%s",
            purchase_token,
        )
        return {"status": "not_found", "purchase_token": purchase_token}
    except Exception:  # noqa: BLE001
        logger.exception("Google Play webhook: refund processing failed")
        raise HTTPException(status_code=500, detail="Refund processing failed")