"""Owner-checked permanent lecture delete (R2 first, then DB cascade)."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from app.services.lecture_service import LecturePipelineError, LectureService
from app.services.r2_storage_service import R2StorageError


def _owned_row(user_id: str = "user-1", lecture_id: str = "lec-1") -> dict:
    return {
        "id": lecture_id,
        "user_id": user_id,
        "r2_folder_path": f"Users/{user_id}/Library/{lecture_id}",
    }


def test_delete_lecture_denies_non_owner():
    service = LectureService()
    select_chain = MagicMock()
    select_chain.select.return_value.eq.return_value.limit.return_value.execute.return_value = (
        MagicMock(data=[_owned_row(user_id="owner-other")])
    )
    db = MagicMock()
    db.table.return_value = select_chain

    with patch("app.services.lecture_service.get_supabase_admin", return_value=db):
        with pytest.raises(LecturePipelineError) as exc:
            service.delete_lecture_for_user("user-1", "lec-1")

    assert exc.value.status_code == 403
    db.table.return_value.delete.assert_not_called()


def test_delete_lecture_r2_failure_keeps_db_row():
    service = LectureService()
    select_chain = MagicMock()
    select_chain.select.return_value.eq.return_value.limit.return_value.execute.return_value = (
        MagicMock(data=[_owned_row()])
    )
    db = MagicMock()
    db.table.return_value = select_chain

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=db),
        patch.object(
            service._r2,
            "delete_prefix",
            side_effect=R2StorageError("boom"),
        ),
    ):
        with pytest.raises(LecturePipelineError) as exc:
            service.delete_lecture_for_user("user-1", "lec-1")

    assert exc.value.status_code == 502
    # Must not delete DB rows when R2 cleanup fails.
    db.table.return_value.delete.assert_not_called()


def test_delete_lecture_success_cleans_duplicates_then_row():
    service = LectureService()
    owned = _owned_row()

    lectures_table = MagicMock()
    # First call: select ownership. Later: delete duplicate children + delete row.
    select_exec = MagicMock(data=[owned])
    lectures_table.select.return_value.eq.return_value.limit.return_value.execute.return_value = (
        select_exec
    )
    delete_calls: list[dict] = []

    def _delete_side_effect():
        chain = MagicMock()

        def _eq(col, val):
            delete_calls.append({col: val})
            return chain

        chain.eq.side_effect = _eq
        chain.execute.return_value = MagicMock(data=[])
        return chain

    lectures_table.delete.side_effect = lambda: _delete_side_effect()

    db = MagicMock()
    db.table.return_value = lectures_table

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=db),
        patch.object(service._r2, "delete_prefix", return_value=3) as r2_del,
    ):
        out = service.delete_lecture_for_user("user-1", "lec-1")

    assert out["deleted"] is True
    assert out["lecture_id"] == "lec-1"
    assert out["r2_objects_deleted"] == 3
    r2_del.assert_called_once_with("Users/user-1/Library/lec-1")

    # duplicate_of_lecture_id cleanup then id+user_id delete
    assert any("duplicate_of_lecture_id" in c for c in delete_calls)
    assert any(c.get("id") == "lec-1" for c in delete_calls)
    assert any(c.get("user_id") == "user-1" for c in delete_calls)


def test_delete_lecture_not_found():
    service = LectureService()
    select_chain = MagicMock()
    select_chain.select.return_value.eq.return_value.limit.return_value.execute.return_value = (
        MagicMock(data=[])
    )
    db = MagicMock()
    db.table.return_value = select_chain

    with patch("app.services.lecture_service.get_supabase_admin", return_value=db):
        with pytest.raises(LecturePipelineError) as exc:
            service.delete_lecture_for_user("user-1", "missing")

    assert exc.value.status_code == 404
