"""YouTube captions — not English-only (Bengali / Hindi / any track)."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.services.youtube_transcript_service import (
    YoutubeTranscriptError,
    fetch_youtube_captions,
)


def test_fetch_passes_preferred_languages_including_bengali():
    snippets = [
        SimpleNamespace(text="বাংলা লেকচার টেক্সট এখানে যথেষ্ট লম্বা।", start=0.0, duration=5.0),
        SimpleNamespace(text="আরও ক্যাপশন লাইন যাতে নোট বানানো যায়।", start=5.0, duration=5.0),
    ]
    fetched = MagicMock()
    fetched.__iter__ = lambda self: iter(snippets)

    api = MagicMock()
    api.fetch.return_value = fetched

    with patch(
        "youtube_transcript_api.YouTubeTranscriptApi",
        return_value=api,
    ):
        out = fetch_youtube_captions("https://www.youtube.com/watch?v=abcdefghijk")

    assert "বাংলা" in out.text
    langs = api.fetch.call_args.kwargs.get("languages") or api.fetch.call_args[0][1]
    assert "bn" in langs
    assert "bn-IN" in langs
    assert "hi" in langs
    assert "ta" in langs
    assert "te" in langs
    assert "en" in langs


def test_notes_language_rule_covers_india_and_world():
    from app.constants.visual_notes_prompt import NOTES_LANGUAGE_RULE

    assert "INPUT = OUTPUT" in NOTES_LANGUAGE_RULE or "SAME language" in NOTES_LANGUAGE_RULE
    assert "Qwen3" in NOTES_LANGUAGE_RULE
    assert "Bengali" in NOTES_LANGUAGE_RULE
    assert "Spanish" in NOTES_LANGUAGE_RULE
    assert "force English" in NOTES_LANGUAGE_RULE
    assert "Do NOT translate" in NOTES_LANGUAGE_RULE or "NOT translate" in NOTES_LANGUAGE_RULE


def test_fetch_falls_back_to_any_listed_track():
    snippets = [
        SimpleNamespace(text="Bengali only track text that is long enough here.", start=0.0, duration=4.0),
        SimpleNamespace(text="Second line of captions for notes generation.", start=4.0, duration=4.0),
    ]
    track = MagicMock()
    track.language_code = "bn"
    track.fetch.return_value = snippets

    transcript_list = MagicMock()
    transcript_list.find_manually_created_transcript.side_effect = Exception("no")
    transcript_list.find_generated_transcript.side_effect = Exception("no")
    transcript_list.find_transcript.side_effect = Exception("no")
    transcript_list.__iter__ = lambda self: iter([track])

    api = MagicMock()
    api.fetch.side_effect = Exception("en only miss")
    api.list.return_value = transcript_list

    with patch(
        "youtube_transcript_api.YouTubeTranscriptApi",
        return_value=api,
    ):
        out = fetch_youtube_captions("https://youtu.be/abcdefghijk")

    assert "Bengali only" in out.text
    track.fetch.assert_called()


def test_empty_url_rejected():
    with pytest.raises(YoutubeTranscriptError):
        fetch_youtube_captions("")
