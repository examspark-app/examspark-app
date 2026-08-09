"""Groups share + teacher student performance."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.notification_service import notify_group_members_of_share
from app.services import notification_service as notif
from app.services.supabase_admin import get_supabase_admin
from app.services import teacher_performance_service as tps

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])


class ShareNotifyRequest(BaseModel):
    class_id: str = Field(..., min_length=1)
    shared_item_id: str | None = None
    title: str = Field(..., min_length=1)
    body: str = ""


class JoinNotifyRequest(BaseModel):
    """After Flutter join/accept/reject RPC — fan-out in-app + FCM."""

    event: str = Field(..., min_length=1)  # pending | accepted | rejected
    class_id: str | None = None
    request_id: str | None = None


class ShareToGroupRequest(BaseModel):
    class_id: str = Field(..., min_length=1)
    lecture_id: str = Field(..., min_length=1)
    type: str = Field(..., min_length=1)
    title: str = Field(..., min_length=1)
    body: str | None = None
    is_pinned: bool = False
    notify: bool = True
    # Teacher All / specific generated chips (notes, quiz, flashcards, …).
    shared_chips: list[str] | None = None


class AnnounceRequest(BaseModel):
    class_id: str = Field(..., min_length=1)
    title: str = Field(..., min_length=1, max_length=120)
    body: str = Field(..., min_length=1, max_length=2000)
    is_pinned: bool = False
    notify: bool = True


@router.post("/share")
async def share_to_group(
    body: ShareToGroupRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Teacher shares own recorded lecture to an owned group (server-enforced)."""
    try:
        item = tps.share_lecture_to_group(
            teacher_id=user.user_id,
            class_id=body.class_id,
            lecture_id=body.lecture_id,
            share_type=body.type,
            title=body.title,
            body=body.body,
            is_pinned=body.is_pinned,
            shared_chips=body.shared_chips,
        )
    except tps.TeacherPerformanceError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e

    notified = 0
    if body.notify:
        notified = notify_group_members_of_share(
            class_id=body.class_id,
            teacher_id=user.user_id,
            shared_item_id=str(item.get("id")) if item.get("id") else None,
            title=body.title,
            body=body.body or f"New {body.type} shared",
        )
    return {"item": item, "notified": notified}


@router.post("/announce")
async def post_announcement(
    body: AnnounceRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Teacher posts a text announcement (no student replies)."""
    try:
        item = tps.post_announcement_to_group(
            teacher_id=user.user_id,
            class_id=body.class_id,
            title=body.title,
            body=body.body,
            is_pinned=body.is_pinned,
        )
    except tps.TeacherPerformanceError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e

    notified = 0
    if body.notify:
        notified = notify_group_members_of_share(
            class_id=body.class_id,
            teacher_id=user.user_id,
            shared_item_id=str(item.get("id")) if item.get("id") else None,
            title=body.title,
            body=body.body[:120],
        )
    return {"item": item, "notified": notified}


@router.post("/join-notify")
async def join_notify(
    body: JoinNotifyRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Pending / accept / reject notifications (Notifications Priority A)."""
    event = (body.event or "").strip().lower()
    if event == "pending":
        class_id = (body.class_id or "").strip()
        if not class_id:
            raise HTTPException(status_code=400, detail="class_id required")
        return notif.notify_join_pending(
            class_id=class_id,
            student_id=user.user_id,
        )
    if event in ("accepted", "rejected"):
        request_id = (body.request_id or "").strip()
        if not request_id:
            raise HTTPException(status_code=400, detail="request_id required")
        return notif.notify_join_resolved(
            request_id=request_id,
            teacher_id=user.user_id,
            accepted=event == "accepted",
        )
    raise HTTPException(
        status_code=400,
        detail="event must be pending, accepted, or rejected",
    )


@router.post("/share-notify")
async def share_notify(
    body: ShareNotifyRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """After Flutter inserts group_shared_items, call this to fan-out notifications."""
    db = get_supabase_admin()
    class_row = (
        db.table("class_folders")
        .select("teacher_id")
        .eq("id", body.class_id)
        .maybe_single()
        .execute()
    )
    if not class_row.data:
        raise HTTPException(status_code=404, detail="Group not found")
    if str(class_row.data.get("teacher_id")) != str(user.user_id):
        raise HTTPException(status_code=403, detail="Only the group teacher can notify")

    count = notify_group_members_of_share(
        class_id=body.class_id,
        teacher_id=user.user_id,
        shared_item_id=body.shared_item_id,
        title=body.title,
        body=body.body,
    )
    return {"notified": count}


@router.get("/teacher/students")
async def teacher_students(
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Joined students across teacher's groups + quiz + daily active."""
    try:
        payload = tps.list_teacher_students(teacher_id=user.user_id)
    except tps.TeacherPerformanceError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e
    return payload


@router.get("/teacher/groups/{class_id}/students")
async def teacher_group_students(
    class_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """One group: members + last_active + quiz % (shared lectures only)."""
    try:
        return tps.list_group_students(
            teacher_id=user.user_id,
            class_id=class_id,
        )
    except tps.TeacherPerformanceError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


class HeartbeatRequest(BaseModel):
    class_id: str = Field(..., min_length=1)


@router.post("/heartbeat")
async def group_heartbeat(
    body: HeartbeatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Student opened a group channel — marks last_active_at (throttled)."""
    try:
        return tps.touch_group_activity(
            student_id=user.user_id,
            class_id=body.class_id,
        )
    except tps.TeacherPerformanceError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e)) from e


class PinSharedItemRequest(BaseModel):
    is_pinned: bool


@router.patch("/shared-items/{item_id}/pin")
async def pin_shared_item(
    item_id: str,
    body: PinSharedItemRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Teacher pins/unpins a shared item in their own group (sticky top)."""
    from app.services.plan_tier_service import (
        TeacherPlanRequiredError,
        require_active_teacher_plan,
        teacher_plan_locked_payload,
    )

    try:
        require_active_teacher_plan(user.user_id)
    except TeacherPlanRequiredError as e:
        raise HTTPException(status_code=403, detail=teacher_plan_locked_payload(e)) from e

    db = get_supabase_admin()
    item = (
        db.table("group_shared_items")
        .select("id, class_id, teacher_id")
        .eq("id", item_id)
        .limit(1)
        .execute()
    )
    rows = item.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="Shared item not found")
    row = rows[0]
    if str(row.get("teacher_id")) != str(user.user_id):
        raise HTTPException(status_code=403, detail="Only the group teacher can pin")

    class_row = (
        db.table("class_folders")
        .select("teacher_id")
        .eq("id", row["class_id"])
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes or str(classes[0].get("teacher_id")) != str(user.user_id):
        raise HTTPException(status_code=403, detail="Only the group teacher can pin")

    db.table("group_shared_items").update({"is_pinned": body.is_pinned}).eq(
        "id", item_id
    ).execute()

    # Optional: track primary pinned item on the class folder.
    if body.is_pinned:
        db.table("class_folders").update({"pinned_item_id": item_id}).eq(
            "id", row["class_id"]
        ).execute()
    else:
        folder = (
            db.table("class_folders")
            .select("pinned_item_id")
            .eq("id", row["class_id"])
            .limit(1)
            .execute()
        )
        if (folder.data or [{}])[0].get("pinned_item_id") == item_id:
            db.table("class_folders").update({"pinned_item_id": None}).eq(
                "id", row["class_id"]
            ).execute()

    return {"id": item_id, "is_pinned": body.is_pinned}
class ReportGroupRequest(BaseModel):
    class_id: str = Field(..., min_length=1)
    reason: str | None = None


@router.post("/report")
async def report_group(
    body: ReportGroupRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    db = get_supabase_admin()
    existing = (
        db.table("group_reports")
        .select("id")
        .eq("class_id", body.class_id)
        .eq("reporter_id", user.user_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        raise HTTPException(
            status_code=409,
            detail="You have already reported this group.",
        )
    db.table("group_reports").insert({
        "class_id": body.class_id,
        "reporter_id": user.user_id,
        "reason": body.reason,
    }).execute()
    return {"status": "ok"}


class SubmitReviewRequest(BaseModel):
    class_id: str = Field(..., min_length=1)
    rating: str = Field(..., pattern="^(good|bad)$")


@router.post("/review")
async def submit_teacher_review(
    body: SubmitReviewRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    db = get_supabase_admin()

    membership = (
        db.table("class_memberships")
        .select("id")
        .eq("class_id", body.class_id)
        .eq("student_id", user.user_id)
        .maybe_single()
        .execute()
    )

    if not membership.data:
        raise HTTPException(
            status_code=403,
            detail="Only joined members can review",
        )

    # Get the real teacher ID from the group/class.
    class_row = (
        db.table("class_folders")
        .select("teacher_id")
        .eq("id", body.class_id)
        .maybe_single()
        .execute()
    )

    if not class_row.data:
        raise HTTPException(
            status_code=404,
            detail="Group not found",
        )

    teacher_id = class_row.data["teacher_id"]

    db.table("teacher_reviews").upsert(
        {
            "teacher_id": teacher_id,
            "student_id": user.user_id,
            "class_id": body.class_id,
            "rating": body.rating,
        },
        on_conflict="teacher_id,student_id",
    ).execute()

    return {"status": "ok"}


@router.get("/teacher/{teacher_id}/reviews")
async def get_teacher_reviews(teacher_id: str):
    db = get_supabase_admin()
    rows = (
        db.table("teacher_reviews")
        .select("rating")
        .eq("teacher_id", teacher_id)
        .execute()
    )
    good = sum(1 for r in (rows.data or []) if r["rating"] == "good")
    bad = sum(1 for r in (rows.data or []) if r["rating"] == "bad")
    return {"good": good, "bad": bad, "total": good + bad}