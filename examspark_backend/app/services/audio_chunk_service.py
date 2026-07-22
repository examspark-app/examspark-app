"""Split long Record / audio-upload files for Whisper (ffmpeg).

Students never see chunk / Whisper / Turbo wording — server-side only.
Short audio stays on the single-call path (no extra latency).
"""
from __future__ import annotations

import logging
import math
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from app.constants.credit_costs import RECORD_MAX_MINUTES

logger = logging.getLogger(__name__)

# Student-safe — no technical detail.
RECORD_TOO_LONG_USER_MESSAGE = (
    "This recording is longer than 3 hours. "
    "Please split it into shorter parts and try again."
)

# Chunk when longer than this (seconds) or larger than BYTE_THRESHOLD.
CHUNK_THRESHOLD_SECONDS = 20 * 60
CHUNK_SECONDS = 12 * 60  # ~10–15 min band
# Groq upload comfort — large files also trigger chunking even if probe fails.
BYTE_THRESHOLD = 18 * 1024 * 1024


class AudioChunkError(Exception):
    """ffmpeg / probe failure — map to a friendly pipeline error upstream."""


def stitch_transcript_parts(parts: list[str]) -> str:
    """Join chunk transcripts with a light paragraph break."""
    cleaned = [(p or "").strip() for p in parts if (p or "").strip()]
    return "\n\n".join(cleaned)


def should_chunk_audio(
    audio_bytes: bytes,
    filename: str | None = None,
    *,
    duration_seconds: float | None = None,
) -> bool:
    """True when audio should be split before Whisper."""
    if duration_seconds is not None and duration_seconds > CHUNK_THRESHOLD_SECONDS:
        return True
    if len(audio_bytes) > BYTE_THRESHOLD:
        return True
    if duration_seconds is None:
        probed = probe_duration_seconds(audio_bytes, filename or "audio.webm")
        if probed is not None and probed > CHUNK_THRESHOLD_SECONDS:
            return True
    return False


def probe_duration_seconds(audio_bytes: bytes, filename: str) -> float | None:
    """Return duration in seconds via ffprobe, or None if unavailable."""
    if not audio_bytes:
        return None
    if shutil.which("ffprobe") is None:
        return None

    suffix = Path(filename or "audio.webm").suffix or ".webm"
    tmp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = Path(tmp.name)
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(tmp_path),
            ],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if result.returncode != 0:
            logger.warning("ffprobe failed: %s", (result.stderr or "")[:200])
            return None
        raw = (result.stdout or "").strip()
        if not raw:
            return None
        seconds = float(raw)
        if not math.isfinite(seconds) or seconds <= 0:
            return None
        return seconds
    except (OSError, ValueError, subprocess.TimeoutExpired) as e:
        logger.warning("ffprobe error: %s", e)
        return None
    finally:
        if tmp_path is not None:
            try:
                tmp_path.unlink(missing_ok=True)
            except OSError:
                pass


def probe_duration_minutes(audio_bytes: bytes, filename: str) -> int | None:
    seconds = probe_duration_seconds(audio_bytes, filename)
    if seconds is None:
        return None
    return max(1, int(math.ceil(seconds / 60.0)))


def split_audio_into_chunks(
    audio_bytes: bytes,
    filename: str,
    *,
    chunk_seconds: int = CHUNK_SECONDS,
) -> list[tuple[bytes, str]]:
    """
    Split audio into sequential ~chunk_seconds pieces via ffmpeg.

    Returns list of (chunk_bytes, chunk_filename). Raises AudioChunkError
    if ffmpeg is missing or split fails. Caller must clean up — no files left.
    """
    if shutil.which("ffmpeg") is None:
        raise AudioChunkError(
            "Long recordings need ffmpeg on the server. "
            "Please try a shorter clip, or contact support."
        )

    suffix = Path(filename or "audio.webm").suffix or ".webm"
    tmp_dir = tempfile.mkdtemp(prefix="examspark_chunk_")
    in_path = Path(tmp_dir) / f"input{suffix}"
    out_pattern = str(Path(tmp_dir) / "chunk_%03d.mp3")
    chunks: list[tuple[bytes, str]] = []

    try:
        in_path.write_bytes(audio_bytes)
        result = subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(in_path),
                "-f",
                "segment",
                "-segment_time",
                str(int(chunk_seconds)),
                "-reset_timestamps",
                "1",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-c:a",
                "libmp3lame",
                "-b:a",
                "64k",
                out_pattern,
            ],
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
        if result.returncode != 0:
            err = (result.stderr or result.stdout or "")[:400]
            raise AudioChunkError(
                "Could not prepare this long recording. "
                "Please try again, or split into a shorter file."
            ) from RuntimeError(err)

        produced = sorted(Path(tmp_dir).glob("chunk_*.mp3"))
        if not produced:
            raise AudioChunkError(
                "Could not prepare this long recording. Please try again."
            )

        for i, path in enumerate(produced):
            data = path.read_bytes()
            if len(data) < 100:
                continue
            chunks.append((data, f"chunk_{i:03d}.mp3"))

        if not chunks:
            raise AudioChunkError(
                "Could not prepare this long recording. Please try again."
            )
        logger.info(
            "audio_chunk_service: split %s bytes into %s chunks (~%ss each)",
            len(audio_bytes),
            len(chunks),
            chunk_seconds,
        )
        return chunks
    finally:
        try:
            for p in Path(tmp_dir).iterdir():
                try:
                    p.unlink(missing_ok=True)
                except OSError:
                    pass
            os.rmdir(tmp_dir)
        except OSError:
            logger.warning("Could not remove temp chunk dir %s", tmp_dir)


def resolve_record_duration_minutes(
    *,
    client_minutes: int | None,
    audio_bytes: bytes,
    filename: str,
) -> int:
    """
    Prefer probed duration; fall back to client. Raises AudioChunkError
    (with RECORD_TOO_LONG_USER_MESSAGE) when over 180 minutes.
    """
    probed = probe_duration_minutes(audio_bytes, filename)
    if probed is not None and probed > RECORD_MAX_MINUTES:
        raise AudioChunkError(RECORD_TOO_LONG_USER_MESSAGE)

    fallback = int(client_minutes or 60)
    if fallback > RECORD_MAX_MINUTES:
        raise AudioChunkError(RECORD_TOO_LONG_USER_MESSAGE)

    minutes = probed if probed is not None else fallback
    return max(1, min(RECORD_MAX_MINUTES, int(minutes)))
