from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import referral_service

router = APIRouter(prefix="/api/v1/referrals", tags=["referrals"])


class RedeemRequest(BaseModel):
    code: str = Field(..., min_length=4, max_length=20)


@router.get("/me")
async def me(user: AuthenticatedUser = Depends(get_current_user)):
    return referral_service.get_referral_summary(user.user_id)


@router.post("/redeem")
async def redeem(body: RedeemRequest, user: AuthenticatedUser = Depends(get_current_user)):
    return referral_service.redeem_referral(user.user_id, body.code)