"""Teacher coupon generate + redeem (first-month free, 50 credits, join bypass)."""
from __future__ import annotations

import logging
import secrets
import string
from datetime import datetime, timedelta, timezone

from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

COUPON_CREDITS = 0  # Free plan already has 50/mo — do NOT grant extra on coupon join
COUPON_ACCESS_DAYS = 30
COUPON_URGENCY_DAYS = 7
COUPON_MAX_REDEMPTIONS = 100


class CouponError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _generate_code(length: int = 8) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def create_coupon_for_class(*, teacher_id: str, class_id: str) -> dict:
    db = get_supabase_admin()
    class_row = (
        db.table("class_folders")
        .select("id, teacher_id, name")
        .eq("id", class_id)
        .maybe_single()
        .execute()
    )
    data = class_row.data
    if not data:
        raise CouponError("Group not found", 404)
    if str(data.get("teacher_id")) != str(teacher_id):
        raise CouponError("You can only create coupons for your own groups", 403)

    code = _generate_code()
    last_err: Exception | None = None
    for _ in range(5):
        try:
            inserted = (
                db.table("teacher_coupons")
                .insert(
                    {
                        "teacher_id": teacher_id,
                        "class_id": class_id,
                        "code": code,
                        "max_redemptions": COUPON_MAX_REDEMPTIONS,
                        "redeemed_count": 0,
                        "active": True,
                    }
                )
                .execute()
            )
            rows = inserted.data or []
            if not rows:
                raise CouponError("Coupon insert returned no row", 500)
            row = rows[0]
            return {
                "coupon_id": row["id"],
                "code": row["code"],
                "class_id": class_id,
                "class_name": data.get("name"),
                "max_redemptions": COUPON_MAX_REDEMPTIONS,
                "redeemed_count": 0,
            }
        except Exception as e:  # noqa: BLE001
            last_err = e
            msg = str(e).lower()
            # Unique code collision → retry; anything else → stop with real reason.
            if "duplicate" in msg or "unique" in msg:
                code = _generate_code()
                continue
            logger.exception("coupon create failed for class %s", class_id)
            if "teacher_coupons" in msg or "does not exist" in msg or "42p01" in msg:
                raise CouponError(
                    "Coupon tables missing — run teacher_coupon_migration.sql "
                    "in Supabase SQL Editor, then retry.",
                    503,
                ) from e
            raise CouponError(f"Could not create coupon: {e}", 500) from e
    logger.error("coupon create exhausted retries: %s", last_err)
    raise CouponError(
        f"Could not generate a unique coupon code. Retry. ({last_err})",
        500,
    )


def list_teacher_coupons(*, teacher_id: str) -> list[dict]:
    db = get_supabase_admin()
    res = (
        db.table("teacher_coupons")
        .select("id, class_id, code, max_redemptions, redeemed_count, active, created_at")
        .eq("teacher_id", teacher_id)
        .order("created_at", desc=True)
        .execute()
    )
    return list(res.data or [])


def list_coupon_redemptions(*, teacher_id: str, coupon_id: str) -> list[dict]:
    db = get_supabase_admin()
    coupon = (
        db.table("teacher_coupons")
        .select("id")
        .eq("id", coupon_id)
        .eq("teacher_id", teacher_id)
        .maybe_single()
        .execute()
    )
    if not coupon.data:
        raise CouponError("Coupon not found", 404)
    res = (
        db.table("coupon_redemptions")
        .select("id, student_id, class_id, redeemed_at, access_ends_at, urgency_ends_at")
        .eq("coupon_id", coupon_id)
        .order("redeemed_at", desc=True)
        .execute()
    )
    return list(res.data or [])


def redeem_coupon(*, student_id: str, code: str) -> dict:
    db = get_supabase_admin()
    clean = (code or "").strip().upper()
    if not clean:
        raise CouponError("Enter a coupon code")

    coupon_res = (
        db.table("teacher_coupons")
        .select("*")
        .eq("code", clean)
        .eq("active", True)
        .maybe_single()
        .execute()
    )
    coupon = coupon_res.data
    if not coupon:
        raise CouponError("Invalid coupon code", 404)

    if int(coupon.get("redeemed_count") or 0) >= int(
        coupon.get("max_redemptions") or COUPON_MAX_REDEMPTIONS
    ):
        raise CouponError("This coupon has reached its 100-student limit")

    coupon_id = coupon["id"]
    class_id = coupon["class_id"]

    existing = (
        db.table("coupon_redemptions")
        .select("id")
        .eq("coupon_id", coupon_id)
        .eq("student_id", student_id)
        .maybe_single()
        .execute()
    )
    if existing.data:
        raise CouponError("You already redeemed this coupon")

    membership = (
        db.table("class_memberships")
        .select("id")
        .eq("class_id", class_id)
        .eq("student_id", student_id)
        .maybe_single()
        .execute()
    )
    if membership.data:
        raise CouponError("You are already a member of this group")

    now = _now()
    access_ends = now + timedelta(days=COUPON_ACCESS_DAYS)
    urgency_ends = access_ends + timedelta(days=COUPON_URGENCY_DAYS)

    # Insert membership first (trigger allows coupon_id path).
    try:
        db.table("class_memberships").insert(
            {
                "class_id": class_id,
                "student_id": student_id,
                "coupon_id": coupon_id,
                "join_type": "coupon",
            }
        ).execute()
    except Exception as e:  # noqa: BLE001
        raise CouponError(f"Could not join group: {e}") from e

    try:
        db.table("coupon_redemptions").insert(
            {
                "coupon_id": coupon_id,
                "student_id": student_id,
                "class_id": class_id,
                "redeemed_at": now.isoformat(),
                "access_ends_at": access_ends.isoformat(),
                "urgency_ends_at": urgency_ends.isoformat(),
                "credits_granted": COUPON_CREDITS,
            }
        ).execute()
    except Exception as e:  # noqa: BLE001
        # Roll back membership if redemption insert fails.
        db.table("class_memberships").delete().eq("class_id", class_id).eq(
            "student_id", student_id
        ).execute()
        raise CouponError(f"Could not record coupon redemption: {e}") from e

    new_count = int(coupon.get("redeemed_count") or 0) + 1
    db.table("teacher_coupons").update({"redeemed_count": new_count}).eq(
        "id", coupon_id
    ).execute()

    # No extra credits: Free signup already has 50/mo. Coupon = group access only.

    class_row = (
        db.table("class_folders")
        .select("id, name, subject, join_code, teacher_id")
        .eq("id", class_id)
        .maybe_single()
        .execute()
    )

    return {
        "class_id": class_id,
        "class": class_row.data,
        "credits_granted": 0,
        "access_ends_at": access_ends.isoformat(),
        "urgency_ends_at": urgency_ends.isoformat(),
        "message": (
            "Joined with teacher coupon — first-month free group access "
            "(same group as paid joiners). Free plan already includes 50 credits/month "
            "(no extra coupon grant). No payment / no teacher commission for this join."
        ),
    }
