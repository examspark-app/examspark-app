"""Per-request timing spans for Home AI / Ask AI (log only — hot path)."""
from __future__ import annotations

import logging
import time
from typing import Any

logger = logging.getLogger("examspark.perf")


class PerformanceTimer:
    def __init__(self, feature: str):
        self.feature = feature
        self._t0 = time.perf_counter()
        self._starts: dict[str, float] = {}
        self.spans_ms: dict[str, float] = {}
        self.extra: dict[str, Any] = {}

    def start(self, label: str) -> None:
        self._starts[label] = time.perf_counter()

    def end(self, label: str) -> None:
        t = self._starts.pop(label, None)
        if t is None:
            return
        self.spans_ms[label] = round((time.perf_counter() - t) * 1000, 1)

    def set(self, **kwargs: Any) -> None:
        self.extra.update(kwargs)

    def log(self) -> None:
        total_ms = round((time.perf_counter() - self._t0) * 1000, 1)
        parts = [f"feature={self.feature}", f"total_ms={total_ms}"]
        for k, v in self.spans_ms.items():
            parts.append(f"{k}_ms={v}")
        for k, v in self.extra.items():
            parts.append(f"{k}={v}")
        logger.info("perf " + " ".join(parts))
