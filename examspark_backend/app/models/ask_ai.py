"""Ask AI request/response models — Session 3."""
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

from app.constants.ai_response_status import AiResponseStatus
from app.constants.answer_source import AnswerSource, Confidence

ConversationLanguage = Literal["ENGLISH", "HINDI", "BENGALI", "HINGLISH"]


class AskAiRequest(BaseModel):
    lecture_id: str
    query: str = Field(..., min_length=1, max_length=4000)
    mode: Literal["normal", "deep"] = "normal"
    conversation_language: Optional[ConversationLanguage] = None


class HomeAiRequest(BaseModel):
    """Home screen Study Coach. Optional lecture_id = Priority 1 open-lecture RAG."""

    query: str = Field(..., min_length=1, max_length=4000)
    mode: Literal["normal", "deep"] = "normal"
    lecture_id: Optional[str] = None
    conversation_language: Optional[ConversationLanguage] = None
    # Home study chips only — server maps to credit amount (never trust client amount).
    study_chip: Optional[Literal["mind_map", "important_questions"]] = None
    # Phase 4C V2 — follow-up creates Knowledge version N+1 and stale parent chips.
    parent_response_id: Optional[str] = None
    # Phase 4D — continue same Study Session thread.
    session_id: Optional[str] = None


class AskAiSource(BaseModel):
    source_type: Optional[str] = None
    similarity: Optional[float] = None
    excerpt: Optional[str] = None


class AskAiResponse(BaseModel):
    answer: str
    status: AiResponseStatus = "SUCCESS"
    answer_source: Optional[AnswerSource] = None
    confidence: Optional[Confidence] = None
    conversation_language: Optional[ConversationLanguage] = None
    sources: list[AskAiSource] = Field(default_factory=list)
    credits_charged: Optional[int] = None
    new_balance: Optional[int] = None
    mode: str = "normal"
    visual_payload: Optional[dict[str, Any]] = None
    # Phase 4C — master response id for chip tools (null if SQL not run yet)
    response_id: Optional[str] = None
    # Phase 4D — Study Session id (null if SQL not run yet)
    session_id: Optional[str] = None
    knowledge: Optional[dict[str, Any]] = None
