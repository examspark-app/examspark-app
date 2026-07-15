"""Phase 1 performance — router, cache, RAG tuning constants."""
from __future__ import annotations

from app.constants.rag_perf import (
    CHUNK_MAX_CHARS,
    MATCH_COUNT_DEFAULT,
    MATCH_COUNT_EXPAND,
)
from app.services.ai_performance_cache import (
    answer_cache_key,
    clear_performance_caches_for_tests,
    get_cached_answer,
    get_cached_embedding,
    set_cached_answer,
    set_cached_embedding,
)
from app.services.question_router import (
    route_ask_question,
    route_home_question,
    should_run_rag,
)


def setup_function():
    clear_performance_caches_for_tests()


def test_match_counts():
    assert MATCH_COUNT_DEFAULT == 3
    assert MATCH_COUNT_EXPAND == 5
    assert CHUNK_MAX_CHARS == 1200


def test_home_direct_without_lecture():
    assert route_home_question("Explain photosynthesis", None) == "direct"
    assert not should_run_rag(route_home_question("Explain photosynthesis", None))


def test_home_product_skips_rag_with_lecture():
    route = route_home_question("what is credit economy", "lec-1")
    assert route == "direct"
    assert not should_run_rag(route)


def test_home_subject_uses_rag_with_lecture():
    route = route_home_question("What is Kirchhoff law in this lecture?", "lec-1")
    assert route == "rag"
    assert should_run_rag(route)


def test_ask_always_rag():
    assert route_ask_question("what are credits?") == "rag"


def test_web_deferred_home():
    assert route_home_question("today's news about NEET", None) == "web_deferred"
    assert not should_run_rag("web_deferred")


def test_embedding_cache_roundtrip():
    set_cached_embedding("Hello World", [0.1, 0.2])
    assert get_cached_embedding("hello world") == [0.1, 0.2]


def test_answer_cache_no_credit_fields_stored():
    key = answer_cache_key(
        user_id="u1",
        mode="normal",
        query="What is HOF?",
        lecture_id=None,
        conversation_language="ENGLISH",
        feature="home_ai",
    )
    set_cached_answer(
        key,
        {
            "answer": "Hofmann",
            "status": "SUCCESS",
            "credits_charged": 5,
            "new_balance": 70,
            "mode": "normal",
        },
    )
    hit = get_cached_answer(key)
    assert hit is not None
    assert hit["answer"] == "Hofmann"
    assert "credits_charged" not in hit
    assert "new_balance" not in hit
