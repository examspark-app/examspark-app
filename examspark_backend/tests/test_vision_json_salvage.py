from app.services.qwen_vision_service import _parse_vision_json


def test_parse_truncated_clean_notes_json():
    raw = (
        '{\n  "cleanNotes": "Photosynthesis is the process by which plants '
        "make food using sunlight and chlorophyll in leaves"
    )
    d = _parse_vision_json(raw, "test-model")
    assert "Photosynthesis" in d["cleanNotes"]
    assert len(d["cleanNotes"]) >= 40
