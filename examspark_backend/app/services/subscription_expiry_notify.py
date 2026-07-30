"""Subscription expiry notifications — 7d / 3d / 1d / expired (Notifications A2)."""
from __future__ import annotations

import logging
from datetime import date, datetime, timezone
from typing import Any

from app.services.notification_service import _insert_and_push
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

_PAID_PLANS = frozenset({"plan_199", "plan_499", "plan_999", "teacher"})

_ALERT_ORDER = (
    ("expiring_7d", 7),
    ("expiring_3d", 3),
    ("expiring_1d", 1),
)


def _parse_ts(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            raw = value.replace("Z", "+00:00")
            dt = datetime.fromisoformat(raw)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def _plan_label(plan_id: str) -> str:
    labels = {
        "plan_199": "₹199 plan",
        "plan_499": "₹499 plan",
        "plan_999": "₹999 plan",
        "teacher": "Teacher plan",
    }
    return labels.get(plan_id, "Your plan")


def _already_sent(
    db: Any,
    *,
    subscription_id: str,
    alert_kind: str,
    period_end: date,
) -> bool:
    try:
        res = (
            db.table("subscription_expiry_alerts")
            .select("id")
            .eq("subscription_id", subscription_id)
            .eq("alert_kind", alert_kind)
            .eq("period_end", period_end.isoformat())
            .limit(1)
            .execute()
        )
        return bool(res.data)
    except Exception as e:  # noqa: BLE001
        logger.warning("subscription_expiry_alerts read failed: %s", e)
        return False


def _mark_sent(
    db: Any,
    *,
    user_id: str,
    subscription_id: str,
    alert_kind: str,
    period_end: date,
) -> bool:
    try:
        db.table("subscription_expiry_alerts").upsert(
            {
                "user_id": user_id,
                "subscription_id": subscription_id,
                "alert_kind": alert_kind,
                "period_end": period_end.isoformat(),
            },
            on_conflict="subscription_id,alert_kind,period_end",
        ).execute()
        return True
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "subscription_expiry_alerts upsert failed "
            "(run notifications_subscription_expiry_migration.sql?): %s",
            e,
        )
        return False


def _send_expiry_alert(
    *,
    user_id: str,
    subscription_id: str,
    plan_id: str,
    alert_kind: str,
    period_end: date,
    days_left: int,
) -> bool:
    db = get_supabase_admin()
    if _already_sent(
        db,
        subscription_id=subscription_id,
        alert_kind=alert_kind,
        period_end=period_end,
    ):
        return False

    label = _plan_label(plan_id)
    if alert_kind == "expired":
        title = "Plan expired"
        body = f"{label} ended — renew to keep paid features"
    elif days_left <= 1:
        title = "Plan ends tomorrow"
        body = f"{label} expires soon — renew anytime"
    else:
        title = f"Plan ends in {days_left} days"
        body = f"{label} expires on {period_end.isoformat()} — renew anytime"

    n = _insert_and_push(
        rows=[
            {
                "user_id": user_id,
                "class_id": None,
                "shared_item_id": None,
                "title": title,
                "body": body,
                "event_type": alert_kind,
            }
        ],
        fcm_title=title,
        fcm_body=body,
        fcm_data={
            "type": alert_kind,
            "route": "subscription",
            "class_id": "",
        },
    )
    if n <= 0:
        return False
    return _mark_sent(
        db,
        user_id=user_id,
        subscription_id=subscription_id,
        alert_kind=alert_kind,
        period_end=period_end,
    )


def check_subscription_expiry_for_user(user_id: str) -> dict[str, Any]:
    """Catch-up alerts for one user (call on app open / bell open)."""
    db = get_supabase_admin()
    try:
        res = (
            db.table("user_subscriptions")
            .select("id, plan_id, status, current_period_end")
            .eq("user_id", user_id)
            .in_("status", ["active", "grace_period", "expired"])
            .order("current_period_end", desc=True)
            .limit(5)
            .execute()
        )
    except Exception as e:  # noqa: BLE001
        logger.warning("user_subscriptions read failed: %s", e)
        return {"sent": [], "detail": str(e)}

    rows = res.data or []
    if not rows:
        return {"sent": [], "detail": "no_subscription"}

    now = datetime.now(timezone.utc)
    today = now.date()
    sent: list[str] = []

    # Prefer newest paid row.
    chosen: dict[str, Any] | None = None
    for r in rows:
        plan_id = str(r.get("plan_id") or "")
        if plan_id in _PAID_PLANS:
            chosen = r
            break
    if chosen is None:
        return {"sent": [], "detail": "no_paid_plan"}

    plan_id = str(chosen.get("plan_id") or "")
    sub_id = str(chosen.get("id") or "")
    status = str(chosen.get("status") or "")
    end = _parse_ts(chosen.get("current_period_end"))
    if not sub_id or end is None:
        return {"sent": [], "detail": "bad_row"}

    period_end = end.date()
    days_left = (period_end - today).days

    if status == "expired" or days_left <= 0:
        if _send_expiry_alert(
            user_id=user_id,
            subscription_id=sub_id,
            plan_id=plan_id,
            alert_kind="expired",
            period_end=period_end,
            days_left=days_left,
        ):
            sent.append("expired")
        return {"sent": sent, "days_left": days_left, "plan_id": plan_id}

    # Catch-up: if within 7 days and 7d not sent, send 7d; same for 3d/1d.
    for kind, threshold in _ALERT_ORDER:
        if days_left <= threshold:
            if _send_expiry_alert(
                user_id=user_id,
                subscription_id=sub_id,
                plan_id=plan_id,
                alert_kind=kind,
                period_end=period_end,
                days_left=days_left,
            ):
                sent.append(kind)

    return {"sent": sent, "days_left": days_left, "plan_id": plan_id}
