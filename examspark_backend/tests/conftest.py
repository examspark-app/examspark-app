from __future__ import annotations

import pytest

from app.services.ai_performance_cache import clear_performance_caches_for_tests


@pytest.fixture(autouse=True)
def _clear_ai_caches_between_tests() -> None:
    """Tests should not depend on cache contents from earlier tests."""
    clear_performance_caches_for_tests()

