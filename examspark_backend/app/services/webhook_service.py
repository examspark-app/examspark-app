"""Webhook handlers — structure only."""
from fastapi import HTTPException, Request

from app.models.payment import PaymentGateway
from app.services.security import PaymentSecurity


class WebhookService:
    _processed_events: set[str] = set()

    async def handle_razorpay(self, request: Request) -> dict:
        # TODO: Razorpay Integration
        body = await request.body()
        signature = request.headers.get("X-Razorpay-Signature", "")
        if not PaymentSecurity.verify_razorpay_signature(body, signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")
        event_id = request.headers.get("X-Razorpay-Event-Id", "")
        if PaymentSecurity.is_replay(event_id, self._processed_events):
            return {"status": "duplicate_ignored"}
        # TODO: Parse event, update payments, activate subscription, credit_history
        # TODO: INSERT payment_webhooks
        return {"status": "received", "gateway": PaymentGateway.RAZORPAY.value, "todo": True}

    async def handle_phonepe(self, request: Request) -> dict:
        # TODO: PhonePe Integration
        body = await request.body()
        signature = request.headers.get("X-VERIFY", "")
        if not PaymentSecurity.verify_phonepe_signature(body, signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")
        return {"status": "received", "gateway": PaymentGateway.PHONEPE.value, "todo": True}

    async def handle_google_play(self, request: Request) -> dict:
        # TODO: Google Play Billing — Real-Time Developer Notifications (RTDN)
        body = await request.body()
        # TODO: Verify Pub/Sub message; decode subscription notification
        return {"status": "received", "gateway": PaymentGateway.GOOGLE_PLAY.value, "todo": True}
