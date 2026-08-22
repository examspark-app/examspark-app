from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services import device_account_service as devices

router = APIRouter(prefix="/api/v1/device-accounts", tags=["device-accounts"])


class DeviceRequest(BaseModel):
    device_id: str = Field(..., min_length=8, max_length=200)


@router.post("/check")
async def check(body: DeviceRequest):
    try:
        count = devices.account_count(body.device_id)
        return {"allowed": count < devices.MAX_ACCOUNTS_PER_DEVICE, "count": count}
    except Exception:
        # Device enforcement is fail-open when the identifier/database is unavailable.
        return {"allowed": True, "count": None}


@router.post("/register")
async def register(
    body: DeviceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    devices.register(user.user_id, body.device_id)
    return {"ok": True}