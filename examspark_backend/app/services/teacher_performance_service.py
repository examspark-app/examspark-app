"""Teacher student performance — quiz_attempts aggregates for dashboard."""
from __future__ import annotations

from calendar import monthrange
from datetime import datetime, timedelta, timezone
from typing import Any

from app.services.supabase_admin import get_supabase_admin


class TeacherPerformanceError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _pct(attempts: list[dict[str, Any]]) -> float | None:
    if not attempts:
        return None
    total_pct = 0.0
    n = 0
    for a in attempts:
        score = a.get("score")
        total = a.get("total")
        if not isinstance(score, (int, float)) or not isinstance(total, (int, float)):
            continue
        if total <= 0:
            continue
        total_pct += (float(score) / float(total)) * 100.0
        n += 1
    if n == 0:
        return None
    return round(total_pct / n, 1)


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


def _filter_window(
    attempts: list[dict[str, Any]], start: datetime, end: datetime
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for a in attempts:
        created = _parse_ts(a.get("created_at"))
        if created is None:
            continue
        if start <= created < end:
            out.append(a)
    return out


def _month_bounds(year: int, month: int) -> tuple[datetime, datetime]:
    start = datetime(year, month, 1, tzinfo=timezone.utc)
    last_day = monthrange(year, month)[1]
    end = datetime(year, month, last_day, 23, 59, 59, tzinfo=timezone.utc) + timedelta(
        seconds=1
    )
    return start, end


def _prev_month(year: int, month: int) -> tuple[int, int]:
    if month == 1:
        return year - 1, 12
    return year, month - 1


def _display_name(user_row: dict[str, Any] | None) -> str:
    if not user_row:
        return "Student"
    for key in ("username", "full_name", "display_name", "name", "email"):
        val = user_row.get(key)
        if isinstance(val, str) and val.strip():
            if key == "email" and "@" in val:
                return val.split("@", 1)[0]
            return val.strip()
    return "Student"


def ensure_previous_month_snapshots(teacher_id: str) -> None:
    """Lazy upsert: save previous calendar month avg if missing."""
    now = _utc_now()
    py, pm = _prev_month(now.year, now.month)
    year_month = f"{py:04d}-{pm:02d}"
    start, end = _month_bounds(py, pm)

    db = get_supabase_admin()
    classes = (
        db.table("class_folders")
        .select("id")
        .eq("teacher_id", teacher_id)
        .execute()
    )
    class_ids = [str(c["id"]) for c in (classes.data or []) if c.get("id")]
    if not class_ids:
        return

    memberships = (
        db.table("class_memberships")
        .select("student_id")
        .in_("class_id", class_ids)
        .execute()
    )
    student_ids = sorted(
        {
            str(m["student_id"])
            for m in (memberships.data or [])
            if m.get("student_id")
        }
    )
    if not student_ids:
        return

    lectures = (
        db.table("lectures")
        .select("id")
        .eq("user_id", teacher_id)
        .execute()
    )
    lecture_ids = [str(r["id"]) for r in (lectures.data or []) if r.get("id")]
    if not lecture_ids:
        return

    attempts_res = (
        db.table("quiz_attempts")
        .select("user_id, score, total, lecture_id, created_at")
        .in_("lecture_id", lecture_ids)
        .in_("user_id", student_ids)
        .gte("created_at", start.isoformat())
        .lt("created_at", end.isoformat())
        .execute()
    )
    by_student: dict[str, list[dict[str, Any]]] = {sid: [] for sid in student_ids}
    for a in attempts_res.data or []:
        sid = str(a.get("user_id") or "")
        if sid in by_student:
            by_student[sid].append(a)

    for sid, rows in by_student.items():
        existing = (
            db.table("teacher_student_month_stats")
            .select("id")
            .eq("teacher_id", teacher_id)
            .eq("student_id", sid)
            .eq("year_month", year_month)
            .limit(1)
            .execute()
        )
        if existing.data:
            continue
        avg = _pct(rows)
        if avg is None and not rows:
            avg = 0.0
        db.table("teacher_student_month_stats").upsert(
            {
                "teacher_id": teacher_id,
                "student_id": sid,
                "year_month": year_month,
                "avg_percent": avg if avg is not None else 0.0,
                "attempt_count": len(rows),
            },
            on_conflict="teacher_id,student_id,year_month",
        ).execute()


def touch_group_activity(*, student_id: str, class_id: str) -> dict[str, Any]:
    """Student opened a group channel — update last_active_at (throttled)."""
    class_id = (class_id or "").strip()
    if not class_id:
        raise TeacherPerformanceError("class_id required", status_code=400)

    db = get_supabase_admin()
    row = (
        db.table("class_memberships")
        .select("id, last_active_at")
        .eq("class_id", class_id)
        .eq("student_id", student_id)
        .limit(1)
        .execute()
    )
    rows = row.data or []
    if not rows:
        raise TeacherPerformanceError("Not a member of this group", status_code=403)

    membership = rows[0]
    now = _utc_now()
    prev = _parse_ts(membership.get("last_active_at"))
    # Avoid write spam if student re-opens within 5 minutes.
    if prev is not None and (now - prev) < timedelta(minutes=5):
        return {
            "class_id": class_id,
            "last_active_at": prev.isoformat(),
            "throttled": True,
        }

    updated = (
        db.table("class_memberships")
        .update({"last_active_at": now.isoformat()})
        .eq("id", membership["id"])
        .execute()
    )
    out = (updated.data or [None])[0] or {}
    return {
        "class_id": class_id,
        "last_active_at": out.get("last_active_at") or now.isoformat(),
        "throttled": False,
    }


def _pick_top_lecture(
    *,
    attempts: list[dict[str, Any]],
    title_by_lecture: dict[str, str],
    type_by_lecture: dict[str, str],
    start: datetime | None = None,
    end: datetime | None = None,
) -> dict[str, Any] | None:
    """Most attempted shared lecture (proxy for 'top' — no open-count table yet)."""
    windowed = attempts
    if start is not None and end is not None:
        windowed = _filter_window(attempts, start, end)
    if not windowed:
        return None

    by_lecture: dict[str, list[dict[str, Any]]] = {}
    for a in windowed:
        lid = str(a.get("lecture_id") or "")
        if not lid:
            continue
        by_lecture.setdefault(lid, []).append(a)
    if not by_lecture:
        return None

    best_id = ""
    best_count = -1
    best_unique = -1
    for lid, rows in by_lecture.items():
        count = len(rows)
        unique = len({str(r.get("user_id") or "") for r in rows if r.get("user_id")})
        if count > best_count or (count == best_count and unique > best_unique):
            best_id = lid
            best_count = count
            best_unique = unique

    if not best_id or best_count <= 0:
        return None
    title = title_by_lecture.get(best_id) or "Shared lecture"
    return {
        "lecture_id": best_id,
        "title": title,
        "share_type": type_by_lecture.get(best_id) or "lecture",
        "attempt_count": best_count,
        "unique_students": best_unique,
    }


def list_group_students(teacher_id: str, class_id: str) -> dict[str, Any]:
    """One Study Group: members + last_active + quiz % on lectures shared to this group."""
    class_id = (class_id or "").strip()
    if not class_id:
        raise TeacherPerformanceError("class_id required", status_code=400)

    db = get_supabase_admin()
    profile = (
        db.table("users")
        .select("id, role")
        .eq("id", teacher_id)
        .limit(1)
        .execute()
    )
    role = ((profile.data or [{}])[0] or {}).get("role")
    if role and role != "teacher":
        raise TeacherPerformanceError("Teacher role required", status_code=403)

    class_row = (
        db.table("class_folders")
        .select("id, teacher_id, name")
        .eq("id", class_id)
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes:
        raise TeacherPerformanceError("Group not found", status_code=404)
    if str(classes[0].get("teacher_id")) != str(teacher_id):
        raise TeacherPerformanceError(
            "You can only view students in groups you own", status_code=403
        )

    empty = {
        "class_id": class_id,
        "students": [],
        "daily_active_count": 0,
        "weekly_active_count": 0,
        "monthly_active_count": 0,
        "total_students": 0,
        "shared_lecture_count": 0,
        "top_lecture": None,
        "top_lecture_week": None,
        "top_lecture_month": None,
    }

    memberships = (
        db.table("class_memberships")
        .select("student_id, coupon_id, joined_at, last_active_at")
        .eq("class_id", class_id)
        .order("joined_at", desc=True)
        .execute()
    )
    rows = memberships.data or []
    if not rows:
        return empty

    student_ids = [
        str(m["student_id"]) for m in rows if m.get("student_id")
    ]
    users = (
        db.table("users")
        .select("id, username, full_name, email")
        .in_("id", student_ids)
        .execute()
    )
    user_map = {str(u["id"]): u for u in (users.data or []) if u.get("id")}

    shared = (
        db.table("group_shared_items")
        .select("lecture_id, title, type")
        .eq("class_id", class_id)
        .not_.is_("lecture_id", "null")
        .execute()
    )
    title_by_lecture: dict[str, str] = {}
    type_by_lecture: dict[str, str] = {}
    lecture_ids: list[str] = []
    for r in shared.data or []:
        lid = str(r.get("lecture_id") or "")
        if not lid:
            continue
        if lid not in title_by_lecture:
            lecture_ids.append(lid)
            raw_title = r.get("title")
            title_by_lecture[lid] = (
                raw_title.strip()
                if isinstance(raw_title, str) and raw_title.strip()
                else "Shared lecture"
            )
            type_by_lecture[lid] = str(r.get("type") or "lecture")
    lecture_ids = sorted(set(lecture_ids))

    attempts_by_student: dict[str, list[dict[str, Any]]] = {
        sid: [] for sid in student_ids
    }
    all_attempts: list[dict[str, Any]] = []
    if lecture_ids and student_ids:
        attempts_res = (
            db.table("quiz_attempts")
            .select("user_id, score, total, lecture_id, created_at")
            .in_("lecture_id", lecture_ids)
            .in_("user_id", student_ids)
            .execute()
        )
        all_attempts = list(attempts_res.data or [])
        for a in all_attempts:
            sid = str(a.get("user_id") or "")
            if sid in attempts_by_student:
                attempts_by_student[sid].append(a)

    now = _utc_now()
    day_ago = now - timedelta(hours=24)
    week_start = now - timedelta(days=7)
    this_month_start, next_month_start = _month_bounds(now.year, now.month)

    top_all = _pick_top_lecture(
        attempts=all_attempts,
        title_by_lecture=title_by_lecture,
        type_by_lecture=type_by_lecture,
    )
    top_week = _pick_top_lecture(
        attempts=all_attempts,
        title_by_lecture=title_by_lecture,
        type_by_lecture=type_by_lecture,
        start=week_start,
        end=now,
    )
    top_month = _pick_top_lecture(
        attempts=all_attempts,
        title_by_lecture=title_by_lecture,
        type_by_lecture=type_by_lecture,
        start=this_month_start,
        end=next_month_start,
    )

    result: list[dict[str, Any]] = []
    daily_active = 0
    weekly_active = 0
    monthly_active = 0
    for m in rows:
        sid = str(m.get("student_id") or "")
        if not sid:
            continue
        last_active = _parse_ts(m.get("last_active_at"))
        active_today = bool(last_active is not None and last_active >= day_ago)
        active_week = bool(last_active is not None and last_active >= week_start)
        active_month = bool(
            last_active is not None
            and this_month_start <= last_active < next_month_start
        )
        if active_today:
            daily_active += 1
        if active_week:
            weekly_active += 1
        if active_month:
            monthly_active += 1

        attempts = attempts_by_student.get(sid, [])
        week_attempts = _filter_window(attempts, week_start, now)
        month_attempts = _filter_window(
            attempts, this_month_start, next_month_start
        )
        result.append(
            {
                "student_id": sid,
                "username": _display_name(user_map.get(sid)),
                "joined_via_coupon": m.get("coupon_id") is not None,
                "joined_at": (
                    (_parse_ts(m.get("joined_at")) or now).isoformat()
                ),
                "overall_percent": _pct(attempts) if lecture_ids else None,
                "this_week_percent": (
                    _pct(week_attempts) if lecture_ids else None
                ),
                "this_month_percent": (
                    _pct(month_attempts) if lecture_ids else None
                ),
                "attempt_count": len(attempts),
                "this_week_attempt_count": len(week_attempts),
                "this_month_attempt_count": len(month_attempts),
                "last_active_at": last_active.isoformat() if last_active else None,
                "active_today": active_today,
                "active_this_week": active_week,
                "active_this_month": active_month,
            }
        )

    result.sort(
        key=lambda r: (
            -(1 if r["active_today"] else 0),
            -(r["overall_percent"] if r["overall_percent"] is not None else -1),
            r["username"].lower(),
        )
    )
    return {
        "class_id": class_id,
        "students": result,
        "daily_active_count": daily_active,
        "weekly_active_count": weekly_active,
        "monthly_active_count": monthly_active,
        "total_students": len(result),
        "shared_lecture_count": len(lecture_ids),
        "top_lecture": top_all,
        "top_lecture_week": top_week,
        "top_lecture_month": top_month,
    }


def list_teacher_students(teacher_id: str) -> dict[str, Any]:
    """Students across teacher's groups with quiz performance + daily active."""
    db = get_supabase_admin()

    profile = (
        db.table("users")
        .select("id, role")
        .eq("id", teacher_id)
        .limit(1)
        .execute()
    )
    role = ((profile.data or [{}])[0] or {}).get("role")
    if role and role != "teacher":
        raise TeacherPerformanceError("Teacher role required", status_code=403)

    try:
        ensure_previous_month_snapshots(teacher_id)
    except Exception:  # noqa: BLE001
        pass

    classes = (
        db.table("class_folders")
        .select("id, name")
        .eq("teacher_id", teacher_id)
        .execute()
    )
    class_rows = classes.data or []
    class_ids = [str(c["id"]) for c in class_rows if c.get("id")]
    class_names = {str(c["id"]): c.get("name") for c in class_rows if c.get("id")}
    if not class_ids:
        return {
            "students": [],
            "daily_active_count": 0,
            "total_students": 0,
        }

    memberships = (
        db.table("class_memberships")
        .select("student_id, coupon_id, joined_at, class_id, last_active_at")
        .in_("class_id", class_ids)
        .execute()
    )
    rows = memberships.data or []
    if not rows:
        return {
            "students": [],
            "daily_active_count": 0,
            "total_students": 0,
        }

    by_student: dict[str, dict[str, Any]] = {}
    for m in rows:
        sid = str(m.get("student_id") or "")
        if not sid:
            continue
        cid = str(m.get("class_id") or "")
        joined = _parse_ts(m.get("joined_at")) or _utc_now()
        coupon = m.get("coupon_id") is not None
        gname = class_names.get(cid)
        last_active = _parse_ts(m.get("last_active_at"))
        if sid not in by_student:
            by_student[sid] = {
                "student_id": sid,
                "joined_at": joined,
                "joined_via_coupon": coupon,
                "group_names": [gname] if gname else [],
                "last_active_at": last_active,
            }
        else:
            prev = by_student[sid]
            if joined < prev["joined_at"]:
                prev["joined_at"] = joined
            if coupon:
                prev["joined_via_coupon"] = True
            if gname and gname not in prev["group_names"]:
                prev["group_names"].append(gname)
            if last_active is not None and (
                prev["last_active_at"] is None or last_active > prev["last_active_at"]
            ):
                prev["last_active_at"] = last_active

    student_ids = list(by_student.keys())
    users = (
        db.table("users")
        .select("id, username, full_name, email")
        .in_("id", student_ids)
        .execute()
    )
    user_map = {str(u["id"]): u for u in (users.data or []) if u.get("id")}

    lectures = (
        db.table("lectures").select("id").eq("user_id", teacher_id).execute()
    )
    lecture_ids = [str(r["id"]) for r in (lectures.data or []) if r.get("id")]

    all_attempts: list[dict[str, Any]] = []
    if lecture_ids and student_ids:
        attempts_res = (
            db.table("quiz_attempts")
            .select("user_id, score, total, lecture_id, created_at")
            .in_("lecture_id", lecture_ids)
            .in_("user_id", student_ids)
            .execute()
        )
        all_attempts = list(attempts_res.data or [])

    attempts_by_student: dict[str, list[dict[str, Any]]] = {
        sid: [] for sid in student_ids
    }
    for a in all_attempts:
        sid = str(a.get("user_id") or "")
        if sid in attempts_by_student:
            attempts_by_student[sid].append(a)

    now = _utc_now()
    day_ago = now - timedelta(hours=24)
    week_start = now - timedelta(days=7)
    prev_week_start = now - timedelta(days=14)
    this_month_start, next_month_start = _month_bounds(now.year, now.month)
    py, pm = _prev_month(now.year, now.month)
    last_month_start, last_month_end = _month_bounds(py, pm)
    prev_ym = f"{py:04d}-{pm:02d}"

    month_stats: dict[str, dict[str, Any]] = {}
    try:
        stats_res = (
            db.table("teacher_student_month_stats")
            .select("student_id, year_month, avg_percent, attempt_count")
            .eq("teacher_id", teacher_id)
            .eq("year_month", prev_ym)
            .execute()
        )
        for s in stats_res.data or []:
            month_stats[str(s["student_id"])] = s
    except Exception:  # noqa: BLE001
        month_stats = {}

    result: list[dict[str, Any]] = []
    daily_active = 0
    for sid, meta in by_student.items():
        attempts = attempts_by_student.get(sid, [])
        this_week = _filter_window(attempts, week_start, now)
        last_week = _filter_window(attempts, prev_week_start, week_start)
        this_month = _filter_window(attempts, this_month_start, next_month_start)
        last_month_live = _filter_window(attempts, last_month_start, last_month_end)

        saved = month_stats.get(sid)
        last_month_pct = (
            float(saved["avg_percent"])
            if saved and saved.get("avg_percent") is not None
            else _pct(last_month_live)
        )

        last_active = meta.get("last_active_at")
        active_today = bool(last_active is not None and last_active >= day_ago)
        if active_today:
            daily_active += 1

        result.append(
            {
                "student_id": sid,
                "username": _display_name(user_map.get(sid)),
                "joined_via_coupon": bool(meta["joined_via_coupon"]),
                "joined_at": meta["joined_at"].isoformat(),
                "group_names": meta["group_names"],
                "overall_percent": _pct(attempts),
                "this_week_percent": _pct(this_week),
                "last_week_percent": _pct(last_week),
                "this_month_percent": _pct(this_month),
                "last_month_percent": last_month_pct,
                "attempt_count": len(attempts),
                "last_active_at": last_active.isoformat() if last_active else None,
                "active_today": active_today,
            }
        )

    result.sort(
        key=lambda r: (
            -(1 if r["active_today"] else 0),
            -(r["overall_percent"] if r["overall_percent"] is not None else -1),
            r["username"].lower(),
        )
    )
    return {
        "students": result,
        "daily_active_count": daily_active,
        "total_students": len(result),
    }


# Teacher-selected Study / Home chips linked into a group (free re-share).
# Students see only these; no generate. NULL on old rows = legacy all tabs.
ALLOWED_SHARE_CHIPS = frozenset(
    {
        "notes",
        "summary",
        "transcript",
        "flashcards",
        "quiz",
        "revision",
        "important_questions",
        "mind_map",
        "five_min_revision",
        "visual",
        "learn_more",
        "memory_tricks",
        "common_mistakes",
        "cheat_sheet",
        "teacher_tips",
        "exam_booster",
    }
)


def share_lecture_to_group(
    *,
    teacher_id: str,
    class_id: str,
    lecture_id: str,
    share_type: str,
    title: str,
    body: str | None = None,
    is_pinned: bool = False,
    shared_chips: list[str] | None = None,
) -> dict[str, Any]:
    """Server-side share: own group + own recorded lecture only.
    Requires active Teacher ₹2,999 (founder lock B + share gate Jul 25, 2026).
    shared_chips: which generated artifacts students may open (All / specific).
    """
    from app.services.plan_tier_service import (
        TeacherPlanRequiredError,
        require_active_teacher_plan,
    )

    try:
        require_active_teacher_plan(teacher_id)
    except TeacherPlanRequiredError as e:
        raise TeacherPerformanceError(str(e), status_code=403) from e

    allowed = {"lecture", "notes", "quiz", "homework", "announcement"}
    if share_type not in allowed:
        raise TeacherPerformanceError(
            f"Invalid share type: {share_type}", status_code=400
        )

    chips_out: list[str] | None = None
    if shared_chips is not None:
        cleaned: list[str] = []
        seen: set[str] = set()
        for raw in shared_chips:
            key = str(raw or "").strip().lower().replace("-", "_")
            if key == "flashcard":
                key = "flashcards"
            if key in ("ask_ai", "ask"):
                continue  # never share Ask AI chip to groups
            if key not in ALLOWED_SHARE_CHIPS:
                raise TeacherPerformanceError(
                    f"Invalid share chip: {raw}", status_code=400
                )
            if key not in seen:
                seen.add(key)
                cleaned.append(key)
        if not cleaned:
            raise TeacherPerformanceError(
                "Select at least one chip to share", status_code=400
            )
        chips_out = cleaned

    db = get_supabase_admin()
    class_row = (
        db.table("class_folders")
        .select("id, teacher_id")
        .eq("id", class_id)
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes:
        raise TeacherPerformanceError("Group not found", status_code=404)
    if str(classes[0].get("teacher_id")) != str(teacher_id):
        raise TeacherPerformanceError(
            "You can only share to groups you own", status_code=403
        )

    lecture = (
        db.table("lectures")
        .select("id, user_id, source_type, title")
        .eq("id", lecture_id)
        .limit(1)
        .execute()
    )
    lectures = lecture.data or []
    if not lectures:
        raise TeacherPerformanceError("Lecture not found", status_code=404)
    lec = lectures[0]
    if str(lec.get("user_id")) != str(teacher_id):
        raise TeacherPerformanceError(
            "You can only share your own lectures", status_code=403
        )
    if lec.get("source_type") != "recorded":
        raise TeacherPerformanceError(
            "Only live-recorded lectures can be shared to a group",
            status_code=403,
        )

    # Teacher Library: same lecture → same group only once (no credit; link only).
    existing = (
        db.table("group_shared_items")
        .select("id")
        .eq("class_id", class_id)
        .eq("lecture_id", lecture_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        raise TeacherPerformanceError(
            "Already shared here",
            status_code=409,
        )

    row: dict[str, Any] = {
        "class_id": class_id,
        "teacher_id": teacher_id,
        "type": share_type,
        "title": title or lec.get("title") or "Shared lecture",
        "lecture_id": lecture_id,
        "body": body,
        "is_pinned": is_pinned,
    }
    if chips_out is not None:
        row["shared_chips"] = chips_out

    try:
        insert = (
            db.table("group_shared_items")
            .insert(row)
            .execute()
        )
    except Exception as e:  # noqa: BLE001 — unique index race
        err = str(e).lower()
        if "uq_group_shared_items_class_lecture" in err or "duplicate" in err:
            raise TeacherPerformanceError(
                "Already shared here",
                status_code=409,
            ) from e
        raise TeacherPerformanceError(f"Share failed: {e}", status_code=500) from e

    rows = insert.data or []
    if not rows:
        # Some PostgREST configs omit returning — fetch latest.
        latest = (
            db.table("group_shared_items")
            .select("*")
            .eq("class_id", class_id)
            .eq("lecture_id", lecture_id)
            .order("shared_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = latest.data or []
    if not rows:
        raise TeacherPerformanceError("Share insert failed", status_code=500)
    return rows[0]


def post_announcement_to_group(
    *,
    teacher_id: str,
    class_id: str,
    title: str,
    body: str,
    is_pinned: bool = False,
) -> dict[str, Any]:
    """Teacher-only text announcement (no lecture). Students cannot reply.
    Requires active Teacher ₹2,999.
    """
    from app.services.plan_tier_service import (
        TeacherPlanRequiredError,
        require_active_teacher_plan,
    )

    try:
        require_active_teacher_plan(teacher_id)
    except TeacherPlanRequiredError as e:
        raise TeacherPerformanceError(str(e), status_code=403) from e

    title_clean = (title or "").strip()
    body_clean = (body or "").strip()
    if not title_clean:
        raise TeacherPerformanceError("Title required", status_code=400)
    if not body_clean:
        raise TeacherPerformanceError("Announcement text required", status_code=400)
    if len(body_clean) > 2000:
        raise TeacherPerformanceError(
            "Announcement too long (max 2000 characters)", status_code=400
        )

    db = get_supabase_admin()
    class_row = (
        db.table("class_folders")
        .select("id, teacher_id")
        .eq("id", class_id)
        .limit(1)
        .execute()
    )
    classes = class_row.data or []
    if not classes:
        raise TeacherPerformanceError("Group not found", status_code=404)
    if str(classes[0].get("teacher_id")) != str(teacher_id):
        raise TeacherPerformanceError(
            "You can only post to groups you own", status_code=403
        )

    insert = (
        db.table("group_shared_items")
        .insert(
            {
                "class_id": class_id,
                "teacher_id": teacher_id,
                "type": "announcement",
                "title": title_clean[:120],
                "lecture_id": None,
                "body": body_clean,
                "is_pinned": is_pinned,
            }
        )
        .execute()
    )
    rows = insert.data or []
    if not rows:
        latest = (
            db.table("group_shared_items")
            .select("*")
            .eq("class_id", class_id)
            .eq("type", "announcement")
            .eq("teacher_id", teacher_id)
            .order("shared_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = latest.data or []
    if not rows:
        raise TeacherPerformanceError("Announcement insert failed", status_code=500)

    item = rows[0]
    if is_pinned and item.get("id"):
        db.table("class_folders").update({"pinned_item_id": item["id"]}).eq(
            "id", class_id
        ).execute()
    return item
