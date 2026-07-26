"""Teacher coupon models — first-month free group access."""
from __future__ import annotations

from pydantic import BaseModel, Field


class CreateCouponRequest(BaseModel):
    class_id: str = Field(..., min_length=1)


class RedeemCouponRequest(BaseModel):
    code: str = Field(..., min_length=4, max_length=32)


class RegisterDeviceTokenRequest(BaseModel):
    token: str = Field(..., min_length=10)
    platform: str = Field(default="android", pattern="^(android|ios|web)$")
