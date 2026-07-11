"""Payment API routes — architecture only, no live gateway."""
from fastapi import APIRouter, Request

from app.models.payment import CreateOrderRequest, VerifyPaymentRequest
from app.services.payment_orchestrator import PaymentOrchestrator
from app.services.webhook_service import WebhookService

router = APIRouter(prefix="/api/v1/payments", tags=["payments"])
_orchestrator = PaymentOrchestrator()
_webhooks = WebhookService()


@router.post("/orders")
async def create_order(request: CreateOrderRequest):
    """Step 2–3: Create order → pending payment."""
    return await _orchestrator.create_order(request)


@router.post("/verify")
async def verify_payment(request: VerifyPaymentRequest):
    """Step 4–7: Verify → activate subscription → allocate credits."""
    return await _orchestrator.verify_payment(request)


@router.get("/status/{order_id}")
async def payment_status(order_id: str):
    # TODO: Load from payments table
    return {
        "order_id": order_id,
        "status": "pending",
        "message": "TODO: DB lookup",
    }


@router.post("/webhooks/razorpay")
async def webhook_razorpay(request: Request):
    return await _webhooks.handle_razorpay(request)


@router.post("/webhooks/phonepe")
async def webhook_phonepe(request: Request):
    return await _webhooks.handle_phonepe(request)


@router.post("/webhooks/google-play")
async def webhook_google_play(request: Request):
    return await _webhooks.handle_google_play(request)
