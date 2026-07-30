"""Ask AI routes — Session 3 RAG + Home AI (JSON + additive SSE stream) + Phase 4C tools."""
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from app.constants.ai_response_status import ai_error_payload
from app.models.ask_ai import AskAiRequest, AskAiResponse, AskAiSource, HomeAiRequest
from app.services.auth_service import AuthenticatedUser, get_current_user
from app.services.home_ai_service import HomeAiError, home_ai, home_ai_stream
from app.services.home_ai_session_service import (
    delete_session,
    list_sessions,
    rename_session,
    restore_session,
    set_session_pinned,
)
from app.services.pyq_retrieve import format_verified_pyq_line, match_pyqs_for_query
from app.services.home_ai_tools_service import (
    HomeAiToolError,
    generate_or_get_tool,
    get_tool_payload,
    list_tool_statuses,
)
from app.services.home_ai_vision_service import home_ai_vision
from app.services.openrouter_stream import format_sse
from app.services.rag_ask_service import AskAiError, ask_ai, ask_ai_stream
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/v1", tags=["ask-ai"])


class _RenameSessionBody(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)


class _PinSessionBody(BaseModel):
    pinned: bool = True

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
        visual_payload=result.get("visual_payload"),
        response_id=result.get("response_id"),
        session_id=result.get("session_id"),
        knowledge=result.get("knowledge"),
    )


async def _sse_from_events(events: AsyncIterator[dict]) -> AsyncIterator[str]:
    async for event in events:
        yield format_sse(event)


def _http_detail_from_ai_error(exc: AskAiError | HomeAiError) -> dict:
    if exc.detail is not None:
        return exc.detail
    return ai_error_payload(str(exc), exc.result_status)


def _http_from_tool_error(exc: HomeAiToolError) -> HTTPException:
    if exc.detail is not None:
        return HTTPException(status_code=exc.status_code, detail=exc.detail)
    return HTTPException(status_code=exc.status_code, detail=str(exc))


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
            detail=_http_detail_from_ai_error(e),
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
            study_chip=body.study_chip,
            parent_response_id=body.parent_response_id,
            session_id=body.session_id,
            charge_credits=True,
        )
    except HomeAiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=_http_detail_from_ai_error(e),
        ) from e

    return _to_response(result, body.mode)


@router.post("/home-ai/vision", response_model=AskAiResponse)
async def post_home_ai_vision(
    file: UploadFile = File(...),
    query: str = Form(""),
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Camera / image upload → Home chat answer (not Study Workspace lecture).

    Credits: HOME_AI_VISION (10). Deduct only after vision SUCCESS.
    """
    raw = await file.read()
    try:
        result = await home_ai_vision(
            user_id=user.user_id,
            image_bytes=raw,
            filename=file.filename,
            mime_type=file.content_type,
            query=query,
        )
    except HomeAiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail=_http_detail_from_ai_error(e),
        ) from e

    return _to_response(result, "normal")


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
                study_chip=body.study_chip,
                parent_response_id=body.parent_response_id,
                session_id=body.session_id,
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


@router.get("/home-ai/responses/{response_id}/tools")
async def get_home_ai_tool_statuses(
    response_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Hydrate all chip states for one master response (Phase 4C)."""
    try:
        return list_tool_statuses(response_id, user.user_id)
    except HomeAiToolError as e:
        raise _http_from_tool_error(e) from e


@router.get("/home-ai/responses/{response_id}/tools/{tool_type}")
async def get_home_ai_tool(
    response_id: str,
    tool_type: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Free read of a generated chip payload (0 credits)."""
    try:
        return get_tool_payload(response_id, user.user_id, tool_type)
    except HomeAiToolError as e:
        raise _http_from_tool_error(e) from e


@router.post("/home-ai/responses/{response_id}/tools/{tool_type}")
async def post_home_ai_tool(
    response_id: str,
    tool_type: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Generate chip once from Knowledge Object; reuse if already generated."""
    try:
        return await generate_or_get_tool(
            user_id=user.user_id,
            response_id=response_id,
            tool_type=tool_type,
            regenerate=False,
        )
    except HomeAiToolError as e:
        raise _http_from_tool_error(e) from e


@router.post("/home-ai/responses/{response_id}/tools/{tool_type}/regenerate")
async def post_home_ai_tool_regenerate(
    response_id: str,
    tool_type: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Explicit regenerate — charges again after SUCCESS."""
    try:
        return await generate_or_get_tool(
            user_id=user.user_id,
            response_id=response_id,
            tool_type=tool_type,
            regenerate=True,
        )
    except HomeAiToolError as e:
        raise _http_from_tool_error(e) from e


# ── Phase 4D — Home AI Study History (0 credits on read) ──────────────────


@router.get("/home-ai/pyq-related")
async def get_home_ai_pyq_related(
    q: str,
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = 3,
):
    """
    Related PYQ metadata tags for a question (0 credits · no AI).
    Used by Home PYQs chip + smoke. Never returns original paper text.
    """
    _ = user  # auth required
    query = (q or "").strip()
    if not query:
        raise HTTPException(status_code=400, detail="q is required")
    matches = await match_pyqs_for_query(query, limit=limit)
    return {
        "query": query,
        "matches": matches,
        "lines": [format_verified_pyq_line(m) for m in matches],
        "credits_charged": 0,
    }


@router.get("/home-ai/sessions")
async def get_home_ai_sessions(
    user: AuthenticatedUser = Depends(get_current_user),
    limit: int = 40,
    q: str | None = None,
):
    """List Study Sessions for History UI. No AI · 0 credits."""
    return {
        "sessions": list_sessions(user.user_id, limit=limit, q=q),
        "credits_charged": 0,
    }


@router.get("/home-ai/sessions/{session_id}")
async def get_home_ai_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Restore full session (messages + chip statuses). No AI · 0 credits."""
    data = restore_session(session_id, user.user_id)
    if not data:
        raise HTTPException(status_code=404, detail="Study session not found.")
    return data


@router.patch("/home-ai/sessions/{session_id}")
async def patch_home_ai_session(
    session_id: str,
    body: _RenameSessionBody,
    user: AuthenticatedUser = Depends(get_current_user),
):
    row = rename_session(session_id, user.user_id, body.title)
    if not row:
        raise HTTPException(status_code=404, detail="Study session not found.")
    return {"id": row["id"], "title": row.get("title"), "credits_charged": 0}


@router.post("/home-ai/sessions/{session_id}/pin")
async def post_home_ai_session_pin(
    session_id: str,
    body: _PinSessionBody,
    user: AuthenticatedUser = Depends(get_current_user),
):
    ok = set_session_pinned(session_id, user.user_id, body.pinned)
    if not ok:
        raise HTTPException(status_code=404, detail="Study session not found.")
    return {"id": session_id, "pinned": body.pinned, "credits_charged": 0}


@router.delete("/home-ai/sessions/{session_id}")
async def delete_home_ai_session(
    session_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    ok = delete_session(session_id, user.user_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Study session not found.")
    return {"ok": True, "credits_charged": 0}