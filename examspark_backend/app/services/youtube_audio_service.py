"""YouTube temp audio download for Whisper fallback (no permanent storage).

Captions-first path lives in youtube_transcript_service.py.
When captions fail: yt-dlp → temp file → bytes → delete file in finally.
Non-CC videos must keep working (same as before) — not “CC only”.
"""
from __future__ import annotations

import logging
import math
import os
import tempfile
from pathlib import Path

from app.services.youtube_transcript_service import (
    YoutubeTranscriptError,
    extract_video_id,
)

logger = logging.getLogger(__name__)


class YoutubeAudioError(YoutubeTranscriptError):
    """User-facing audio download failure (no credits charged yet)."""


def _ydl_base_opts(outtmpl: str) -> dict:
    # Prefer small audio; speech-to-text does not need high bitrate.
    # socket_timeout avoids infinite hang; retries keep old reliability.
    return {
        "format": "bestaudio/best",
        "outtmpl": outtmpl,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "socket_timeout": 45,
        "retries": 3,
        "fragment_retries": 3,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "64",
            }
        ],
    }


def _try_download(url: str, tmp_dir: str, video_id: str, extra: dict) -> tuple[dict | None, Path | None]:
    import yt_dlp  # type: ignore

    outtmpl = str(Path(tmp_dir) / f"{video_id}.%(ext)s")
    opts = {**_ydl_base_opts(outtmpl), **extra}
    info: dict | None = None
    produced: Path | None = None
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url.strip(), download=True)
        candidate = Path(tmp_dir) / f"{video_id}.mp3"
        if candidate.is_file():
            produced = candidate
        else:
            for p in Path(tmp_dir).iterdir():
                if p.is_file() and p.stat().st_size > 0:
                    produced = p
                    break
    return info, produced


def download_youtube_audio_bytes(url: str) -> tuple[bytes, int, str]:
    """
    Download best audio-only stream to a temp file, read bytes, delete file.

    Returns (audio_bytes, duration_minutes, filename_for_whisper).
    Never leaves audio on disk after return.
    """
    video_id = extract_video_id(url)
    try:
        import yt_dlp  # type: ignore  # noqa: F401
    except ImportError as e:
        raise YoutubeAudioError(
            "YouTube Whisper fallback needs yt-dlp — install backend requirements "
            "(pip install -U yt-dlp)."
        ) from e

    tmp_dir = tempfile.mkdtemp(prefix="examspark_yt_")
    info: dict | None = None
    produced: Path | None = None
    last_err: Exception | None = None

    # YouTube often 403s default web client — try android/ios/tv/mweb like before
    # when non-CC Whisper path worked.
    client_attempts: list[dict] = [
        {
            "extractor_args": {
                "youtube": {"player_client": ["android", "web"]}
            }
        },
        {
            "extractor_args": {
                "youtube": {"player_client": ["ios", "mweb"]}
            }
        },
        {
            "extractor_args": {
                "youtube": {"player_client": ["tv_embedded", "web"]}
            }
        },
        {},  # default yt-dlp clients
    ]

    try:
        for i, extra in enumerate(client_attempts):
            try:
                # Clean partial files between attempts
                for p in Path(tmp_dir).iterdir():
                    try:
                        p.unlink(missing_ok=True)
                    except OSError:
                        pass
                info, produced = _try_download(url, tmp_dir, video_id, extra)
                if produced is not None and produced.is_file() and produced.stat().st_size > 1000:
                    logger.info(
                        "YouTube audio download OK video_id=%s attempt=%s",
                        video_id,
                        i + 1,
                    )
                    break
                produced = None
            except Exception as e:  # noqa: BLE001
                last_err = e
                logger.info(
                    "YouTube audio attempt %s failed video_id=%s: %s",
                    i + 1,
                    video_id,
                    e,
                )
                continue

        if produced is None or not produced.is_file():
            detail = str(last_err) if last_err else "no audio file"
            raise YoutubeAudioError(
                f"Could not download YouTube audio ({detail}). "
                "Server will retry with captions when available; otherwise try again shortly."
            )

        audio_bytes = produced.read_bytes()
        if len(audio_bytes) < 1000:
            raise YoutubeAudioError(
                "Downloaded audio was too short to transcribe. Please try again."
            )
        duration_sec = float((info or {}).get("duration") or 0.0)
        if duration_sec <= 0:
            duration_sec = max(60.0, len(audio_bytes) / 12000.0)
        duration_minutes = max(1, int(math.ceil(duration_sec / 60.0)))
        filename = produced.name if produced.suffix else f"{video_id}.mp3"
        return audio_bytes, duration_minutes, filename
    except YoutubeAudioError:
        raise
    except Exception as e:  # noqa: BLE001
        raise YoutubeAudioError(
            f"Could not download YouTube audio: {e}"
        ) from e
    finally:
        try:
            for p in Path(tmp_dir).iterdir():
                try:
                    p.unlink(missing_ok=True)
                except OSError:
                    logger.warning("Could not delete temp YouTube audio %s", p)
            os.rmdir(tmp_dir)
        except OSError:
            logger.warning("Could not remove temp YouTube dir %s", tmp_dir)
