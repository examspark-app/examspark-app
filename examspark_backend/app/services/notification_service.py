"""In-app notifications + FCM device tokens (group post + join approval)."""
from __future__ import annotations

import logging
from typing import Any

from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)


def _insert_and_push(
    *,
    rows: list[dict[str, Any]],
    fcm_title: str,
    fcm_body: str,
    fcm_data: dict[str, str],
) -> int:
    if not rows:
        return 0
    db = get_supabase_admin()
    try:
        db.table("notifications").insert(rows).execute()
    except Exception as e:  # noqa: BLE001
        # Older DBs without event_type — retry without that column.
        if "event_type" in str(e):
            stripped = [
                {k: v for k, v in r.items() if k != "event_type"} for r in rows
            ]
            try:
                db.table("notifications").insert(stripped).execute()
            except Exception as e2:  # noqa: BLE001
                logger.warning("notifications insert failed: %s", e2)
                return 0
        else:
            logger.warning(
                "notifications insert failed (run teacher_coupon_migration.sql?): %s",
                e,
            )
            return 0

    try:
        from app.services.fcm_service import send_push_to_users

        user_ids = [str(r["user_id"]) for r in rows]
        send_push_to_users(
            user_ids=user_ids,
            title=fcm_title,
            body=fcm_body,
            data=fcm_data,
        )
    except Exception as e:  # noqa: BLE001
        logger.debug("FCM skipped: %s", e)

    return len(rows)


def notify_group_members_of_share(
    *,
    class_id: str,
    teacher_id: str,
    shared_item_id: str | None,
    title: str,
    body: str = "",
) -> int:
    """Insert one notification per student member (except teacher). Returns count."""
    db = get_supabase_admin()
    try:
        class_row = (
            db.table("class_folders")
            .select("name")
            .eq("id", class_id)
            .maybe_single()
            .execute()
        )
        group_name = (class_row.data or {}).get("name") or "Your group"
    except Exception:  # noqa: BLE001
        group_name = "Your group"

    preview = (body or title or "New content").strip()
    if len(preview) > 120:
        preview = preview[:117] + "..."

    members = (
        db.table("class_memberships")
        .select("student_id")
        .eq("class_id", class_id)
        .execute()
    )
    student_ids = [
        str(r["student_id"])
        for r in (members.data or [])
        if str(r.get("student_id")) != str(teacher_id)
    ]
    if not student_ids:
        return 0

    rows = [
        {
            "user_id": sid,
            "class_id": class_id,
            "shared_item_id": shared_item_id,
            "title": group_name,
            "body": preview,
            "event_type": "group_post",
        }
        for sid in student_ids
    ]
    return _insert_and_push(
        rows=rows,
        fcm_title=group_name,
        fcm_body=preview,
        fcm_data={
            "class_id": class_id,
            "type": "group_post",
            "route": "group_info",
        },
    )


def notify_join_pending(*, class_id: str, student_id: str) -> dict[str, Any]:
    """Free student requested Approve group → notify student + teacher."""
    db = get_supabase_admin()
    class_row = (
        db.table("class_folders")
        .select("id, name, teacher_id")
        .eq("id", class_id)
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes:
        return {"student": 0, "teacher": 0, "detail": "group_not_found"}
    row = classes[0]
    group_name = (row.get("name") or "Study Group").strip() or "Study Group"
    teacher_id = str(row.get("teacher_id") or "")
    if not teacher_id:
        return {"student": 0, "teacher": 0, "detail": "no_teacher"}

    pending = (
        db.table("group_join_requests")
        .select("id")
        .eq("class_id", class_id)
        .eq("student_id", student_id)
        .eq("status", "pending")
        .limit(1)
        .execute()
    )
    if not (pending.data or []):
        return {"student": 0, "teacher": 0, "detail": "not_pending"}

    student_body = f"Request sent — waiting for teacher to accept ({group_name})"
    teacher_body = f"New join request for {group_name}"

    n_student = _insert_and_push(
        rows=[
            {
                "user_id": student_id,
                "class_id": class_id,
                "shared_item_id": None,
                "title": group_name,
                "body": student_body,
                "event_type": "join_pending_student",
            }
        ],
        fcm_title=group_name,
        fcm_body=student_body,
        fcm_data={
            "class_id": class_id,
            "type": "join_pending_student",
            "route": "group_info",
        },
    )

    n_teacher = 0
    if str(teacher_id) != str(student_id):
        n_teacher = _insert_and_push(
            rows=[
                {
                    "user_id": teacher_id,
                    "class_id": class_id,
                    "shared_item_id": None,
                    "title": "Join request",
                    "body": teacher_body,
                    "event_type": "join_pending_teacher",
                }
            ],
            fcm_title="Join request",
            fcm_body=teacher_body,
            fcm_data={
                "class_id": class_id,
                "type": "join_pending_teacher",
                "route": "group_dashboard",
            },
        )

    return {"student": n_student, "teacher": n_teacher}


def notify_join_resolved(
    *,
    request_id: str,
    teacher_id: str,
    accepted: bool,
) -> dict[str, Any]:
    """Teacher accept/reject → notify the student."""
    db = get_supabase_admin()
    req = (
        db.table("group_join_requests")
        .select("id, class_id, student_id, status")
        .eq("id", request_id)
        .limit(1)
        .execute()
    )
    rows = req.data or []
    if not rows:
        return {"notified": 0, "detail": "request_not_found"}
    request = rows[0]
    class_id = str(request.get("class_id") or "")
    student_id = str(request.get("student_id") or "")
    status = str(request.get("status") or "")

    class_row = (
        db.table("class_folders")
        .select("id, name, teacher_id")
        .eq("id", class_id)
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes:
        return {"notified": 0, "detail": "group_not_found"}
    if str(classes[0].get("teacher_id")) != str(teacher_id):
        return {"notified": 0, "detail": "forbidden"}

    # Prefer resolved status; still notify after RPC even if race leaves pending briefly.
    if accepted and status == "rejected":
        return {"notified": 0, "detail": "already_rejected"}
    if not accepted and status == "accepted":
        return {"notified": 0, "detail": "already_accepted"}

    group_name = (classes[0].get("name") or "Study Group").strip() or "Study Group"
    if accepted:
        event_type = "join_accepted"
        body = f"You're in — joined {group_name}"
        title = group_name
    else:
        event_type = "join_rejected"
        body = f"Request declined — {group_name}"
        title = group_name

    n = _insert_and_push(
        rows=[
            {
                "user_id": student_id,
                "class_id": class_id,
                "shared_item_id": None,
                "title": title,
                "body": body,
                "event_type": event_type,
            }
        ],
        fcm_title=title,
        fcm_body=body,
        fcm_data={
            "class_id": class_id,
            "type": event_type,
            "route": "group_info",
        },
    )
    return {"notified": n, "class_id": class_id, "student_id": student_id}


def list_notifications(*, user_id: str, limit: int = 50) -> list[dict[str, Any]]:
    db = get_supabase_admin()
    try:
        res = (
            db.table("notifications")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return list(res.data or [])
    except Exception as e:  # noqa: BLE001
        logger.warning("list_notifications failed: %s", e)
        return []


def mark_notification_read(*, user_id: str, notification_id: str) -> None:
    db = get_supabase_admin()
    from datetime import datetime, timezone

    db.table("notifications").update(
        {"read_at": datetime.now(timezone.utc).isoformat()}
    ).eq("id", notification_id).eq("user_id", user_id).execute()


def mark_class_notifications_read(*, user_id: str, class_id: str) -> None:
    db = get_supabase_admin()
    from datetime import datetime, timezone

    db.table("notifications").update(
        {"read_at": datetime.now(timezone.utc).isoformat()}
    ).eq("user_id", user_id).eq("class_id", class_id).is_("read_at", "null").execute()


def register_device_token(*, user_id: str, token: str, platform: str) -> dict:
    db = get_supabase_admin()
    from datetime import datetime, timezone

    try:
        db.table("device_tokens").upsert(
            {
                "user_id": user_id,
                "token": token,
                "platform": platform,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
            on_conflict="token",
        ).execute()
        return {"ok": True}
    except Exception as e:  # noqa: BLE001
        logger.warning("device_tokens upsert failed: %s", e)
        return {"ok": False, "detail": str(e)}


def _plan_or_pack_label(*, plan_id: str | None, credit_pack_id: str | None) -> str:
    if credit_pack_id:
        return "credit pack"
    labels = {
        "plan_199": "₹199 plan",
        "plan_499": "₹499 plan",
        "plan_999": "₹999 plan",
        "teacher": "Teacher plan",
        "free": "Free plan",
    }
    if plan_id and plan_id in labels:
        return labels[plan_id]
    return "your purchase"


def notify_payment_success(
    *,
    user_id: str,
    order_id: str,
    plan_id: str | None = None,
    credit_pack_id: str | None = None,
) -> int:
    """In-app + FCM after verified payment. No credit amounts / paise in copy."""
    label = _plan_or_pack_label(plan_id=plan_id, credit_pack_id=credit_pack_id)
    title = "Payment successful"
    if credit_pack_id:
        body = f"{label.capitalize()} added — thank you"
    else:
        body = f"{label} is now active — thank you"
    return _insert_and_push(
        rows=[
            {
                "user_id": user_id,
                "class_id": None,
                "shared_item_id": None,
                "title": title,
                "body": body,
                "event_type": "payment_success",
            }
        ],
        fcm_title=title,
        fcm_body=body,
        fcm_data={
            "type": "payment_success",
            "route": "subscription",
            "order_id": order_id,
            "class_id": "",
        },
    )


def notify_payment_failed(
    *,
    user_id: str,
    order_id: str,
    reason: str | None = None,
) -> int:
    """In-app + FCM when verify fails. Soft copy — no internal error dumps."""
    title = "Payment failed"
    body = "Could not verify payment — try again or contact support"
    if reason and "not configured" in reason.lower():
        body = "Payment setup incomplete — try again later"
    return _insert_and_push(
        rows=[
            {
                "user_id": user_id,
                "class_id": None,
                "shared_item_id": None,
                "title": title,
                "body": body,
                "event_type": "payment_failed",
            }
        ],
        fcm_title=title,
        fcm_body=body,
        fcm_data={
            "type": "payment_failed",
            "route": "subscription",
            "order_id": order_id,
            "class_id": "",
        },
    )
