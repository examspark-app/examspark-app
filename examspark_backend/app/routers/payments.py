"""Payment API routes — Razorpay Web (test/live keys via .env)."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.config import PaymentConfig
from app.models.payment import CreateOrderRequest, VerifyPaymentRequest
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import credits_service
from app.services.payment_orchestrator import PaymentOrchestrator
from app.services.webhook_service import WebhookService

router = APIRouter(prefix="/api/v1/payments", tags=["payments"])
_orchestrator = PaymentOrchestrator()
_webhooks = WebhookService()

# Dev mock: packs stay +50; subscription plans get full monthly credits
# (Teacher = 16,000 — not +50). Founder Jul 25, 2026.
_MOCK_PACK_CREDITS = 50


class MockDevPurchaseRequest(BaseModel):
    """Optional label for history — amounts are fixed server-side when IS_TESTING."""

    kind: str = Field(
        default="credit_pack",
        description="credit_pack | subscription",
    )
    plan_id: str | None = None
    credit_pack_id: str | None = None


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


@router.post("/mock-dev-purchase")
async def mock_dev_purchase(
    body: MockDevPurchaseRequest | None = None,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """IS_TESTING only — skip Google Play / Razorpay.

    - credit_pack: +50 credits (quick smoke top-up)
    - subscription + plan_id: activate plan AND grant full monthly credits
      (e.g. teacher → 16,000) so balance matches real buy behavior
    """
    if not PaymentConfig.is_testing():
        raise HTTPException(
            status_code=403,
            detail=(
                "Mock purchase disabled — set IS_TESTING=true in backend "
                ".env (dev only)"
            ),
        )

    from uuid import uuid4

    from app.constants.payment_catalog import (
        PLAN_MONTHLY_CREDITS,
        credits_for_plan,
    )
    from app.models.payment import PaymentGateway, PaymentPlatform

    body = body or MockDevPurchaseRequest()
    kind = (body.kind or "credit_pack").strip().lower()
    if kind not in ("credit_pack", "subscription"):
        kind = "credit_pack"

    plan_id = (body.plan_id or "").strip() or None
    activated_plan: str | None = None
    credits_to_grant = _MOCK_PACK_CREDITS

    if kind == "subscription" and plan_id:
        if plan_id not in PLAN_MONTHLY_CREDITS and plan_id != "free":
            raise HTTPException(
                status_code=400,
                detail=f"Unknown plan_id for mock: {plan_id}",
            )
        try:
            await _orchestrator.activate_subscription(
                user_id=UUID(user.user_id),
                plan_id=plan_id,
                payment_id=uuid4(),
                platform=PaymentPlatform.WEB,
                gateway=PaymentGateway.RAZORPAY,
            )
            activated_plan = plan_id
            credits_to_grant = credits_for_plan(plan_id)
            if credits_to_grant <= 0:
                credits_to_grant = _MOCK_PACK_CREDITS
        except Exception as e:  # noqa: BLE001
            raise HTTPException(
                status_code=400,
                detail=f"Mock plan activate failed: {e}",
            ) from e

    label = "Mock credit pack"
    if kind == "subscription":
        label = f"Mock subscription ({activated_plan or plan_id or 'plan'})"
    elif body.credit_pack_id:
        label = f"Mock pack ({body.credit_pack_id})"

    try:
        new_balance = credits_service.grant_credits(
            user_id=user.user_id,
            amount=credits_to_grant,
            description=f"[IS_TESTING] {label} — +{credits_to_grant} credits",
            action="mock_dev_purchase",
        )
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(e)) from e

    msg = f"Dev mock OK — +{credits_to_grant} credits"
    if activated_plan:
        msg += f" + plan `{activated_plan}` active"

    return {
        "status": "verified",
        "mock": True,
        "credits_allocated": credits_to_grant,
        "new_balance": new_balance,
        "kind": kind,
        "plan_id": activated_plan,
        "message": msg,
    }


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
