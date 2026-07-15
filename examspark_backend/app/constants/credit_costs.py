"""Credit Economy v2.1 — feature/session-based, never per-minute in UI.

Mirrors examspark_frontend/lib/core/constants/credit_costs.dart. Keep both
in sync when either changes — this is the copy the server actually charges
against via fn_deduct_credits(), so it is the source of truth for billing.
"""

RECORD_UP_TO_30_MIN = 40
RECORD_30_TO_60_MIN = 80
RECORD_60_TO_90_MIN = 120
SUMMARY_WITH_RECORDING = 0

ASK_AI_NORMAL = 5
ASK_AI_DEEP = 12

FLASHCARDS = 20
QUIZ_20_MCQ = 25
IMPORTANT_QUESTIONS = 20
REVISION_NOTES = 20
FORMULA_SHEET = 15
MIND_MAP = 30

DIAGRAM_IMAGE = 25
PDF_ANALYSIS = 20
OCR_IMAGE = 15

TRANSLATE = 8
VOICE_READ = 5

# YouTube Link → Notes (founder-locked Jul 12, 2026) — captions only, no Whisper.
YOUTUBE_UP_TO_20_MIN = 35
YOUTUBE_20_TO_40_MIN = 65
YOUTUBE_40_TO_60_MIN = 100
YOUTUBE_MAX_MINUTES = 60


def record_credits_for_duration_minutes(minutes: int) -> int:
    if minutes <= 30:
        return RECORD_UP_TO_30_MIN
    if minutes <= 60:
        return RECORD_30_TO_60_MIN
    if minutes <= 90:
        return RECORD_60_TO_90_MIN
    return RECORD_60_TO_90_MIN


def youtube_credits_for_duration_minutes(minutes: int) -> int:
    """Band cost. Caller must reject videos longer than YOUTUBE_MAX_MINUTES first."""
    if minutes <= 20:
        return YOUTUBE_UP_TO_20_MIN
    if minutes <= 40:
        return YOUTUBE_20_TO_40_MIN
    return YOUTUBE_40_TO_60_MIN
