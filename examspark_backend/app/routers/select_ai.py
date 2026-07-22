"""Select & Ask AI routes — Phase 6 (JSON + SSE stream)."""
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.constants.ai_response_status import ai_error_payload
from app.models.ask_ai import AskAiSource
from app.models.select_ai import SelectAiRequest, SelectAiResponse
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.openrouter_stream import format_sse
from app.services.select_ai_service import SelectAiError, select_ai, select_ai_stream

router = APIRouter(prefix="/api/v1", tags=["select-ai"])


def _to_response(result: dict) -> SelectAiResponse:
    return SelectAiResponse(
        answer=result.get("answer") or "",
        status=result.get("status") or "SUCCESS",
        action=result.get("action") or "explain",
        answer_source=result.get("answer_source"),
        confidence=result.get("confidence"),
        conversation_language=result.get("conversation_language"),
        sources=[AskAiSource(**s) for s in result.get("sources") or []],
        credits_charged=result.get("credits_charged"),
        new_balance=result.get("new_balance"),
        visual_payload=result.get("visual_payload"),
        structured_result=result.get("structured_result"),
    )


async def _sse_from_events(events: AsyncIterator[dict]) -> AsyncIterator[str]:
    async for event in events:
        yield format_sse(event)


def _http_detail(exc: SelectAiError) -> dict:
    if exc.detail is not None:
        return exc.detail
    return ai_error_payload(str(exc), exc.result_status)


@router.post("/select-ai", response_model=SelectAiResponse)
async def post_select_ai(
    body: SelectAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        result = await select_ai(
            user_id=user.user_id,
            lecture_id=body.lecture_id,
            selected_text=body.selected_text,
            action=body.action,
            followup_query=body.followup_query,
            source_surface=body.source_surface,
            conversation_language=body.conversation_language,
            charge_credits=True,
        )
    except SelectAiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=_http_detail(e),
        ) from e
    return _to_response(result)


@router.post("/select-ai/stream")
async def post_select_ai_stream(
    body: SelectAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    return StreamingResponse(
        _sse_from_events(
            select_ai_stream(
                user_id=user.user_id,
                lecture_id=body.lecture_id,
                selected_text=body.selected_text,
                action=body.action,
                followup_query=body.followup_query,
                source_surface=body.source_surface,
                conversation_language=body.conversation_language,
                charge_credits=True,
            )
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
