"""Parse streamed AI answers with optional trailing <<VISUAL_JSON>> block."""
from __future__ import annotations

import json

from app.constants.visual_notes_prompt import ASK_AI_STREAM_DELIMITER
from app.models.visual_payload import parse_visual_payload

_DELIM = ASK_AI_STREAM_DELIMITER


class VisualStreamParser:
    """Buffers stream tokens; forwards answer text; extracts visual JSON at end."""

    def __init__(self) -> None:
        self._buf = ""
        self._done = False
        self._answer = ""
        self._visual: dict | None = None

    @property
    def finished(self) -> bool:
        return self._done

    @property
    def answer(self) -> str:
        return self._answer.strip()

    @property
    def visual_payload(self) -> dict | None:
        return self._visual

    def feed(self, token: str) -> str:
        """Feed a token chunk; return text safe to forward to the client."""
        if self._done or not token:
            return ""
        self._buf += token
        if _DELIM in self._buf:
            before, after = self._buf.split(_DELIM, 1)
            self._answer += before
            self._parse_visual_json(after)
            self._done = True
            return before
        # Hold back a partial delimiter suffix
        hold = _partial_delimiter_suffix(self._buf)
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
        """Flush remaining buffer when stream ends without delimiter."""
        if self._done:
            return
        if _DELIM in self._buf:
            before, after = self._buf.split(_DELIM, 1)
            self._answer += before
            self._parse_visual_json(after)
        else:
            self._answer += self._buf
        self._buf = ""
        self._done = True

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


def _partial_delimiter_suffix(buf: str) -> str:
    for i in range(min(len(buf), len(_DELIM) - 1), 0, -1):
        if _DELIM.startswith(buf[-i:]):
            return buf[-i:]
    return ""


def split_answer_and_visual(full_text: str) -> tuple[str, dict | None]:
    """Split a complete non-stream response that may include the delimiter."""
    parser = VisualStreamParser()
    parser.feed(full_text)
    parser.finish()
    return parser.answer, parser.visual_payload
