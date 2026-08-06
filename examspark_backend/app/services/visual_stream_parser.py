"""Parse streamed AI answers with optional trailing <<VISUAL_JSON>>,
<<SUGGESTED_QUESTIONS>>, and <<PRACTICE_QUESTION>> blocks."""
from __future__ import annotations

import json

from app.constants.visual_notes_prompt import ASK_AI_STREAM_DELIMITER
from app.models.visual_payload import parse_visual_payload

_DELIM = ASK_AI_STREAM_DELIMITER
_SQ_START = "<<SUGGESTED_QUESTIONS>>"
_SQ_END = "<<END_SUGGESTED_QUESTIONS>>"
_PQ_START = "<<PRACTICE_QUESTION>>"
_PQ_END = "<<END_PRACTICE_QUESTION>>"

_MARKERS = [_DELIM, _SQ_START, _PQ_START]


class VisualStreamParser:
    """Buffers stream tokens; forwards answer text; extracts visual JSON,
    suggested-questions, and practice-question blocks at the end (never
    shown to the client)."""

    def __init__(self) -> None:
        self._buf = ""
        self._tail = ""
        self._in_tail = False
        self._done = False
        self._answer = ""
        self._visual: dict | None = None
        self._suggested_questions: list[str] = []
        self._practice_question: str | None = None

    @property
    def finished(self) -> bool:
        return self._done

    @property
    def answer(self) -> str:
        return self._answer.strip()

    @property
    def visual_payload(self) -> dict | None:
        return self._visual

    @property
    def suggested_questions(self) -> list[str]:
        return self._suggested_questions

    @property
    def practice_question(self) -> str | None:
        return self._practice_question

    def feed(self, token: str) -> str:
        if self._done or not token:
            return ""

        if self._in_tail:
            self._tail += token
            return ""

        self._buf += token

        earliest_idx = -1
        for marker in _MARKERS:
            idx = self._buf.find(marker)
            if idx != -1 and (earliest_idx == -1 or idx < earliest_idx):
                earliest_idx = idx

        if earliest_idx != -1:
            before = self._buf[:earliest_idx]
            self._answer += before
            self._tail = self._buf[earliest_idx:]
            self._in_tail = True
            self._buf = ""
            return before

        hold = _partial_marker_suffix(self._buf)
        if hold:
            safe = self._buf[: -len(hold)]
            self._answer += safe
            self._buf = hold
            return safe
        out = self._buf
        self._answer += out
        self._buf = ""
        return out

    def finish(self) -> None:
        if self._done:
            return
        raw_tail = self._tail if self._in_tail else self._buf
        if not self._in_tail:
            earliest_idx = -1
            for marker in _MARKERS:
                idx = raw_tail.find(marker)
                if idx != -1 and (earliest_idx == -1 or idx < earliest_idx):
                    earliest_idx = idx
            if earliest_idx != -1:
                self._answer += raw_tail[:earliest_idx]
                raw_tail = raw_tail[earliest_idx:]
            else:
                self._answer += raw_tail
                raw_tail = ""

        self._parse_tail_blocks(raw_tail)
        self._buf = ""
        self._tail = ""
        self._done = True

    def _parse_tail_blocks(self, raw_tail: str) -> None:
        remaining = raw_tail

        sq_start = remaining.find(_SQ_START)
        if sq_start != -1:
            sq_end = remaining.find(_SQ_END, sq_start)
            if sq_end != -1:
                sq_raw = remaining[sq_start + len(_SQ_START) : sq_end].strip()
                self._suggested_questions = _parse_questions_json(sq_raw)
                remaining = (
                    remaining[:sq_start] + remaining[sq_end + len(_SQ_END) :]
                )
            else:
                remaining = remaining[:sq_start]

        pq_start = remaining.find(_PQ_START)
        if pq_start != -1:
            pq_end = remaining.find(_PQ_END, pq_start)
            if pq_end != -1:
                pq_raw = remaining[pq_start + len(_PQ_START) : pq_end].strip()
                self._practice_question = _parse_practice_json(pq_raw)
                remaining = (
                    remaining[:pq_start] + remaining[pq_end + len(_PQ_END) :]
                )
            else:
                remaining = remaining[:pq_start]

        if _DELIM in remaining:
            before, after = remaining.split(_DELIM, 1)
            self._answer += before
            self._parse_visual_json(after)
        else:
            self._answer += remaining

    def _parse_visual_json(self, raw: str) -> None:
        raw = raw.strip()
        if not raw:
            return
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            start = raw.find("{")
            end = raw.rfind("}")
            if start == -1 or end <= start:
                return
            try:
                parsed = json.loads(raw[start : end + 1])
            except json.JSONDecodeError:
                return
        if isinstance(parsed, dict):
            vp = parsed.get("visualPayload") or parsed.get("visual_payload") or parsed
            visual = parse_visual_payload(vp if isinstance(vp, dict) else None)
            if visual is not None:
                self._visual = visual.model_dump(by_alias=False)


def _parse_questions_json(raw: str) -> list[str]:
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        start = raw.find("[")
        end = raw.rfind("]")
        if start == -1 or end <= start:
            return []
        try:
            parsed = json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            return []
    if isinstance(parsed, list):
        return [str(q).strip() for q in parsed if str(q).strip()][:3]
    return []


def _parse_practice_json(raw: str) -> str | None:
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, str) and parsed.strip():
            return parsed.strip()
    except json.JSONDecodeError:
        pass
    return None


def _partial_marker_suffix(buf: str) -> str:
    max_len = max(len(m) for m in _MARKERS) - 1
    for i in range(min(len(buf), max_len), 0, -1):
        suffix = buf[-i:]
        for marker in _MARKERS:
            if marker.startswith(suffix):
                return suffix
    return ""


def split_answer_and_visual(full_text: str) -> tuple[str, dict | None]:
    parser = VisualStreamParser()
    parser.feed(full_text)
    parser.finish()
    return parser.answer, parser.visual_payload