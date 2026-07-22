import json

from app.services.qwen_service import _extract_json_object


def test_extract_json_object_happy():
    d = _extract_json_object('{"cleanNotes": "Hello world notes that are long enough here.", "keyPoints": []}')
    assert "Hello" in d["cleanNotes"]


def test_extract_json_object_salvages_truncated_clean_notes():
    raw = (
        '{\n  "cleanNotes": "Cell biology covers membranes and organelles in detail for exams'
    )
    d = _extract_json_object(raw)
    assert "Cell biology" in d["cleanNotes"]
    assert len(d["cleanNotes"]) >= 40


def test_extract_json_object_raises_when_empty():
    try:
        _extract_json_object("not json at all")
        assert False, "expected JSONDecodeError"
    except json.JSONDecodeError:
        pass
