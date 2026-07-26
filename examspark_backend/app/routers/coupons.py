"""Teacher coupon + device token routes."""
from fastapi import APIRouter, Depends, HTTPException

from app.models.coupon import (
    CreateCouponRequest,
    RedeemCouponRequest,
    RegisterDeviceTokenRequest,
)
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import coupon_service
from app.services.notification_service import register_device_token

router = APIRouter(prefix="/api/v1/coupons", tags=["coupons"])


@router.post("/create")
async def create_coupon(
    body: CreateCouponRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return coupon_service.create_coupon_for_class(
            teacher_id=user.user_id,
            class_id=body.class_id,
        )
    except coupon_service.CouponError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.get("/mine")
async def list_my_coupons(user: AuthenticatedUser = Depends(get_current_user)):
    return {"coupons": coupon_service.list_teacher_coupons(teacher_id=user.user_id)}


@router.get("/{coupon_id}/redemptions")
async def list_redemptions(
    coupon_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return {
            "redemptions": coupon_service.list_coupon_redemptions(
                teacher_id=user.user_id,
                coupon_id=coupon_id,
            )
        }
    except coupon_service.CouponError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.post("/redeem")
async def redeem_coupon(
    body: RedeemCouponRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        return coupon_service.redeem_coupon(
            student_id=user.user_id,
            code=body.code,
        )
    except coupon_service.CouponError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


@router.post("/device-token")
async def upsert_device_token(
    body: RegisterDeviceTokenRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Register FCM device token (Slice 3B). Soft-ok if table missing."""
    return register_device_token(
        user_id=user.user_id,
        token=body.token,
        platform=body.platform,
    )
