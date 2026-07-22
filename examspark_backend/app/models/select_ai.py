"""Select & Ask AI (Phase 6) — selection-scoped request/response models."""
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field

from app.constants.ai_response_status import AiResponseStatus
from app.constants.answer_source import AnswerSource, Confidence
from app.models.ask_ai import AskAiSource, ConversationLanguage

SelectAiAction = Literal[
    "explain",
    "simplify",
    "translate",
    "memory_trick",
    "exam_view",
    "generate_quiz",
    "generate_flashcards",
    "ask_followup",
]

SelectAiSourceSurface = Literal[
    "notes",
    "summary",
    "revision",
    "transcript",
    "flashcard",
]


class SelectAiRequest(BaseModel):
    lecture_id: str
    selected_text: str = Field(..., min_length=1, max_length=8000)
    action: SelectAiAction
    followup_query: Optional[str] = Field(default=None, max_length=2000)
    source_surface: Optional[SelectAiSourceSurface] = "notes"
    conversation_language: Optional[ConversationLanguage] = None


class SelectAiResponse(BaseModel):
    answer: str
    status: AiResponseStatus = "SUCCESS"
    action: str = "explain"
    answer_source: Optional[AnswerSource] = None
    confidence: Optional[Confidence] = None
    conversation_language: Optional[ConversationLanguage] = None
    sources: list[AskAiSource] = Field(default_factory=list)
    credits_charged: Optional[int] = None
    new_balance: Optional[int] = None
    visual_payload: Optional[dict[str, Any]] = None
    structured_result: Optional[dict[str, Any]] = None
