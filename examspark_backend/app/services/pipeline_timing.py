"""Admin/debug stage timings for lecture processing — never shown to students."""
from __future__ import annotations

import logging
import time
from contextlib import contextmanager
from typing import Any, Iterator

logger = logging.getLogger("examspark.pipeline_timing")


class PipelineTimer:
    """Collect wall-clock seconds per stage; log a one-line summary at the end."""

    def __init__(self, label: str, *, lecture_id: str | None = None):
        self.label = label
        self.lecture_id = lecture_id or "-"
        self._t0 = time.perf_counter()
        self._stages: dict[str, float] = {}
        self._meta: dict[str, Any] = {}

    def set_meta(self, key: str, value: Any) -> None:
        self._meta[key] = value

    @contextmanager
    def stage(self, name: str) -> Iterator[None]:
        start = time.perf_counter()
        try:
            yield
        finally:
            self._stages[name] = round(time.perf_counter() - start, 3)

    def mark(self, name: str, seconds: float) -> None:
        self._stages[name] = round(float(seconds), 3)

    def _parts(self) -> str:
        stage_parts = " | ".join(f"{k}={v:.1f}s" for k, v in self._stages.items())
        meta_parts = " | ".join(f"{k}={v}" for k, v in self._meta.items())
        bits = [p for p in (stage_parts, meta_parts) if p]
        return " | ".join(bits) if bits else "(no stages)"

    def log_summary(self) -> None:
        total = round(time.perf_counter() - self._t0, 3)
        logger.info(
            "pipeline_timing lecture_id=%s label=%s %s | total=%.1fs",
            self.lecture_id,
            self.label,
            self._parts(),
            total,
        )

    def log_failure(self, exc: BaseException) -> None:
        total = round(time.perf_counter() - self._t0, 3)
        status = getattr(exc, "status_code", None)
        logger.warning(
            "pipeline_timing_fail lecture_id=%s label=%s %s | total=%.1fs "
            "exc_type=%s groq_or_http_status=%s err=%s",
            self.lecture_id,
            self.label,
            self._parts(),
            total,
            type(exc).__name__,
            status if status is not None else "-",
            str(exc)[:300],
        )
