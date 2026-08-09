"""PhonePe callback webhook — server-to-server payment confirmation."""
import base64
import hashlib
import json
import logging
import os

from fastapi import APIRouter, Request

from app.services.payment_orchestrator import PaymentOrchestrator
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/api/v1/payments/webhooks/phonepe")
async def phonepe_webhook(request: Request):
    body = await request.json()
    response_b64 = body.get("response", "")
    x_verify = request.headers.get("X-VERIFY", "")

    salt_key = os.getenv("PHONEPE_SALT_KEY", "")
    salt_index = os.getenv("PHONEPE_SALT_INDEX", "1")
    expected = hashlib.sha256(
        f"{response_b64}{salt_key}".encode()
    ).hexdigest() + f"###{salt_index}"

    if x_verify != expected:
        logger.warning("PhonePe webhook: checksum mismatch")
        return {"status": "ignored", "reason": "bad_checksum"}

    decoded = json.loads(base64.b64decode(response_b64))
    order_id = decoded.get("data", {}).get("merchantTransactionId")
    state = decoded.get("data", {}).get("state")

    if not order_id or state != "COMPLETED":
        return {"status": "ignored", "reason": "not_completed"}

    db = get_supabase_admin()
    row = (
        db.table("payments")
        .select("*")
        .eq("order_id", order_id)
        .limit(1)
        .execute()
    )
    if not row.data:
        return {"status": "not_found", "order_id": order_id}

    result = await PaymentOrchestrator().fulfill_verified_payment(
        payment=row.data[0],
        gateway_payment_id=decoded.get("data", {}).get("transactionId"),
        fulfillment_idempotency_key=f"phonepe_webhook_{order_id}",
    )
    return {"status": "ok", "result": result.message}