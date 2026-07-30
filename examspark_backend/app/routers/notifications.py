"""In-app notifications API."""
from fastapi import APIRouter, Depends, HTTPException

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.notification_service import (
    list_notifications,
    mark_class_notifications_read,
    mark_notification_read,
)
from app.services.subscription_expiry_notify import (
    check_subscription_expiry_for_user,
)

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


@router.get("")
async def get_notifications(user: AuthenticatedUser = Depends(get_current_user)):
    return {"notifications": list_notifications(user_id=user.user_id)}


@router.post("/check-subscription-expiry")
async def check_subscription_expiry(
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Catch-up 7d/3d/1d/expired alerts for the logged-in user (deduped)."""
    try:
        return check_subscription_expiry_for_user(user.user_id)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.post("/class/{class_id}/read")
async def read_class_notifications(
    class_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        mark_class_notifications_read(user_id=user.user_id, class_id=class_id)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(e)) from e
    return {"ok": True}


@router.post("/{notification_id}/read")
async def read_notification(
    notification_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        mark_notification_read(user_id=user.user_id, notification_id=notification_id)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(e)) from e
    return {"ok": True}
