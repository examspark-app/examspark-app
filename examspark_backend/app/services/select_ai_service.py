"""Select & Ask AI (Phase 6) — selection-first, minimal RAG, streamed answers.

Never dumps the full lecture. Credits deducted only after SUCCESS.
"""
from __future__ import annotations

import json
import logging

import httpx

from app.config import AIConfig
from app.constants.ai_response_status import (
    API_ERROR,
    NETWORK_ERROR,
    SUCCESS,
    TIMEOUT,
    http_status_to_ai_status,
)
from app.constants.answer_source import derive_ask_ai_source, derive_confidence
from app.constants.credit_costs import select_ai_cost_for_action
from app.constants.language_hint import resolve_answer_language
from app.constants.rag_perf import (
    SELECT_CHUNK_MAX_CHARS,
    SELECT_MATCH_COUNT,
    SELECT_MAX_TOKENS,
)
from app.constants.select_ai_prompts import (
    STRUCTURED_JSON_DELIMITER,
    build_user_message,
    system_prompt_for_action,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.embedding_service import EmbeddingError, embed_query
from app.services.openrouter_stream import OpenRouterStreamError, stream_chat_completions
from app.services.performance_timer import PerformanceTimer
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.rag_ask_service import (
    AskAiError,
    _fetch_matches_with_fallback,
    _credits_balance,
)
from app.services.rag_index_service import RagIndexError, ensure_lecture_indexed
from app.services.r2_storage_service import R2StorageError, R2StorageService
from app.services.visual_stream_parser import VisualStreamParser, split_answer_and_visual

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
_MATCH_THRESHOLD = 0.20
_STRUCTURED_ACTIONS = frozenset({"generate_quiz", "generate_flashcards"})
# Short selections often need a tiny RAG assist; long selections may stand alone.
_RAG_IF_SELECTION_SHORTER_THAN = 120
_ACTIONS_NEEDING_RAG = frozenset({"exam_view", "explain", "ask_followup"})


class SelectAiError(AskAiError):
    """Same shape as AskAiError for router reuse."""


def _load_select_chunks(matches: list[dict], r2: R2StorageService) -> list[dict]:
    sources: list[dict] = []
    for m in matches:
        path = m.get("r2_chunk_path")
        if not path:
            continue
        try:
            text = r2.download_text(path)
        except R2StorageError:
            continue
        if len(text) > SELECT_CHUNK_MAX_CHARS:
            text = text[:SELECT_CHUNK_MAX_CHARS]
        sources.append(
            {
                "source_type": m.get("source_type"),
                "similarity": m.get("similarity"),
                "excerpt": text[:400],
                "text": text,
            }
        )
    return sources


async def _retrieve_selection_context(
    user_id: str,
    lecture_id: str,
    selected_text: str,
    action: str,
    timer: PerformanceTimer | None = None,
) -> tuple[list[str], list[dict]]:
    """Selected text first; max 2 notes chunks; optional 1 transcript chunk."""
    need_rag = (
        action in _ACTIONS_NEEDING_RAG
        or len(selected_text.strip()) < _RAG_IF_SELECTION_SHORTER_THAN
    )
    if not need_rag and action in _STRUCTURED_ACTIONS:
        # Quiz/flashcards from selection only — skip RAG for token savings.
        return [], []

    if timer:
        timer.start("index")
    await ensure_lecture_indexed(user_id, lecture_id)
    if timer:
        timer.end("index")

    if timer:
        timer.start("embed")
    embedding = await embed_query(selected_text)
    if timer:
        timer.end("embed")

    if timer:
        timer.start("vector")
    notes_hits = _fetch_matches_with_fallback(
        user_id,
        lecture_id,
        embedding,
        "notes",
        match_count=SELECT_MATCH_COUNT,
    )
    r2 = R2StorageService()
    loaded = _load_select_chunks(notes_hits[:SELECT_MATCH_COUNT], r2)

    if not loaded and action in ("exam_view", "explain"):
        tr_hits = _fetch_matches_with_fallback(
            user_id,
            lecture_id,
            embedding,
            "clean_transcript",
            match_count=1,
        )
        loaded = _load_select_chunks(tr_hits[:1], r2)

    if timer:
        timer.end("vector")
        timer.set(chunks=len(loaded))

    context_blocks = [s["text"] for s in loaded]
    sources_meta = [
        {
            "source_type": s["source_type"],
            "similarity": s["similarity"],
            "excerpt": s["excerpt"],
        }
        for s in loaded
    ]
    return context_blocks, sources_meta


def _split_structured(full_text: str) -> tuple[str, dict | None]:
    if STRUCTURED_JSON_DELIMITER not in full_text:
        return full_text.strip(), None
    before, after = full_text.split(STRUCTURED_JSON_DELIMITER, 1)
    raw = after.strip()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        start = raw.find("{")
        end = raw.rfind("}")
        if start == -1 or end <= start:
            return before.strip(), None
        try:
            parsed = json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            return before.strip(), None
    return before.strip(), parsed if isinstance(parsed, dict) else None


def _parse_structured_stream(full: str) -> tuple[str, dict | None]:
    answer, structured = _split_structured(full)
    return answer, structured


class StructuredStreamParser:
    """Like VisualStreamParser but for <<STRUCTURED_JSON>>."""

    def __init__(self) -> None:
        self._buf = ""
        self._done = False
        self._answer = ""
        self._structured: dict | None = None
        self._delim = STRUCTURED_JSON_DELIMITER

    @property
    def answer(self) -> str:
        return self._answer.strip()

    @property
    def structured_result(self) -> dict | None:
        return self._structured

    def feed(self, token: str) -> str:
        if self._done or not token:
            return ""
        self._buf += token
        if self._delim in self._buf:
            before, after = self._buf.split(self._delim, 1)
            self._answer += before
            _, structured = _split_structured(self._delim + after)
            self._structured = structured
            self._done = True
            return before
        hold = ""
        for i in range(min(len(self._buf), len(self._delim) - 1), 0, -1):
            if self._delim.startswith(self._buf[-i:]):
                hold = self._buf[-i:]
                break
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
        if self._delim in self._buf:
            before, after = self._buf.split(self._delim, 1)
            self._answer += before
            _, structured = _split_structured(self._delim + after)
            self._structured = structured
        else:
            self._answer += self._buf
        self._buf = ""
        self._done = True


async def _generate_select_answer(
    *,
    system: str,
    user_content: str,
) -> str:
    if not AIConfig.openrouter_configured():
        raise SelectAiError(
            "OPENROUTER_API_KEY not configured on the server.", status_code=500
        )
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                _OPENROUTER_URL,
                headers={
                    "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": AIConfig.AI_CHAT_MODEL,
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": user_content},
                    ],
                    "temperature": 0.3,
                    "max_tokens": SELECT_MAX_TOKENS,
                },
                timeout=60.0,
            )
    except httpx.TimeoutException as e:
        raise SelectAiError(
            "Select AI timed out.",
            status_code=504,
            result_status=TIMEOUT,
        ) from e
    except httpx.RequestError as e:
        raise SelectAiError(
            f"Select AI network error: {e}",
            status_code=502,
            result_status=NETWORK_ERROR,
        ) from e

    if response.status_code != 200:
        raise SelectAiError(
            f"Select AI failed: {response.status_code} {response.text[:300]}",
            status_code=502,
            result_status=API_ERROR,
        )
    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        raise SelectAiError(
            "Select AI returned no choices.",
            status_code=502,
            result_status=API_ERROR,
        )
    content = (choices[0].get("message") or {}).get("content") or ""
    if not content.strip():
        raise SelectAiError(
            "Select AI returned an empty answer.",
            status_code=502,
            result_status=API_ERROR,
        )
    return content.strip()


def _validate_action(action: str) -> str:
    allowed = {
        "explain",
        "simplify",
        "translate",
        "memory_trick",
        "exam_view",
        "generate_quiz",
        "generate_flashcards",
        "ask_followup",
    }
    key = (action or "").strip().lower()
    if key not in allowed:
        raise SelectAiError(
            f"Unknown Select AI action: {action}",
            status_code=400,
        )
    return key


async def select_ai(
    user_id: str,
    lecture_id: str,
    selected_text: str,
    action: str,
    *,
    followup_query: str | None = None,
    source_surface: str | None = "notes",
    conversation_language: str | None = None,
    charge_credits: bool = True,
) -> dict:
    timer = PerformanceTimer("select_ai")
    timer.start("validation")
    selected = (selected_text or "").strip()
    if not selected:
        raise SelectAiError("Selected text is empty.", status_code=400)
    action = _validate_action(action)
    if action == "ask_followup" and not (followup_query or "").strip():
        raise SelectAiError(
            "ask_followup requires followup_query.",
            status_code=400,
        )

    try:
        require_feature_unlocked(user_id, GatedFeature.ASK_AI)
    except FeatureLockedError as e:
        raise SelectAiError(
            str(e),
            status_code=403,
            result_status="FEATURE_LOCKED",
            detail=feature_locked_payload(e),
        ) from e

    amount = select_ai_cost_for_action(action)
    timer.end("validation")

    if charge_credits:
        balance = _credits_balance(user_id)
        if balance < amount:
            raise SelectAiError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    try:
        context_blocks, sources_meta = await _retrieve_selection_context(
            user_id, lecture_id, selected, action, timer=timer
        )
    except RagIndexError as e:
        raise SelectAiError(str(e), status_code=e.status_code) from e
    except EmbeddingError as e:
        raise SelectAiError(str(e), status_code=502) from e
    except AskAiError as e:
        raise SelectAiError(
            str(e),
            status_code=e.status_code,
            result_status=e.result_status,
            detail=e.detail,
        ) from e

    answer_source = derive_ask_ai_source(sources_meta, context_blocks)
    confidence = derive_confidence(sources_meta)
    resolved_lang = resolve_answer_language(selected, conversation_language)

    system = system_prompt_for_action(action)
    user_content = build_user_message(
        selected_text=selected,
        action=action,
        context_blocks=context_blocks,
        followup_query=followup_query,
        conversation_language=conversation_language,
        source_surface=source_surface,
    )

    timer.start("llm")
    raw = await _generate_select_answer(system=system, user_content=user_content)
    timer.end("llm")

    visual_payload = None
    structured_result = None
    if action in _STRUCTURED_ACTIONS:
        answer, structured_result = _parse_structured_stream(raw)
    else:
        answer, visual_payload = split_answer_and_visual(raw)

    if not answer and structured_result:
        answer = "Ready."

    if not (answer or "").strip() and not structured_result:
        raise SelectAiError(
            "Select AI returned an empty answer.",
            status_code=502,
            result_status=API_ERROR,
        )

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Select AI ({action})",
                lecture_id=lecture_id,
                action="select_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            raise SelectAiError(str(e), status_code=402) from e

    result = {
        "answer": answer or "",
        "status": SUCCESS,
        "action": action,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "sources": sources_meta,
        "credits_charged": credits_charged,
        "new_balance": new_balance,
    }
    if visual_payload is not None:
        result["visual_payload"] = visual_payload
    if structured_result is not None:
        result["structured_result"] = structured_result
    timer.set(cache_hit=False)
    timer.log()
    return result


async def select_ai_stream(
    user_id: str,
    lecture_id: str,
    selected_text: str,
    action: str,
    *,
    followup_query: str | None = None,
    source_surface: str | None = "notes",
    conversation_language: str | None = None,
    charge_credits: bool = True,
):
    """Async generator of SSE event dicts."""
    timer = PerformanceTimer("select_ai_stream")
    timer.start("validation")
    selected = (selected_text or "").strip()
    if not selected:
        yield {
            "type": "error",
            "status": "VALIDATION_ERROR",
            "message": "Selected text is empty.",
        }
        return
    try:
        action = _validate_action(action)
    except SelectAiError as e:
        yield {"type": "error", "status": e.result_status, "message": str(e)}
        return
    if action == "ask_followup" and not (followup_query or "").strip():
        yield {
            "type": "error",
            "status": "VALIDATION_ERROR",
            "message": "ask_followup requires followup_query.",
        }
        return

    try:
        require_feature_unlocked(user_id, GatedFeature.ASK_AI)
    except FeatureLockedError as e:
        payload = feature_locked_payload(e)
        yield {
            "type": "error",
            "status": "FEATURE_LOCKED",
            "code": "FEATURE_LOCKED",
            "message": payload["message"],
            "feature": payload["feature"],
            "current_plan": payload["current_plan"],
            "required_plan": payload["required_plan"],
        }
        return

    amount = select_ai_cost_for_action(action)
    timer.end("validation")

    if charge_credits:
        balance = _credits_balance(user_id)
        if balance < amount:
            yield {
                "type": "error",
                "status": "VALIDATION_ERROR",
                "message": (
                    f"Insufficient credits: balance {balance} < required {amount}"
                ),
            }
            return

    try:
        context_blocks, sources_meta = await _retrieve_selection_context(
            user_id, lecture_id, selected, action, timer=timer
        )
    except (RagIndexError, EmbeddingError, AskAiError) as e:
        status = getattr(e, "result_status", API_ERROR)
        code = getattr(e, "status_code", 502)
        yield {
            "type": "error",
            "status": status if isinstance(status, str) else http_status_to_ai_status(code),
            "message": str(e),
        }
        return

    answer_source = derive_ask_ai_source(sources_meta, context_blocks)
    confidence = derive_confidence(sources_meta)
    resolved_lang = resolve_answer_language(selected, conversation_language)

    yield {
        "type": "meta",
        "action": action,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
    }

    system = system_prompt_for_action(action)
    user_content = build_user_message(
        selected_text=selected,
        action=action,
        context_blocks=context_blocks,
        followup_query=followup_query,
        conversation_language=conversation_language,
        source_surface=source_surface,
    )
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_content},
    ]

    visual_payload = None
    structured_result = None
    use_structured = action in _STRUCTURED_ACTIONS
    parser = StructuredStreamParser() if use_structured else VisualStreamParser()

    try:
        timer.start("llm")
        async for delta in stream_chat_completions(
            messages,
            temperature=0.3,
            max_tokens=SELECT_MAX_TOKENS,
        ):
            safe = parser.feed(delta)
            if safe:
                yield {"type": "token", "text": safe}
        parser.finish()
        timer.end("llm")
    except OpenRouterStreamError as e:
        yield {
            "type": "error",
            "status": e.result_status,
            "message": str(e),
        }
        return

    answer = parser.answer
    if use_structured:
        structured_result = parser.structured_result  # type: ignore[attr-defined]
    else:
        visual_payload = parser.visual_payload  # type: ignore[attr-defined]

    if not answer and structured_result:
        answer = "Ready."
    if not (answer or "").strip() and not structured_result:
        yield {
            "type": "error",
            "status": API_ERROR,
            "message": "Select AI returned an empty answer.",
        }
        return

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Select AI ({action}) — stream",
                lecture_id=lecture_id,
                action="select_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            yield {
                "type": "error",
                "status": "VALIDATION_ERROR",
                "message": str(e),
            }
            return

    done_evt: dict = {
        "type": "done",
        "status": SUCCESS,
        "answer": answer,
        "action": action,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "credits_charged": credits_charged,
        "new_balance": new_balance,
    }
    if visual_payload is not None:
        done_evt["visual_payload"] = visual_payload
    if structured_result is not None:
        done_evt["structured_result"] = structured_result
    timer.set(cache_hit=False)
    timer.log()
    yield done_evt
