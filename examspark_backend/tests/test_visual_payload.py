"""Tests — Smart Visual Notes Engine (Phase 5)."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.models.visual_payload import (
    GraphDataItem,
    TextDiagram,
    VisualPayload,
    parse_visual_payload,
    visual_payload_to_plain_text,
)
from app.services.lecture_service import (
    LectureService,
    _processed_notes_from_row,
    _visual_from_notes_dict,
)
from app.services.visual_stream_parser import VisualStreamParser, split_answer_and_visual


def test_parse_visual_payload_camel_case():
    raw = {
        "graphs": [{"function": "y=x^2", "x_range": [-5, 5]}],
        "cheatSheet": "## Quick recap",
        "memoryTricks": ["PEMDAS"],
    }
    payload = parse_visual_payload(raw)
    assert payload is not None
    assert payload.cheat_sheet == "## Quick recap"
    assert payload.memory_tricks == ["PEMDAS"]


def test_visual_payload_to_plain_text():
    payload = VisualPayload(
        graphs=[GraphDataItem(function="y=x", x_range=[-1, 1], label="Linear")],
        text_diagrams=[TextDiagram(title="Cycle", content="A → B → C")],
    )
    text = visual_payload_to_plain_text(payload)
    assert "Graph: Linear" in text
    assert "Cycle" in text


def test_visual_stream_parser_strips_delimiter():
    parser = VisualStreamParser()
    before = "Hello student."
    after = '{"memory_tricks":["Use FOIL"]}'
    out = parser.feed(before)
    parser.feed("\n\n<<VISUAL_JSON>>\n")
    parser.feed(after)
    parser.finish()
    assert parser.answer.strip() == before
    assert "<<VISUAL_JSON>>" not in parser.answer
    assert out == before


def test_split_answer_and_visual():
    text = 'Answer text.\n<<VISUAL_JSON>>\n{"memory_tricks":["Use FOIL"]}'
    answer, visual = split_answer_and_visual(text)
    assert answer == "Answer text."
    assert visual is not None
    assert visual["memory_tricks"] == ["Use FOIL"]


def test_visual_from_notes_dict():
    raw = _visual_from_notes_dict(
        {"visualPayload": {"exam_tips": ["Revise formulas"]}}
    )
    assert raw == {"exam_tips": ["Revise formulas"]}


def test_processed_notes_from_row_with_visual():
    row = {
        "clean_notes": "Body",
        "short_summary": "Sum",
        "key_points": [],
        "important_terms": [],
        "visual_payload_json": {"examples": ["Ex1"]},
    }
    notes = _processed_notes_from_row(row)
    assert notes is not None
    assert notes.visualPayload is not None
    assert notes.visualPayload.examples == ["Ex1"]


def test_get_lecture_notes_returns_visual_payload():
    service = LectureService()
    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table
    mock_table.select.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.limit.return_value = mock_table
    mock_table.execute.side_effect = [
        MagicMock(data=[{"id": "lec-1", "user_id": "u1", "status": "done"}]),
        MagicMock(
            data=[
                {
                    "clean_notes": "Notes",
                    "short_summary": "S",
                    "key_points": [],
                    "important_terms": [],
                    "visual_payload_json": {"graphs": []},
                    "r2_notes_path": None,
                }
            ]
        ),
    ]

    with patch(
        "app.services.lecture_service.get_supabase_admin", return_value=mock_db
    ):
        result = service.get_lecture_notes("u1", "lec-1")

    assert result.cleanNotes == "Notes"
    assert result.visualPayload is None  # empty graphs → parse returns None
