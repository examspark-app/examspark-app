"""Credit Economy — Record/Audio Upload are per-minute; other features stay session-based.

Mirrors examspark_frontend/lib/core/constants/credit_costs.dart. Keep both
in sync when either changes — this is the copy the server actually charges
against via fn_deduct_credits(), so it is the source of truth for billing.

Founder Jul 22, 2026: Recording + Audio Upload = 1 credit/min (actual length,
round up, max 180). YouTube stays banded (10/20/40).
"""

# Record / Audio Upload — per-minute (founder-approved Jul 22, 2026).
RECORD_CREDITS_PER_MINUTE = 1
# Hard max for Record / audio upload (3 hours). YouTube stays at 90.
RECORD_MAX_MINUTES = 180
# Legacy band constants (pre–per-minute) — kept for reference / old imports only.
RECORD_UP_TO_30_MIN = 40
RECORD_30_TO_60_MIN = 80
RECORD_60_TO_90_MIN = 120
RECORD_90_TO_180_MIN = 240
SUMMARY_WITH_RECORDING = 0

ASK_AI_NORMAL = 5
ASK_AI_DEEP = 12
# Live web search (Tavily) — last-resort current affairs only. 2× normal Ask.
ASK_AI_WEB_SEARCH = 10
ASK_AI_WEB_SEARCH_DEEP = 20

# Home chat study chips (topic = prior Home reply). Not full lecture Mind Map / IQ.
# Phase 4C Final Hardening (Jul 17, 2026): first open from Knowledge Object = 0.
# These constants remain for explicit Regenerate pricing only.
HOME_CHIP_MIND_MAP = 10
HOME_CHIP_IMPORTANT_QUESTIONS = 10

FLASHCARDS = 5
QUIZ_20_MCQ = 5
IMPORTANT_QUESTIONS = 20
REVISION_NOTES = 5
# 5 Minute Revision — short quick-recap extra (same credit band as Revision Notes).
FIVE_MIN_REVISION = 5
FORMULA_SHEET = 15
MIND_MAP = 30


def ask_ai_cost(mode: str, *, used_web_search: bool = False) -> int:
    """Server charge for Ask AI / Home AI text answers."""
    deep = (mode or "").strip().lower() == "deep"
    if used_web_search:
        return ASK_AI_WEB_SEARCH_DEEP if deep else ASK_AI_WEB_SEARCH
    return ASK_AI_DEEP if deep else ASK_AI_NORMAL


def home_ai_cost_for_study_chip(
    study_chip: str | None, mode: str, *, used_web_search: bool = False
) -> int:
    """Server-side Home AI cost. Unknown chip → normal Ask AI price."""
    if used_web_search:
        return ask_ai_cost(mode, used_web_search=True)
    key = (study_chip or "").strip().lower()
    if key in ("mind_map", "mind-map"):
        return HOME_CHIP_MIND_MAP
    if key in ("important_questions", "important-questions"):
        return HOME_CHIP_IMPORTANT_QUESTIONS
    return ask_ai_cost(mode, used_web_search=False)


DIAGRAM_IMAGE = 25
# Home AI Camera / Upload Image → chat answer (not Study Workspace lecture).
HOME_AI_VISION = 10
PDF_ANALYSIS = 20
OCR_IMAGE = 15

TRANSLATE = 8
VOICE_READ = 5

# Select & Ask AI (Phase 6) — selection-scoped, cheaper than full Ask AI (5).
SELECT_AI_EXPLAIN = 2  # explain, simplify, translate, memory_trick, exam_view, ask_followup
SELECT_AI_MINI_QUIZ = 3  # 5 MCQ from selection
SELECT_AI_MINI_FLASHCARDS = 3  # 5 cards from selection

# YouTube Link → Notes: cheaper than Record (10 / 20 / 40). Max 90 min.
YOUTUBE_MAX_MINUTES = 90
YOUTUBE_UP_TO_30_MIN = 10
YOUTUBE_30_TO_60_MIN = 20
YOUTUBE_60_TO_90_MIN = 40
# Legacy aliases (older test/import names — map to new bands).
YOUTUBE_UP_TO_20_MIN = YOUTUBE_UP_TO_30_MIN
YOUTUBE_20_TO_40_MIN = YOUTUBE_30_TO_60_MIN
YOUTUBE_40_TO_60_MIN = YOUTUBE_60_TO_90_MIN


def record_credits_for_duration_minutes(minutes: int) -> int:
    """1 credit per minute (round up already done by caller). Clamp 1–180."""
    clamped = max(1, min(RECORD_MAX_MINUTES, int(minutes)))
    return clamped * RECORD_CREDITS_PER_MINUTE


def youtube_credits_for_duration_minutes(minutes: int) -> int:
    """YouTube Notes bands (10 / 20 / 40). Reject >90 elsewhere."""
    if minutes <= 30:
        return YOUTUBE_UP_TO_30_MIN
    if minutes <= 60:
        return YOUTUBE_30_TO_60_MIN
    if minutes <= 90:
        return YOUTUBE_60_TO_90_MIN
    return YOUTUBE_60_TO_90_MIN


def select_ai_cost_for_action(action: str) -> int:
    """Credits for Select AI actions. Unknown action → explain tier (2)."""
    key = (action or "").strip().lower()
    if key in ("generate_quiz", "quiz", "mini_quiz"):
        return SELECT_AI_MINI_QUIZ
    if key in ("generate_flashcards", "flashcards", "mini_flashcards"):
        return SELECT_AI_MINI_FLASHCARDS
    return SELECT_AI_EXPLAIN
