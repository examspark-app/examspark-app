"""YouTube captions → text (no video/audio download).

Used by YouTube Link → Notes. Prefer captions in any available language
(Hindi / Bengali / English / other), then Whisper audio fallback elsewhere.
"""
from __future__ import annotations

import logging
import math
import re
from dataclasses import dataclass

logger = logging.getLogger(__name__)


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

# Prefer Indian + major world languages; any other YouTube CC track still works
# via list/any-track fallback (Qwen3 notes stay in that language).
_PREFERRED_LANGS = (
    # India
    "hi",
    "hi-IN",
    "bn",
    "bn-IN",
    "bn-BD",
    "te",
    "te-IN",
    "mr",
    "mr-IN",
    "ta",
    "ta-IN",
    "ur",
    "ur-IN",
    "ur-PK",
    "gu",
    "gu-IN",
    "kn",
    "kn-IN",
    "or",
    "or-IN",
    "ml",
    "ml-IN",
    "pa",
    "pa-IN",
    "as",
    "as-IN",
    "mai",
    "sa",
    "ne",
    "ne-NP",
    "sd",
    "sd-IN",
    "ks",
    "doi",
    "mni",
    "sat",
    "kok",
    "brx",
    "bh",
    "bho",
    "mag",
    "new",
    "gom",
    "tcy",
    "si",
    # World (common YouTube CC)
    "en",
    "en-IN",
    "en-GB",
    "en-US",
    "es",
    "es-ES",
    "es-419",
    "fr",
    "fr-FR",
    "pt",
    "pt-BR",
    "pt-PT",
    "de",
    "it",
    "nl",
    "pl",
    "ru",
    "uk",
    "ar",
    "tr",
    "id",
    "ms",
    "th",
    "vi",
    "zh",
    "zh-CN",
    "zh-Hans",
    "zh-Hant",
    "zh-TW",
    "ja",
    "ko",
    "sv",
    "da",
    "fi",
    "no",
    "ro",
    "cs",
    "el",
    "he",
    "fa",
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


def fetch_youtube_title(url: str) -> str | None:
    """Best-effort video title via yt-dlp metadata (no download)."""
    try:
        import yt_dlp  # type: ignore
    except ImportError:
        return None
    try:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info((url or "").strip(), download=False)
        raw = (info or {}).get("title")
        if isinstance(raw, str):
            t = raw.strip()
            if t:
                return t[:120]
    except Exception as e:  # noqa: BLE001
        logger.info("fetch_youtube_title failed: %s", e)
    return None


def _snippets_from_fetched(fetched) -> list:
    return list(fetched)


def _legacy_dicts_to_snippets(rows: list) -> list:
    return [
        type(
            "S",
            (),
            {
                "text": s["text"],
                "start": s["start"],
                "duration": s.get("duration", 0.0),
            },
        )()
        for s in rows
    ]


def _fetch_any_language_snippets(api, video_id: str) -> list:
    """Prefer Indian + English langs, then any available track (manual or auto)."""
    from youtube_transcript_api._errors import NoTranscriptFound

    # 1) Priority languages (incl. Bengali / Hindi — not English-only).
    try:
        fetched = api.fetch(video_id, languages=_PREFERRED_LANGS)
        logger.info("YouTube captions via preferred langs video_id=%s", video_id)
        return _snippets_from_fetched(fetched)
    except Exception as e:  # noqa: BLE001
        logger.info(
            "Preferred-lang captions miss video_id=%s (%s); trying any track",
            video_id,
            e,
        )

    # 2) Any listed transcript (fixes bn-only / hi-only / auto-CC).
    try:
        transcript_list = api.list(video_id)
    except Exception:
        raise

    # Collect every language code YouTube exposes, then retry fetch.
    listed_codes: list[str] = []
    try:
        for t in transcript_list:
            code = getattr(t, "language_code", None)
            if isinstance(code, str) and code.strip():
                c = code.strip()
                if c not in listed_codes:
                    listed_codes.append(c)
    except TypeError:
        listed_codes = []

    if listed_codes:
        try:
            merged = tuple(dict.fromkeys([*listed_codes, *_PREFERRED_LANGS]))
            fetched = api.fetch(video_id, languages=merged)
            logger.info(
                "YouTube captions via listed langs=%s video_id=%s",
                listed_codes[:8],
                video_id,
            )
            return _snippets_from_fetched(fetched)
        except Exception as e:  # noqa: BLE001
            logger.info(
                "Listed-lang fetch miss video_id=%s (%s); trying track loop",
                video_id,
                e,
            )

    # Prefer finding from our language list explicitly (manual or generated).
    for finder_name in (
        "find_manually_created_transcript",
        "find_generated_transcript",
        "find_transcript",
    ):
        finder = getattr(transcript_list, finder_name, None)
        if finder is None:
            continue
        try:
            t = finder(_PREFERRED_LANGS if not listed_codes else listed_codes)
            fetched = t.fetch()
            lang = getattr(t, "language_code", "?")
            logger.info(
                "YouTube captions via %s lang=%s video_id=%s",
                finder_name,
                lang,
                video_id,
            )
            return _snippets_from_fetched(fetched)
        except Exception:
            continue

    # 3) Last resort — first track that fetches (any language code).
    try:
        for t in transcript_list:
            try:
                fetched = t.fetch()
                lang = getattr(t, "language_code", "?")
                logger.info(
                    "YouTube captions any-track lang=%s video_id=%s",
                    lang,
                    video_id,
                )
                return _snippets_from_fetched(fetched)
            except Exception:
                continue
    except TypeError:
        # Older list objects may not be iterable the same way.
        pass

    raise NoTranscriptFound(video_id)


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
            snippets = _fetch_any_language_snippets(api, video_id)
        except AttributeError:
            snippets = YouTubeTranscriptApi.get_transcript(  # type: ignore[attr-defined]
                video_id, languages=list(_PREFERRED_LANGS)
            )
            snippets = _legacy_dicts_to_snippets(snippets)
    except TranscriptsDisabled as e:
        raise YoutubeTranscriptError(
            "This video has captions disabled. Turn on subtitles/CC "
            "(Hindi, Bengali, English, or any language) and try again."
        ) from e
    except NoTranscriptFound as e:
        raise YoutubeTranscriptError(
            "No captions found for this video. Turn on subtitles/CC "
            "(Hindi, Bengali, English, or auto-captions) and try again."
        ) from e
    except VideoUnavailable as e:
        raise YoutubeTranscriptError(
            "This video is unavailable (private, unlisted, age-restricted, region-locked, "
            "or removed)."
        ) from e
    except Exception as e:  # noqa: BLE001
        msg = str(e).lower()
        if "unavailable" in msg or "private" in msg or "forbidden" in msg:
            raise YoutubeTranscriptError(
                "This video is unavailable (private, unlisted, age-restricted, "
                "region-locked, or removed)."
            ) from e
        raise YoutubeTranscriptError(f"Could not fetch captions: {e}") from e

    if not snippets:
        raise YoutubeTranscriptError(
            "No captions found for this video. Turn on subtitles/CC "
            "(Hindi, Bengali, English, or auto-captions) and try again."
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
            "Captions were too short to make study notes. Try another video with CC."
        )

    duration_minutes = max(1, int(math.ceil(end_seconds / 60.0)))
    return YoutubeCaptions(
        video_id=video_id,
        text=joined,
        duration_minutes=duration_minutes,
    )
