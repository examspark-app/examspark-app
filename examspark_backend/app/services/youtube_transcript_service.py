"""YouTube captions → text (no video/audio download).

Used by YouTube Link → Notes. Public videos with captions only.
Duration from last caption end; >60 min rejected by lecture pipeline.
"""
from __future__ import annotations

import math
import re
from dataclasses import dataclass


class YoutubeTranscriptError(Exception):
    """User-facing caption/fetch failure (no credits charged yet)."""

    def __init__(self, message: str):
        super().__init__(message)


@dataclass(frozen=True)
class YoutubeCaptions:
    video_id: str
    text: str
    duration_minutes: int


_WATCH_RE = re.compile(
    r"(?:youtube\.com/watch\?[^#]*v=|youtu\.be/|youtube\.com/shorts/)([A-Za-z0-9_-]{6,})",
    re.IGNORECASE,
)


def extract_video_id(url: str) -> str:
    raw = (url or "").strip()
    if not raw:
        raise YoutubeTranscriptError("Please paste a YouTube link.")
    match = _WATCH_RE.search(raw)
    if not match:
        raise YoutubeTranscriptError(
            "That doesn't look like a YouTube watch / youtu.be / Shorts link."
        )
    return match.group(1)


def fetch_youtube_captions(url: str) -> YoutubeCaptions:
    """Fetch captions for a public video. Raises YoutubeTranscriptError on reject."""
    video_id = extract_video_id(url)

    try:
        from youtube_transcript_api import YouTubeTranscriptApi
        from youtube_transcript_api._errors import (
            NoTranscriptFound,
            TranscriptsDisabled,
            VideoUnavailable,
        )
    except ImportError as e:
        raise YoutubeTranscriptError(
            "YouTube support requires youtube-transcript-api — install backend requirements."
        ) from e

    try:
        # youtube-transcript-api ≥1.0 instance API; fall back to 0.6 classmethod.
        try:
            api = YouTubeTranscriptApi()
            fetched = api.fetch(video_id)
            snippets = list(fetched)
        except AttributeError:
            snippets = YouTubeTranscriptApi.get_transcript(video_id)  # type: ignore[attr-defined]
            snippets = [
                type("S", (), {"text": s["text"], "start": s["start"], "duration": s.get("duration", 0.0)})()
                for s in snippets
            ]
    except TranscriptsDisabled as e:
        raise YoutubeTranscriptError(
            "This video has captions disabled. Try a public video with subtitles/CC on."
        ) from e
    except NoTranscriptFound as e:
        raise YoutubeTranscriptError(
            "No captions found for this video. Public videos with subtitles/CC are required."
        ) from e
    except VideoUnavailable as e:
        raise YoutubeTranscriptError(
            "This video is unavailable (private, unlisted, age-restricted, region-locked, "
            "or removed). Public videos only."
        ) from e
    except Exception as e:  # noqa: BLE001
        msg = str(e).lower()
        if "unavailable" in msg or "private" in msg or "forbidden" in msg:
            raise YoutubeTranscriptError(
                "This video is unavailable (private, unlisted, age-restricted, "
                "region-locked, or removed). Public videos only."
            ) from e
        raise YoutubeTranscriptError(f"Could not fetch captions: {e}") from e

    if not snippets:
        raise YoutubeTranscriptError(
            "No captions found for this video. Public videos with subtitles/CC are required."
        )

    parts: list[str] = []
    end_seconds = 0.0
    for snip in snippets:
        text = (getattr(snip, "text", None) or "").strip()
        if text:
            parts.append(text)
        start = float(getattr(snip, "start", 0.0) or 0.0)
        dur = float(getattr(snip, "duration", 0.0) or 0.0)
        end_seconds = max(end_seconds, start + dur)

    joined = " ".join(parts).strip()
    if len(joined) < 40:
        raise YoutubeTranscriptError(
            "Captions were too short to make study notes. Try another public video."
        )

    duration_minutes = max(1, int(math.ceil(end_seconds / 60.0)))
    return YoutubeCaptions(
        video_id=video_id,
        text=joined,
        duration_minutes=duration_minutes,
    )
