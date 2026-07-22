"""Phase 4D session helpers — title + soft idempotency (no DB)."""
from app.services.home_ai_session_service import _title_from_query


def test_title_from_query_short():
    assert _title_from_query("What is photosynthesis?") == "What is photosynthesis?"


def test_title_from_query_long():
    long_q = "A" * 100
    t = _title_from_query(long_q, max_len=72)
    assert len(t) <= 72
    assert t.endswith("…")


def test_title_from_query_empty():
    assert _title_from_query("   ") == "Study session"
