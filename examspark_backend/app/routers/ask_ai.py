"""Ask AI routes — Session 3 RAG + Home AI (JSON + additive SSE stream)."""
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.constants.ai_response_status import ai_error_payload
from app.models.ask_ai import AskAiRequest, AskAiResponse, AskAiSource, HomeAiRequest
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.home_ai_service import HomeAiError, home_ai, home_ai_stream
from app.services.openrouter_stream import format_sse
from app.services.rag_ask_service import AskAiError, ask_ai, ask_ai_stream

router = APIRouter(prefix="/api/v1", tags=["ask-ai"])


def _to_response(result: dict, mode: str) -> AskAiResponse:
    return AskAiResponse(
        answer=result["answer"],
        status=result.get("status") or "SUCCESS",
        answer_source=result.get("answer_source"),
        confidence=result.get("confidence"),
        conversation_language=result.get("conversation_language"),
        sources=[AskAiSource(**s) for s in result.get("sources") or []],
        credits_charged=result.get("credits_charged"),
        new_balance=result.get("new_balance"),
        mode=result.get("mode") or mode,
    )


async def _sse_from_events(events: AsyncIterator[dict]) -> AsyncIterator[str]:
    async for event in events:
        yield format_sse(event)


@router.post("/ask-ai", response_model=AskAiResponse)
async def post_ask_ai(
    body: AskAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        result = await ask_ai(
            user_id=user.user_id,
            lecture_id=body.lecture_id,
            query=body.query,
            mode=body.mode,
            conversation_language=body.conversation_language,
            charge_credits=True,
        )
    except AskAiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=ai_error_payload(str(e), e.result_status),
        ) from e

    return _to_response(result, body.mode)


@router.post("/home-ai", response_model=AskAiResponse)
async def post_home_ai(
    body: HomeAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    try:
        result = await home_ai(
            user_id=user.user_id,
            query=body.query,
            mode=body.mode,
            lecture_id=body.lecture_id,
            conversation_language=body.conversation_language,
            charge_credits=True,
        )
    except HomeAiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=ai_error_payload(str(e), e.result_status),
        ) from e

    return _to_response(result, body.mode)


@router.post("/ask-ai/stream")
async def post_ask_ai_stream(
    body: AskAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Additive SSE path — JSON /ask-ai unchanged."""
    return StreamingResponse(
        _sse_from_events(
            ask_ai_stream(
                user_id=user.user_id,
                lecture_id=body.lecture_id,
                query=body.query,
                mode=body.mode,
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


@router.post("/home-ai/stream")
async def post_home_ai_stream(
    body: HomeAiRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Additive SSE path — JSON /home-ai unchanged."""
    return StreamingResponse(
        _sse_from_events(
            home_ai_stream(
                user_id=user.user_id,
                query=body.query,
                mode=body.mode,
                lecture_id=body.lecture_id,
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
