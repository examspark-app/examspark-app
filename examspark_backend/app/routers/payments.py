"""Payment API routes — Razorpay Web (test/live keys via .env)."""
from uuid import UUID

from fastapi import APIRouter, Depends, Request

from app.models.payment import CreateOrderRequest, VerifyPaymentRequest
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.payment_orchestrator import PaymentOrchestrator
from app.services.webhook_service import WebhookService

router = APIRouter(prefix="/api/v1/payments", tags=["payments"])
_orchestrator = PaymentOrchestrator()
_webhooks = WebhookService()


@router.post("/orders")
async def create_order(
    request: CreateOrderRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Create Razorpay order — amount from server catalog, never client."""
    return await _orchestrator.create_order(
        request,
        auth_user_id=UUID(user.user_id),
    )


@router.post("/verify")
async def verify_payment(
    request: VerifyPaymentRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Verify checkout signature → activate subscription / pack → credits."""
    return await _orchestrator.verify_payment(
        request,
        auth_user_id=UUID(user.user_id),
    )


@router.get("/status/{order_id}")
async def payment_status(
    order_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    return await _orchestrator.get_payment_status(
        order_id, user_id=UUID(user.user_id)
    )


@router.post("/webhooks/razorpay")
async def webhook_razorpay(request: Request):
    return await _webhooks.handle_razorpay(request)


@router.post("/webhooks/phonepe")
async def webhook_phonepe(request: Request):
    return await _webhooks.handle_phonepe(request)


@router.post("/webhooks/google-play")
async def webhook_google_play(request: Request):
    return await _webhooks.handle_google_play(request)
