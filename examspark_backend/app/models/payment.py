"""Pydantic models for payment architecture."""
from datetime import datetime
from enum import Enum
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class PaymentGateway(str, Enum):
    RAZORPAY = "razorpay"
    PHONEPE = "phonepe"
    GOOGLE_PLAY = "google_play"


class PaymentPlatform(str, Enum):
    WEB = "web"
    ANDROID = "android"


class PaymentStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    VERIFIED = "verified"
    FAILED = "failed"
    REFUNDED = "refunded"
    CANCELLED = "cancelled"


class SubscriptionStatus(str, Enum):
    ACTIVE = "active"
    PENDING = "pending"
    EXPIRED = "expired"
    CANCELLED = "cancelled"
    GRACE_PERIOD = "grace_period"


class PlanTier(str, Enum):
    FREE = "free"
    ENTRY = "entry"
    MID = "mid"
    PREMIUM = "premium"
    TEACHER = "teacher"


# ---------- Request / Response ----------


class CreateOrderRequest(BaseModel):
    user_id: UUID
    plan_id: str
    platform: PaymentPlatform
    gateway: PaymentGateway
    idempotency_key: str = Field(..., min_length=8, max_length=128)
    credit_pack_id: Optional[str] = None


class CreateOrderResponse(BaseModel):
    order_id: str
    status: PaymentStatus = PaymentStatus.PENDING
    amount_paise: int
    currency: str = "INR"
    gateway: PaymentGateway
    gateway_order_id: Optional[str] = None
    message: str = "Order created — payment gateway integration pending"


class VerifyPaymentRequest(BaseModel):
    order_id: str
    user_id: UUID
    gateway: PaymentGateway
    gateway_payment_id: Optional[str] = None
    gateway_signature: Optional[str] = None
    gateway_payload: dict[str, Any] = Field(default_factory=dict)
    idempotency_key: str


class VerifyPaymentResponse(BaseModel):
    order_id: str
    status: PaymentStatus
    subscription_id: Optional[UUID] = None
    credits_allocated: int = 0
    message: str


class WebhookPayload(BaseModel):
    gateway: PaymentGateway
    raw_body: bytes
    headers: dict[str, str]


class AllocateCreditsRequest(BaseModel):
    user_id: UUID
    credits: int
    source: str
    payment_id: Optional[UUID] = None
    idempotency_key: str


class SubscriptionActivateRequest(BaseModel):
    user_id: UUID
    plan_id: str
    payment_id: UUID
    platform: PaymentPlatform
    gateway: PaymentGateway
    expires_at: datetime


class PaymentRecord(BaseModel):
    id: UUID
    user_id: UUID
    order_id: str
    gateway: PaymentGateway
    platform: PaymentPlatform
    amount_paise: int
    currency: str
    status: PaymentStatus
    plan_id: Optional[str] = None
    credit_pack_id: Optional[str] = None
    idempotency_key: str
    created_at: datetime
    verified_at: Optional[datetime] = None
