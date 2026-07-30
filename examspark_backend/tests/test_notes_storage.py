"""Tests for short notes storage in Supabase with legacy R2 fallback."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.services.lecture_service import LectureService
from app.services.rag_index_service import _load_notes_text


def test_persist_writes_short_notes_to_supabase_columns():
    service = LectureService()
    notes = {
        "cleanNotes": "Cell division is the process by which cells reproduce.",
        "shortSummary": "Short summary",
        "keyPoints": ["Mitosis", "Meiosis"],
        "importantTerms": [{"term": "Mitosis", "definition": "Cell division"}],
    }

    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.upsert.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.limit.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(service._r2, "lecture_folder_path", return_value="Users/u/Library/l"),
        patch.object(service._r2, "upload_text", return_value="tr-path") as upload_text,
    ):
        service._persist_notes_supabase_sync("u", "l", notes)
        result = service._persist_r2_transcript_sync(
            "u", "l", "Transcript text"
        )

    assert result["transcript"] == "tr-path"
    assert result["clean_transcript"] == "tr-path"
    upload_text.assert_called_once()
    mock_table.upsert.assert_any_call(
        {
            "lecture_id": "l",
            "clean_notes": notes["cleanNotes"],
            "short_summary": notes["shortSummary"],
            "key_points": notes["keyPoints"],
            "important_terms": notes["importantTerms"],
            "visual_payload_json": None,
        },
        on_conflict="lecture_id",
    )


def test_persist_notes_first_does_not_require_r2():
    service = LectureService()
    notes = {
        "cleanNotes": "Notes only",
        "shortSummary": "S",
        "keyPoints": [],
        "importantTerms": [],
    }
    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.upsert.return_value = mock_table
    mock_table.execute.return_value = MagicMock(data=[])

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(service._r2, "lecture_folder_path", return_value="Users/u/Library/l"),
        patch.object(service._r2, "upload_text") as upload_text,
    ):
        service._persist_notes_supabase_sync("u", "l", notes)

    upload_text.assert_not_called()
    mock_table.upsert.assert_any_call(
        {
            "lecture_id": "l",
            "clean_notes": "Notes only",
            "short_summary": "S",
            "key_points": [],
            "important_terms": [],
            "visual_payload_json": None,
        },
        on_conflict="lecture_id",
    )


def test_get_lecture_notes_prefers_supabase_columns_without_r2():
    service = LectureService()

    mock_db = MagicMock()
    lecture_table = MagicMock()
    notes_table = MagicMock()

    def table_side_effect(name: str):
        if name == "lectures":
            return lecture_table
        if name == "notes":
            return notes_table
        raise AssertionError(name)

    mock_db.table.side_effect = table_side_effect

    lecture_table.select.return_value = lecture_table
    lecture_table.eq.return_value = lecture_table
    lecture_table.limit.return_value = lecture_table
    lecture_table.execute.return_value = MagicMock(
        data=[{"id": "lec-1", "user_id": "user-1", "status": "done"}]
    )

    notes_table.select.return_value = notes_table
    notes_table.eq.return_value = notes_table
    notes_table.limit.return_value = notes_table
    notes_table.execute.return_value = MagicMock(
        data=[
            {
                "clean_notes": "Direct DB clean notes",
                "short_summary": "DB summary",
                "key_points": ["A", "B"],
                "important_terms": [{"term": "A", "definition": "B"}],
                "r2_notes_path": "legacy/path.json",
            }
        ]
    )

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(service._r2, "download_json") as download_json,
    ):
        result = service.get_lecture_notes("user-1", "lec-1")

    assert result.cleanNotes == "Direct DB clean notes"
    assert result.shortSummary == "DB summary"
    assert result.keyPoints == ["A", "B"]
    download_json.assert_not_called()


def test_get_lecture_notes_falls_back_to_legacy_r2():
    service = LectureService()

    mock_db = MagicMock()
    lecture_table = MagicMock()
    notes_table = MagicMock()

    def table_side_effect(name: str):
        if name == "lectures":
            return lecture_table
        if name == "notes":
            return notes_table
        raise AssertionError(name)

    mock_db.table.side_effect = table_side_effect

    lecture_table.select.return_value = lecture_table
    lecture_table.eq.return_value = lecture_table
    lecture_table.limit.return_value = lecture_table
    lecture_table.execute.return_value = MagicMock(
        data=[{"id": "lec-1", "user_id": "user-1", "status": "done"}]
    )

    notes_table.select.return_value = notes_table
    notes_table.eq.return_value = notes_table
    notes_table.limit.return_value = notes_table
    notes_table.execute.return_value = MagicMock(
        data=[
            {
                "clean_notes": "",
                "short_summary": "",
                "key_points": [],
                "important_terms": [],
                "r2_notes_path": "legacy/path.json",
            }
        ]
    )

    with (
        patch("app.services.lecture_service.get_supabase_admin", return_value=mock_db),
        patch.object(
            service._r2,
            "download_json",
            return_value={
                "cleanNotes": "Legacy clean notes",
                "shortSummary": "Legacy summary",
                "keyPoints": ["KP"],
                "importantTerms": [{"term": "T", "definition": "D"}],
            },
        ) as download_json,
    ):
        result = service.get_lecture_notes("user-1", "lec-1")

    assert result.cleanNotes == "Legacy clean notes"
    assert result.shortSummary == "Legacy summary"
    download_json.assert_called_once()


def test_rag_load_notes_text_prefers_supabase_columns():
    mock_db = MagicMock()
    notes_table = MagicMock()
    mock_db.table.return_value = notes_table
    notes_table.select.return_value = notes_table
    notes_table.eq.return_value = notes_table
    notes_table.limit.return_value = notes_table
    notes_table.execute.return_value = MagicMock(
        data=[
            {
                "clean_notes": "Photosynthesis stores solar energy.",
                "short_summary": "Plants make food.",
                "key_points": ["Chlorophyll", "Sunlight", "Glucose"],
                "important_terms": [],
                "r2_notes_path": "legacy/path.json",
            }
        ]
    )

    with patch("app.services.rag_index_service.get_supabase_admin", return_value=mock_db):
        text = _load_notes_text("user-1", "lec-1", MagicMock())

    assert "Photosynthesis stores solar energy." in text
    assert "Plants make food." in text
    assert "Chlorophyll" in text

