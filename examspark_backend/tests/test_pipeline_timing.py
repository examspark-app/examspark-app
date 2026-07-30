"""PipelineTimer — admin-only stage timings."""
from __future__ import annotations

from app.services.pipeline_timing import PipelineTimer


def test_pipeline_timer_records_stages():
    timer = PipelineTimer("audio", lecture_id="lec-1")
    with timer.stage("whisper"):
        pass
    timer.mark("openrouter_notes", 12.5)
    assert "whisper" in timer._stages
    assert timer._stages["openrouter_notes"] == 12.5
    timer.log_summary()  # must not raise
