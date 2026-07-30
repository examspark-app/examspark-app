"""Unit tests for RAG chunking — no network / OpenRouter."""
from app.services.chunk_service import chunk_hash, chunk_text


def test_chunk_hash_stable():
    assert chunk_hash("hello") == chunk_hash("hello")
    assert chunk_hash("hello") != chunk_hash("hello!")


def test_chunk_text_empty():
    assert chunk_text("") == []
    assert chunk_text("   ") == []


def test_chunk_text_short_stays_one():
    text = "Short lecture notes about Newton."
    chunks = chunk_text(text, target_chars=700)
    assert chunks == [text]


def test_chunk_text_long_splits():
    words = ["word"] * 200
    text = " ".join(words)
    chunks = chunk_text(text, target_chars=100, overlap_chars=20)
    assert len(chunks) >= 2
    assert all(len(c) <= 120 for c in chunks)
