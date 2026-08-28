"""Home AI — education Study Coach for Home chat.

Retrieval order: User RAG → PYQ → Internal Knowledge → Web (Tavily last resort).
Tavily only on web_deferred after empty RAG/PYQ + current-affairs classifier.

Credits: Ask AI Normal 5 / Deep 12; Web search 10 / 20.
Phase 1 perf: smart route, caches, timing (SSE already live).
"""
from __future__ import annotations

import asyncio
import json
import re
import httpx

from app.config import AIConfig
from app.constants.ai_response_status import (
    API_ERROR,
    NETWORK_ERROR,
    SUCCESS,
    TIMEOUT,
    http_status_to_ai_status,
)
from app.constants.ai_speed import answer_length_user_line, max_tokens_for_mode
from app.constants.answer_source import (
    MEDIUM,
    NO_MATCH,
    WEB,
    derive_home_ai_confidence,
    derive_home_ai_source,
)
from app.constants.credit_costs import home_ai_cost_for_study_chip
from app.constants.answer_intelligence import ANSWER_INTELLIGENCE_BLOCK
from app.constants.language_hint import (
    language_hint_user_line,
    resolve_answer_language,
    typo_intent_rule_block,
)
from app.constants.visual_notes_prompt import ASK_AI_VISUAL_EXTENSION
from app.constants.subject_patterns import subject_teaching_hint
from app.services.ai_performance_cache import (
    answer_cache_key,
    find_semantic_cached_answer,
    get_cached_answer,
    set_cached_answer,
)
from app.services.credits_service import (
    InsufficientCreditsError,
    deduct_credits,
    get_credits_balance as _credits_balance,
)
from app.services.home_ai_followup import looks_like_knowledge_follow_up
from app.services.openrouter_stream import OpenRouterStreamError, stream_chat_completions
from app.services.performance_timer import PerformanceTimer
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)

from app.services.question_router import route_home_question, should_run_rag
from app.services.embedding_service import EmbeddingError
from app.services.rag_ask_service import (
    AskAiError,
    _replay_cached_tokens,
    _retrieve_lecture_rag,
)
from app.services.rag_index_service import RagIndexError
from app.services.home_ai_knowledge import build_knowledge_object
from app.services.pyq_retrieve import format_verified_pyq_block
from app.services.tavily_gate import try_tavily_fallback
from app.services.home_ai_response_store import (
    mark_tools_stale_for_response,
    next_knowledge_version,
    persist_home_ai_response,
)
from app.services.home_ai_session_service import (
    ensure_session_for_turn,
    get_recent_messages,
)
from app.services.visual_fallback import (
    fallback_visual_payload,
    visual_reminder_user_line,
    wants_visual,
)
from app.services.visual_stream_parser import VisualStreamParser, split_answer_and_visual


def _is_placeholder_visual(vp: object) -> bool:
    """Detect the old fake 'Concept / Key relation / Result' stub."""
    if not isinstance(vp, dict):
        return False
    for d in vp.get("text_diagrams") or []:
        if not isinstance(d, dict):
            continue
        content = str(d.get("content") or "")
        if "Key relation" in content or "Result / roots" in content:
            return True
    return False


def _attach_session(
    *,
    user_id: str,
    query: str,
    answer: str,
    result: dict,
    response_id: str,
    session_id: str | None,
    parent_response_id: str | None,
) -> None:
    """Phase 4D — link turn into Study Session (0 cost; soft-fail)."""
    sid = ensure_session_for_turn(
        user_id=user_id,
        query=query,
        answer=answer,
        response_id=str(response_id),
        credits_used=int(result.get("credits_charged") or 0),
        session_id=session_id,
        parent_response_id=parent_response_id,
        conversation_language=result.get("conversation_language"),
    )
    if sid:
        result["session_id"] = sid


def _finalize_home_result(
    *,
    user_id: str,
    query: str,
    answer: str,
    result: dict,
    lecture_id: str | None,
    parent_response_id: str | None = None,
    session_id: str | None = None,
) -> dict:
    """Build knowledge object, persist master response, attach response_id + session."""
    visual_payload = result.get("visual_payload")
    knowledge = build_knowledge_object(
        query=query,
        answer=answer,
        visual_payload=visual_payload if isinstance(visual_payload, dict) else None,
        answer_source=result.get("answer_source"),
        confidence=result.get("confidence"),
    )
    version = 1
    parent = (parent_response_id or "").strip() or None
    if parent:
        version = next_knowledge_version(parent, user_id)
        knowledge.setdefault("metadata", {})
        if isinstance(knowledge["metadata"], dict):
            knowledge["metadata"]["parent_response_id"] = parent
            knowledge["metadata"]["knowledge_version"] = version

    result["knowledge"] = {
        "summary": knowledge.get("summary"),
        "key_points": knowledge.get("key_points"),
        "formulas": knowledge.get("formulas"),
        "knowledge_version": version,
    }
    # Reuse existing response_id on cache hit when present
    existing_id = result.get("response_id")
    if existing_id:
        _attach_session(
            user_id=user_id,
            query=query,
            answer=answer,
            result=result,
            response_id=str(existing_id),
            session_id=session_id,
            parent_response_id=parent,
        )
        return result
    rid = persist_home_ai_response(
        user_id=user_id,
        query=query,
        answer=answer,
        knowledge_json=knowledge,
        visual_payload=visual_payload if isinstance(visual_payload, dict) else None,
        answer_source=result.get("answer_source"),
        confidence=result.get("confidence"),
        conversation_language=result.get("conversation_language"),
        lecture_id=lecture_id,
        parent_response_id=parent,
        knowledge_version=version,
    )
    if rid:
        result["response_id"] = rid
        result["knowledge_version"] = version
        if parent:
            mark_tools_stale_for_response(parent, user_id)
            result["parent_response_id"] = parent
            result["tools_stale_on_parent"] = True
        _attach_session(
            user_id=user_id,
            query=query,
            answer=answer,
            result=result,
            response_id=rid,
            session_id=session_id,
            parent_response_id=parent,
        )
    return result

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

_SUGGESTED_Q_RE = re.compile(
    r"<<SUGGESTED_QUESTIONS>>\s*(\[.*?\])\s*<<END_SUGGESTED_QUESTIONS>>",
    re.DOTALL,
)


def _extract_suggested_questions(raw_answer: str) -> tuple[str, list[str]]:
    """Pulls the <<SUGGESTED_QUESTIONS>> marker block out of the raw answer.
    Returns (cleaned_answer, questions_list)."""
    match = _SUGGESTED_Q_RE.search(raw_answer)
    if not match:
        return raw_answer, []
    cleaned = raw_answer[: match.start()] + raw_answer[match.end():]
    try:
        parsed = json.loads(match.group(1))
        questions = [str(q).strip() for q in parsed if str(q).strip()][:3]
    except Exception:
        questions = []
    return cleaned.strip(), questions

_PRACTICE_Q_RE = re.compile(
    r"<<PRACTICE_QUESTION>>\s*(\".*?\")\s*<<END_PRACTICE_QUESTION>>",
    re.DOTALL,
)


def _extract_practice_question(raw_answer: str) -> tuple[str, str | None]:
    """Pulls the <<PRACTICE_QUESTION>> marker block out of the raw answer.
    Returns (cleaned_answer, question_or_none)."""
    match = _PRACTICE_Q_RE.search(raw_answer)
    if not match:
        return raw_answer, None
    cleaned = raw_answer[: match.start()] + raw_answer[match.end():]
    try:
        parsed = json.loads(match.group(1))
        question = str(parsed).strip() or None
    except Exception:
        question = None
    return cleaned.strip(), question
class HomeAiError(Exception):
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        *,
        result_status: str | None = None,
        detail: dict | None = None,
    ):
        self.status_code = status_code
        self.result_status = result_status or http_status_to_ai_status(status_code)
        self.detail = detail
        super().__init__(message)


_HOME_SYSTEM = (
    """# Sonaxia Home AI - Retrieval & Generation Rules

You are Sonaxia AI — an education learning tutor and knowledge helper.
You are a smart, professional AI Study Coach.

You are an AI Study Coach.

Your job is NOT just answering questions.

Your job is helping students learn, revise, practice and score better.

For every question: first understand what the student is REALLY asking
(target the actual question, not just keywords), think it through
properly, then guide them to the answer step by step — don't jump to a
final answer without making sure the reasoning is sound and the student
can follow it.

You are NOT a general-purpose chatbot.

==================================================
ALLOWED TOPICS (education & learning — broad)
==================================================

Anything genuinely educational or skill-learning: school/college subjects,
competitive & entrance exams (UPSC, NEET, JEE, etc.), maths, science, history,
geography, economics, CS, aptitude, reasoning, study techniques, career
guidance, exam prep, practice questions, education-related current affairs —
AND learning ANY language (English, Turkish, Bengali, French, Spanish,
Japanese, or any other language a student wants to learn), coding, or any
other legitimate skill someone wants to study or practice.

If a student says "I want to learn X" (a language, a skill, a subject),
teach it — do not refuse just because it isn't a school subject.

==================================================
NOT ALLOWED
==================================================

Love advice, dating, politics debates, religion debates, entertainment gossip,
celebrity news, crypto/stocks, gambling, lottery, adult content, casual non-study chat.

If unrelated, reply exactly:
"I'm Sonaxia AI. I can only help with education, study materials, exam preparation, and academic questions."

==================================================
SEARCH PRIORITY
==================================================

Always retrieve information in this exact order.

Priority 1
Current User RAG Memory
(Search previously generated study materials if available — provided in the user message as "Priority 1 RAG context" when an open lecture is attached)

↓

Priority 2
PYQ Database

↓

Priority 3
Subject Knowledge Base

↓

Priority 4
Trusted Web Search (Only if no reliable answer exists)

Never skip this order.

==================================================
RAG RULE
==================================================

If relevant information exists inside the RAG context provided,

always use RAG first.

Never perform web search before checking RAG.

==================================================
PYQ RULE
==================================================

Do NOT invent PYQ citations from memory.
Include a Related PYQ section ONLY when the user message contains
VERIFIED PYQ MATCHES — and use ONLY those metadata tags
(e.g. Related: NEET 2024). Never quote original exam question text.
If VERIFIED PYQ: none — omit Related PYQ entirely (do not say "no match").

==================================================
KNOWLEDGE BASE
==================================================

If RAG and PYQ cannot answer,

search the internal subject knowledge base.

Use this before using Web Search.

==================================================
WEB SEARCH
==================================================

Use Trusted Web Search ONLY IF

- RAG returns nothing

AND

- PYQ returns nothing

AND

- Knowledge Base returns nothing

OR

The student asks about

Latest

Recent

Current

Today's

News

Scholarships

Admissions

Notifications

Government updates

New discoveries

Current affairs

Otherwise,

never perform Web Search.

==================================================
ANSWER SOURCE
==================================================

Always display where the answer came from.

Examples

📄 RAG Notes

📚 PYQ Database

📖 Knowledge Base

🌐 Web Search

Or combinations when multiple real sources were used.

For this product build, honest labels only:
- 📄 RAG Notes — only if Priority 1 RAG context was provided AND you used it
- Internal Education Knowledge — when answering from your education knowledge (stand-in while Subject Knowledge Base is offline)
- Never claim 📚 PYQ / 📖 Knowledge Base / 🌐 Web Search unless that system actually ran (they do not in this build)

==================================================
LEARNING MODE
==================================================

Do NOT list "Suggested Study Actions" inside the answer body.
The Sonaxia app already shows study-action chips under the reply.
Save tokens for the answer + required <<VISUAL_JSON>> block when asked.

"""
    + ANSWER_INTELLIGENCE_BLOCK
    + """
==================================================
COMPACT FIRST RESPONSE (Phase 4C)
==================================================

Students expand via chips (Flashcards, Quiz, Mind Map, etc.).
Keep the first reply compact — roughly 20–30% of a long essay — unless
the student clearly asked for a long/detailed exam answer.

OMIT RULE (HARD): Never invent filler sections or "N/A" headers.

FORMATTING FOR READABILITY (choose the form that fits the actual answer):
- Do not use a fixed template, repeated header sequence, or bold-term list by
    default. The subject and the learner's question must drive the structure.
- Use headers, bullets, or numbering only when there are genuinely distinct
    parts, enumerable steps, alternatives, or items to compare. A short answer
    should simply read as natural prose.
- Math often works best as flowing step-by-step explanation with the formula
    itself carrying the visual structure; do not force one bullet per term.
- History and narrative topics usually work best as connected paragraphs that
    explain sequence, cause, and context; do not force a bold bullet list.
- Definitions, comparisons, procedures, and multiple answers may use bullets,
    numbering, or a small table when that genuinely improves scanning.
- Vary openings and structure across subjects. Two different topics should not
    look like the same template with different words.
- Use **bold** sparingly for a genuinely important term or number, not as a
    mechanical prefix on every list item.

Fixed section labels (Direct Answer · Easy Explanation · Key Points ·
Important Formula · Related PYQ · Source · Exam Tip) are for
long/detailed exam-style answers only — use headers that match the
actual content instead for normal explanatory answers.

If user message says VERIFIED PYQ: none — never mention PYQs or official
exam years; do not write that no PYQ was found.

Do NOT dump multi-page notes. Do NOT add Suggested Study Actions.

==================================================
RESPONSE STYLE — CRITICAL
==================================================

Prefer natural structure over a fixed checklist.
Do not force the same shape on every reply.

NEVER default to the same opening pattern every time (e.g. always
starting with a definition, always starting with "So,", always starting
the same way). Look at the conversation history above — if you already
answered in a certain style/opening recently, deliberately use a
DIFFERENT approach this time: start with the answer directly, or with
a quick example, or with a short contrasting statement — whatever fits
this specific question best.

Vary sentence length and rhythm like a real person talking — not every
answer needs the same paragraph shape or bullet structure. Two answers
in the same conversation should never read like they came from a
template, even if the subject is similar.

==================================================
FRIENDLY CHECK-IN (when explaining a concept)
==================================================

If the student's question was an "explain" / "samjhao" / "why does this
work" type doubt (not a quick factual lookup, not a chip-generated
flashcards/quiz), end your answer with ONE short, warm check-in question —
like a good teacher would — asking if it made sense or if they want it
explained a different way.

CRITICAL — vary the wording every time. Never reuse the same sentence
twice in a row for the same student. Generate a fresh, natural check-in
each time — do not copy any example below verbatim.

Match the CURRENT conversation language exactly (the same language you
just answered in — English, Hindi, Hinglish, Bengali, or whichever
language is locked for this conversation). If the answer was in Bengali,
the check-in must also be in Bengali — not English, not Hindi.

Style references only (do NOT copy these words — write your own each time):
- casual check on understanding
- offer a different angle / simpler example
- occasionally ask which specific part felt unclear

Skip this check-in for quick factual answers, definitions, or chip-generated
content — only use it for real explanatory doubts.

==================================================
SUGGESTED FOLLOW-UP QUESTIONS (machine-readable)
==================================================

After your answer (and after the check-in line, if you added one), output
2-3 short natural follow-up questions the student might want to ask next
about THIS topic. Wrap them EXACTLY like this, nothing else inside the
markers:

<<SUGGESTED_QUESTIONS>>
["question one", "question two", "question three"]
<<END_SUGGESTED_QUESTIONS>>

Rules:
- Include this block for every answer (except the "topic not allowed"
  refusal message).
- Questions in the SAME language as your answer.
- Each question under 12 words.
- Must be valid JSON array syntax — nothing else inside the markers.
# NAYA — yeh naya section iske turant baad add karo:
==================================================
PRACTICE CHECK QUESTION (teacher-style, machine-readable)
==================================================

If your answer was an EXPLANATION of a concept (not a quick fact, not a
judging/grading turn, not chip-generated content), also output ONE short
practice question that tests whether the student understood what you just
explained — like a teacher checking understanding. Wrap it EXACTLY like
this:

<<PRACTICE_QUESTION>>
"one short question testing the concept just explained"
<<END_PRACTICE_QUESTION>>

Rules:
- Only include this for genuine concept explanations — skip it for quick
  facts, definitions, chip-generated content, or when you are judging a
  student's practice answer (see JUDGING MODE below).
- Same language as your answer.
- Must be a single JSON string (with quotes) — nothing else inside markers.
- If not applicable, omit this block entirely.

==================================================
JUDGING MODE (when a student submits a practice answer)
==================================================

If the user message is wrapped as a PRACTICE ANSWER CHECK (it will say so
explicitly with the original question, the concept context, and the
student's answer), do NOT re-explain the whole topic and do NOT re-teach
generically. Instead, act like a good teacher checking one answer:
- If correct: 1-2 short encouraging sentences. No essay.
- If wrong or incomplete: point out specifically what's missing or wrong,
  then re-explain THAT SPECIFIC part in a different way (different
  example/angle than before) so it clicks — keep it focused, not a full
  restart.
- Do NOT include another <<PRACTICE_QUESTION>> block on a judging turn.
- Still include <<SUGGESTED_QUESTIONS>> as normal.
==================================================
SMART REASONING RULE (avoid generic answers)
==================================================

Before answering, silently think through:
1. What is the student REALLY confused about — the surface question,
   or a deeper concept behind it?
2. What is the SIMPLEST correct explanation a topper would give —
   not a textbook copy-paste, not a vague summary.
3. Would a smart human tutor add ONE sharp example, analogy, or
   distinction that makes this click? If yes, include it.

Never give a shallow one-line answer to a real doubt. Never pad a
simple question with unnecessary long text either. Match depth to
the actual difficulty of the question.

Banned generic phrases — never use filler like:
"It depends on various factors", "There are many aspects to consider",
"This is an important topic", or restating the question back to the
student before answering.

Go straight to the insight.

==================================================
PROFESSIONAL, GEN-Z-INSPIRING TONE
==================================================

Sound like the sharpest, coolest senior/mentor in college — someone
students actually want to learn from. Confident, warm, precise, and
a little energetic — never robotic, never over-eager, never fake-hype.

Do:
- Be direct and encouraging. Make the student feel "okay, I actually
  get this now" — not lectured at.
- Use crisp, modern phrasing. Short sentences beat long-winded ones.
- It is fine to sound motivating in a genuine way (e.g. tying a concept
  to why it matters for their exam or real understanding) — but only
  when it fits naturally, never forced onto every single reply.

Don't:
- No excessive emojis, no "Great question!" openers, no apologizing
  before answering.
- No slang that undermines credibility (this is a study coach, not a
  meme page) — cool and professional, not childish.
- No throat-clearing. State the answer, then briefly show why.

"""
    + typo_intent_rule_block()
    + """
==================================================
LANGUAGE RULE — CHATGPT-STYLE (Qwen3 multilingual)
==================================================

Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

- Always answer in the SAME language / chat style as the student (India or world).
  Example: English notes + Hinglish question → Hinglish answer.
  Example: English notes + Marathi question → Marathi answer.
- If conversation is LOCKED (Hindi, Bengali, Hinglish, ENGLISH, or MATCH_QUESTION),
  keep that across turns until the student explicitly switches (workspace memory).
- Explicit switch wins: "I want Hinglish" / "answer in English" /
  "Hindi mein batao" / "Marathi mein" /
  "answer in Bengali|Tamil|Spanish|French|Arabic|…" → switch.
- Devanagari → Hindi (or Marathi if the question is Marathi). Bengali script → Bengali.
- Latin Hinglish chat → HINGLISH. Other scripts / Latin world languages → MATCH_QUESTION.

ANTI-LEAK (mandatory):
- NEVER switch language only because Priority 1 RAG / notes are in another language.
- If notes are Khmer/Thai/wrong language, still answer in the student's language.
- If the student asked in English (or locked ENGLISH), explain source material IN ENGLISH.

Same credits — NOT the separate Translate (8 cr) product.

==================================================
LANGUAGE-LEARNING EXCEPTION
==================================================

If the student is asking to LEARN a specific language (e.g. "mujhe English
sikhna hai", "I want to learn Turkish"), that target language is the SUBJECT
being taught — it is NOT the answer language.
Keep explaining/teaching in the student's own conversation language
(Hindi, Bengali, Hinglish, etc.) as usual, using short example phrases
in the target language where useful. Keep it a short, practical
conversation — a few sentences or a small starter lesson, not a long essay
— and invite them to continue if they want more.
==================================================
TONE — EMOTIONAL SAFETY ("No Fear" learning space)
==================================================

Be encouraging and patient. Never sound impatient, sarcastic, or dismissive.

Never judge or shame a student for a "silly" question, a wrong guess, or
not knowing something basic — treat every question as valid.

If a student made a mistake or misunderstood something, correct it gently:
acknowledge what they got right first (if anything), then clarify —
don't just say "wrong" or "no".

If a student sounds frustrated, confused, or anxious (e.g. "I don't
understand anything", "I'm going to fail", "this is too hard"), briefly
acknowledge that feeling in one short line before answering — then keep
the actual explanation calm, clear, and reassuring.

Never use discouraging language ("obviously", "everyone knows this",
"you should already know"). Assume the student is doing their best.

Stay warm but stay focused — this is tutoring, not therapy. One short
reassuring line is enough; don't over-explain feelings.

==================================================
STRICT RULES
==================================================

Never hallucinate.

Never invent PYQs.

Never invent facts.

Never claim RAG found information if it did not.

Never use Web Search if local information is sufficient.

==================================================
STRICT RULES
==================================================

Never hallucinate.

Never invent PYQs.

Never invent facts.

Never claim RAG found information if it did not.

Never use Web Search if local information is sufficient.

Always minimize API cost by preferring:

RAG

↓

PYQ

↓

Knowledge Base

↓

Web Search

==================================================
PYQ COPYRIGHT POLICY
==================================================

Never reproduce full copyrighted examination questions or answer keys unless the application has explicit rights to display them.

If a user asks about a topic,

display only metadata such as:

- Exam Name
- Exam Year
- Subject
- Chapter
- Difficulty
- Marks
- Similarity Score

Example

Related PYQs

- NEET 2024

- NEET 2022

- JEE Main 2023

Do NOT display the original question text.

--------------------------------------------------

If the user requests an exact PYQ,

do not reproduce it.

Instead,

state that a related PYQ exists,

then generate a NEW original practice question that tests the same concept.

--------------------------------------------------

Never copy textbook paragraphs verbatim.

Always explain concepts in original words.

Summarize instead of copying.

Generate original examples.

Generate original practice questions.

Generate original MCQs.

Generate original revision notes.

==================================================
RUNTIME HONESTY (this build — mandatory)
==================================================

- Priority 1 RAG — ONLY the "Priority 1 RAG context" block in the user message (open lecture). If that block is missing or empty, do not invent RAG findings.

- PYQ — cite ONLY when user message has VERIFIED PYQ MATCHES (metadata tags). Otherwise omit Related PYQ entirely; do not say bank unavailable or no match found in the answer body. You may still generate NEW original practice questions (clearly labeled practice). Never paste copyrighted exam paper text.

- Subject Knowledge Base — NOT connected as a separate DB. Use Internal Education Knowledge and label Source accordingly (not 📖 Knowledge Base).

- Trusted Web Search (Tavily) — LIVE only via web_deferred route after RAG+PYQ
  empty AND current-affairs classifier YES. Never for syllabus/conceptual doubts.
  Only claim web search when user message includes LIVE WEB SEARCH context.
  If that block is missing, never invent a web search. Prefer honesty:
  "I don't have reliable current information — please check an official source."
  Web answers cost more credits; label Source as Trusted Web Search.

==================================================
MISSION
==================================================

Your objective is to give the best educational answer with the lowest possible cost while helping students learn effectively.

==================================================
ANSWER TYPE DETECTION — FORMAT ACCORDINGLY
==================================================

Silently detect what type of question this is, then pick the right format.
Do NOT write the type label in the answer.

Math / Physics (formula, equation, numerical, solve, calculate, find the value):
  → Direct answer first, then formula/law clearly stated.
  → Numbered steps for numerical — show working, final answer with units.
  → Use highlight_boxes (kind: "important") for the core formula or rule.
  → No generic paragraph intro — go straight to the math.

Concept explanation (Biology, History, Polity, Geography, Economics, Chemistry):
  → Natural tutor prose — headers ONLY for multi-part answers with 3+ distinct parts.
  → Use highlight_boxes (kind: "exam_favourite") for ONE genuinely key fact or term.
  → 20–30% of a full essay by default; go deeper only if student asked for detail.

Exam-pattern (MCQ, "1 mark", "2 marks", PYQ-style, short answer):
  → Direct answer first (1–2 lines). Brief reasoning. No long theory block.
  → Use highlight_boxes (kind: "shortcut") for the exam trick if there is one.

Photo / Diagram based (when image context or diagram is mentioned):
  → Focus ONLY on what is visible/shown — no generic topic intro.
  → Answer the actual question about the image directly.

"KAM BOLO, ZAROORI BOLO" RULE (HARD — always):
  → 1-sentence factual question → answer in ≤ 3 sentences. No headers.
  → Never pad a simple answer into a multi-section essay.
  → Never add ## headers for a question that deserves one paragraph.
  → highlight_boxes: use ONLY when there is genuinely a formula/key-term/trick
    that deserves to stand out — NOT in every answer by default.

"""
    + ASK_AI_VISUAL_EXTENSION
)


async def _retrieve_open_lecture_context(
    user_id: str,
    lecture_id: str,
    query: str,
    timer: PerformanceTimer | None = None,
) -> tuple[list[str], list[dict]]:
    """Priority 1 open lecture + weighted other-lecture RAG (same as Workspace Ask)."""
    try:
        return await _retrieve_lecture_rag(user_id, lecture_id, query, timer=timer)
    except AskAiError as e:
        raise HomeAiError(
            str(e), status_code=e.status_code, result_status=e.result_status
        ) from e
    except RagIndexError as e:
        raise HomeAiError(str(e), status_code=e.status_code) from e
    except EmbeddingError as e:
        raise HomeAiError(str(e), status_code=502) from e


def _build_user_message(
    query: str,
    context_blocks: list[str] | None,
    *,
    conversation_language: str | None = None,
    mode: str = "normal",
    pyq_matches: list | None = None,
    used_web_search: bool = False,
    web_deferred_no_web: bool = False,
    history: list[dict[str, str]] | None = None,
) -> str:
    lang_line = language_hint_user_line(
        query, conversation_language=conversation_language
    )
    speed_line = answer_length_user_line(query, mode)
    speed_suffix = f"\n{speed_line}" if speed_line else ""
    visual_line = visual_reminder_user_line(query)
    pyq_block = format_verified_pyq_block(pyq_matches)
    subj_hint = subject_teaching_hint(query)
    subj_line = f"{subj_hint}\n\n" if subj_hint else ""
    if used_web_search and context_blocks:
        context = "\n\n---\n\n".join(context_blocks)
        return (
            "LIVE WEB SEARCH context (Tavily — current events last resort). "
            "This is NOT from the student's lecture notes or PYQ bank.\n\n"
            f"{context}\n\n"
            "---\n"
            f"{pyq_block}\n\n"
            f"{subj_line}"
            f"Student question: {query}\n\n"
            f"{lang_line}\n"
            "Answer using the web context when it clearly helps. "
            "Label Source as Trusted Web Search / Live web. "
            "If web snippets are unclear or conflicting, say you don't have "
            "reliable information and suggest checking an official current source. "
            "Do not pretend this came from notes or PYQ.\n"
            "Do not list Suggested Study Actions in the answer body.\n"
            f"{visual_line}{speed_suffix}"
        )
    if context_blocks:
        context = "\n\n---\n\n".join(context_blocks)
        return (
            "Priority 1 RAG context from the student's open lecture "
            "(use FIRST if relevant):\n\n"
            f"{context}\n\n"
            "---\n"
            f"{pyq_block}\n\n"
            f"{subj_line}"
            f"Student question: {query}\n\n"
            f"{lang_line}\n"
            "Answer language MUST match the resolved answer language "
            "(conversation lock / question — not the language of notes/RAG).\n"
            "If this RAG context answers the question, prefer it and set "
            "Source to 📄 RAG Notes.\n"
            "If it is empty or irrelevant, answer from Internal Education "
            "Knowledge and label Source honestly.\n"
            "Never claim Knowledge Base / Web Search ran unless a LIVE WEB "
            "SEARCH context block is present.\n"
            "Do not list Suggested Study Actions in the answer body.\n"
            f"{visual_line}{speed_suffix}"
        )
    honest_web = ""
    if web_deferred_no_web:
        honest_web = (
            "This looked like a current-events question, but live web search "
            "did not return a clear usable result (or was not allowed). "
            "Do NOT invent news, dates, or appointments. "
            "Say you don't have reliable current information and suggest "
            "checking an official / trusted current source.\n"
        )
    return (
        f"{pyq_block}\n\n"
        f"{subj_line}"
        f"Student question: {query}\n\n"
        f"{lang_line}\n"
        f"{honest_web}"
        "(No open-lecture RAG context was attached. Priority 1 RAG is empty "
        "for this turn. Answer from Internal Education Knowledge only if this "
        "is a syllabus/concept question — not live news. "
        "Never claim Knowledge Base / Web Search ran unless LIVE WEB SEARCH "
        "context was provided. "
        "Do not list Suggested Study Actions in the answer body.)\n"
        f"{visual_line}{speed_suffix}"
    )


async def _generate_home_answer(
    query: str,
    mode: str,
    *,
    context_blocks: list[str] | None = None,
    conversation_language: str | None = None,
    pyq_matches: list | None = None,
    used_web_search: bool = False,
    web_deferred_no_web: bool = False,
    history: list[dict[str, str]] | None = None,
    text_model: str = "qwen3",
) -> str:
    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.45 if mode == "deep" else 0.65
    chat_messages = [{"role": "system", "content": _HOME_SYSTEM}]
    if history:
        chat_messages.extend(history)
    chat_messages.append(
        {
            "role": "user",
            "content": _build_user_message(
                query,
                context_blocks,
                conversation_language=conversation_language,
                mode=mode,
                pyq_matches=pyq_matches,
                used_web_search=used_web_search,
                web_deferred_no_web=web_deferred_no_web,
            ),
        }
    )

    if text_model != "qwen3":
        from app.services.english_practice_service import _call_chat_model

        return await _call_chat_model(chat_messages, text_model)

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
                    "messages": chat_messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                },
                timeout=90.0,
            )
            
    except httpx.TimeoutException as e:
        raise HomeAiError(
            "Home AI timed out.",
            status_code=504,
            result_status=TIMEOUT,
        ) from e
    except httpx.RequestError as e:
        raise HomeAiError(
            f"Home AI network error: {e}",
            status_code=502,
            result_status=NETWORK_ERROR,
        ) from e

    if response.status_code != 200:
        raise HomeAiError(
            f"Home AI (OpenRouter) failed: {response.status_code} {response.text[:300]}",
            status_code=502,
            result_status=API_ERROR,
        )

    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        raise HomeAiError(
            "Home AI returned no choices.",
            status_code=502,
            result_status=API_ERROR,
        )
    content = (choices[0].get("message") or {}).get("content") or ""
    if not content.strip():
        raise HomeAiError(
            "Home AI returned an empty answer.",
            status_code=502,
            result_status=API_ERROR,
        )
    return content.strip()


async def home_ai(
    user_id: str,
    query: str,
    mode: str = "normal",
    *,
    lecture_id: str | None = None,
    conversation_language: str | None = None,
    study_chip: str | None = None,
    parent_response_id: str | None = None,
    session_id: str | None = None,
    charge_credits: bool = True,
    text_model: str = "qwen3",
) -> dict:
    timer = PerformanceTimer("home_ai")
    timer.start("validation")
    query = (query or "").strip()
    if not query:
        raise HomeAiError("Question is empty.", status_code=400)
    if mode not in ("normal", "deep"):
        raise HomeAiError("mode must be 'normal' or 'deep'.", status_code=400)
    if text_model not in {"qwen3", "gemini", "claude"}:
        text_model = "qwen3"
    if text_model == "claude":
        
        try:
            require_feature_unlocked(user_id, GatedFeature.PREMIUM_CHAT_MODEL)
        except Exception as error:
            raise HomeAiError(str(error), status_code=403) from error

    try:
        require_feature_unlocked(user_id, GatedFeature.ASK_AI)
    except FeatureLockedError as e:
        raise HomeAiError(
            str(e),
            status_code=403,
            result_status="FEATURE_LOCKED",
            detail=feature_locked_payload(e),
        ) from e

    lid = (lecture_id or "").strip() or None
    parent = (parent_response_id or "").strip() or None
    sid = (session_id or "").strip() or None
    # Follow-up that needs new knowledge must not reuse semantic cache.
    force_new = bool(parent) or looks_like_knowledge_follow_up(query)
    if force_new and not parent:
        # Soft follow-up without client parent — still generate fresh (no semantic hit).
        pass
    route = route_home_question(query, lid)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lid,
        conversation_language=conversation_language,
        feature="home_ai",
        study_chip=study_chip,
    )
    cached = None if force_new else get_cached_answer(cache_key)
    timer.end("validation")
    # Never replay a cached answer that omitted a required visual,
    # or that stored the old fake placeholder diagram.
    if cached and wants_visual(query):
        vp = cached.get("visual_payload")
        if not vp or _is_placeholder_visual(vp):
            cached = None
    if cached:
        timer.set(cache_hit=True)
        balance = _credits_balance(user_id)
        timer.log()
        out = {
            **cached,
            "status": SUCCESS,
            "credits_charged": 0,
            "new_balance": balance,
            "cache_hit": True,
        }
        # Always finalize: backfill response_id if missing + attach Study Session.
        out = _finalize_home_result(
            user_id=user_id,
            query=query,
            answer=(out.get("answer") or "").strip(),
            result=out,
            lecture_id=lid,
            parent_response_id=parent,
            session_id=sid,
        )
        if out.get("response_id") and not cached.get("response_id"):
            set_cached_answer(
                cache_key,
                {
                    **cached,
                    "response_id": out["response_id"],
                    "knowledge": out.get("knowledge"),
                    "session_id": out.get("session_id"),
                    "_user_id": user_id,
                    "_query": query,
                    "_feature": "home_ai",
                },
            )
        return out

    # Precheck web band when route is web_deferred (Tavily may fire).
    amount = home_ai_cost_for_study_chip(
        study_chip, mode, used_web_search=(route == "web_deferred")
    )

    def _precheck_sync() -> None:
        if not charge_credits:
            return
        balance = _credits_balance(user_id)
        if balance < amount:
            raise HomeAiError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    if charge_credits:
        timer.start("pre_llm")
        await asyncio.to_thread(_precheck_sync)
        timer.end("pre_llm")

    resolved_lang = resolve_answer_language(query, conversation_language)

    # PYQ match on answer path only inside Tavily gate (not for every Home ask).
    from app.services.pyq_retrieve import match_pyqs_for_query
    pyq_matches = await match_pyqs_for_query(query)

    context_blocks: list[str] | None = None
    sources_meta: list[dict] = []
    if lid and should_run_rag(route):
        context_blocks, sources_meta = await _retrieve_open_lecture_context(
            user_id, lid, query, timer=timer
        )
        if not context_blocks:
            context_blocks = None
            sources_meta = []
    else:
        timer.set(rag_skipped=True)

    used_web_search = False
    web_deferred_no_web = False
    if route == "web_deferred":
        gate = await try_tavily_fallback(
            query=query,
            route=route,
            sources_meta=sources_meta,
            context_blocks=context_blocks,
            feature="home_ai",
        )
        if gate.used:
            used_web_search = True
            context_blocks = gate.context_blocks
            sources_meta = gate.sources_meta
            answer_source = WEB
            confidence = MEDIUM
            amount = home_ai_cost_for_study_chip(
                study_chip, mode, used_web_search=True
            )
        else:
            web_deferred_no_web = True
            answer_source = derive_home_ai_source(sources_meta, context_blocks)
            if answer_source != "RAG":
                answer_source = NO_MATCH
            confidence = derive_home_ai_confidence(sources_meta, answer_source)
            amount = home_ai_cost_for_study_chip(
                study_chip, mode, used_web_search=False
            )
    else:
        answer_source = derive_home_ai_source(sources_meta, context_blocks)
        confidence = derive_home_ai_confidence(sources_meta, answer_source)
        amount = home_ai_cost_for_study_chip(
            study_chip, mode, used_web_search=False
        )

    history = get_recent_messages(sid, user_id, limit=50) if sid else []

    timer.start("llm")
    raw_answer = await _generate_home_answer(
        query,
        mode,
        context_blocks=context_blocks,
        pyq_matches=pyq_matches,
        conversation_language=conversation_language,
        used_web_search=used_web_search,
        web_deferred_no_web=web_deferred_no_web and not used_web_search,
        history=history,
        text_model=text_model,
    )
    raw_answer, suggested_questions = _extract_suggested_questions(raw_answer)
    raw_answer, practice_question = _extract_practice_question(raw_answer)
    answer, visual_payload = split_answer_and_visual(raw_answer)
    if not wants_visual(query):
        visual_payload = None
    elif visual_payload is None:
        visual_payload = fallback_visual_payload(query, answer)
    timer.end("llm")

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            desc = (
                f"Home AI web search ({mode})"
                if used_web_search
                else f"Home AI ({mode})"
            )
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=desc,
                lecture_id=lid,
                action="ask_ai_web" if used_web_search else "ask_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            raise HomeAiError(str(e), status_code=402) from e

    result = {
        "answer": answer,
        "status": SUCCESS,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "sources": sources_meta,
        "credits_charged": credits_charged,
        "new_balance": new_balance,
        "mode": mode,
        "used_web_search": used_web_search,
    }
    if suggested_questions:
        result["suggested_questions"] = suggested_questions
    if practice_question:
        result["practice_question"] = practice_question
    if used_web_search:
        result["web_search_note"] = (
            "This answer used a live web search (current events). "
            f"It costs {amount} credits — more than a normal Ask from your notes."
        )
    if visual_payload is not None:
        result["visual_payload"] = visual_payload
    result = _finalize_home_result(
        user_id=user_id,
        query=query,
        answer=answer,
        result=result,
        lecture_id=lid,
        parent_response_id=parent,
        session_id=sid,
    )
    set_cached_answer(
        cache_key,
        {
            **result,
            "_user_id": user_id,
            "_query": query,
            "_feature": "home_ai",
        },
    )
    timer.set(cache_hit=False)
    timer.log()
    return result


async def home_ai_stream(
    user_id: str,
    query: str,
    mode: str = "normal",
    *,
    lecture_id: str | None = None,
    conversation_language: str | None = None,
    study_chip: str | None = None,
    parent_response_id: str | None = None,
    session_id: str | None = None,
    charge_credits: bool = True,
    text_model: str = "qwen3",
):
    """Async generator of SSE event dicts. Does not alter home_ai() JSON path."""
    timer = PerformanceTimer("home_ai_stream")
    timer.start("validation")
    query = (query or "").strip()
    if not query:
        yield {
            "type": "error",
            "status": "VALIDATION_ERROR",
            "message": "Question is empty.",
        }
        return
    if mode not in ("normal", "deep"):
        yield {
            "type": "error",
            "status": "VALIDATION_ERROR",
            "message": "mode must be 'normal' or 'deep'.",
        }
        return
    if text_model not in {"qwen3", "gemini", "claude"}:
        text_model = "qwen3"
    if text_model == "claude":
        
        try:
            require_feature_unlocked(user_id, GatedFeature.PREMIUM_CHAT_MODEL)
        except Exception as error:
            yield {"type": "error", "status": "FEATURE_LOCKED", "message": str(error)}
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

    lid = (lecture_id or "").strip() or None
    parent = (parent_response_id or "").strip() or None
    sid = (session_id or "").strip() or None
    force_new = bool(parent) or looks_like_knowledge_follow_up(query)
    route = route_home_question(query, lid)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lid,
        conversation_language=conversation_language,
        feature="home_ai",
        study_chip=study_chip,
    )
    cached = None if force_new else get_cached_answer(cache_key)
    timer.end("validation")
    # Never replay a cached answer that omitted a required visual,
    # or that stored the old fake placeholder diagram.
    if cached and wants_visual(query):
        vp = cached.get("visual_payload")
        if not vp or _is_placeholder_visual(vp):
            cached = None
    if cached:
        answer = (cached.get("answer") or "").strip()
        timer.set(cache_hit=True)
        balance = _credits_balance(user_id)
        cached_out = _finalize_home_result(
            user_id=user_id,
            query=query,
            answer=answer,
            result={**dict(cached), "answer": answer, "credits_charged": 0},
            lecture_id=lid,
            parent_response_id=parent,
            session_id=sid,
        )
        if cached_out.get("response_id") and not cached.get("response_id"):
            set_cached_answer(
                cache_key,
                {
                    **cached,
                    "response_id": cached_out["response_id"],
                    "knowledge": cached_out.get("knowledge"),
                    "session_id": cached_out.get("session_id"),
                    "_user_id": user_id,
                    "_query": query,
                    "_feature": "home_ai",
                },
            )
        yield {
            "type": "meta",
            "answer_source": cached_out.get("answer_source"),
            "confidence": cached_out.get("confidence"),
            "conversation_language": cached_out.get("conversation_language"),
            "mode": mode,
            "cache_hit": True,
            "response_id": cached_out.get("response_id"),
            "session_id": cached_out.get("session_id"),
        }
        for piece in _replay_cached_tokens(answer):
            yield {"type": "token", "text": piece}
        timer.log()
        done_evt = {
            "type": "done",
            "status": SUCCESS,
            "answer": answer,
            "answer_source": cached_out.get("answer_source"),
            "confidence": cached_out.get("confidence"),
            "conversation_language": cached_out.get("conversation_language"),
            "credits_charged": 0,
            "new_balance": balance,
            "mode": mode,
            "cache_hit": True,
            "response_id": cached_out.get("response_id"),
            "session_id": cached_out.get("session_id"),
            "knowledge": cached_out.get("knowledge"),
        }
        if cached_out.get("visual_payload"):
            done_evt["visual_payload"] = cached_out.get("visual_payload")
        yield done_evt
        return

    amount = home_ai_cost_for_study_chip(
        study_chip, mode, used_web_search=(route == "web_deferred")
    )

    def _precheck_sync() -> None:
        if not charge_credits:
            return
        balance = _credits_balance(user_id)
        if balance < amount:
            raise HomeAiError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    try:
        if charge_credits:
            timer.start("pre_llm")
            await asyncio.to_thread(_precheck_sync)
            timer.end("pre_llm")
    except HomeAiError as e:
        yield {
            "type": "error",
            "status": e.result_status,
            "message": str(e),
        }
        return

    resolved_lang = resolve_answer_language(query, conversation_language)

    from app.services.pyq_retrieve import match_pyqs_for_query
    pyq_matches = await match_pyqs_for_query(query)

    context_blocks: list[str] | None = None
    sources_meta: list[dict] = []
    try:
        if lid and should_run_rag(route):
            context_blocks, sources_meta = await _retrieve_open_lecture_context(
                user_id, lid, query, timer=timer
            )
            if not context_blocks:
                context_blocks = None
                sources_meta = []
        else:
            timer.set(rag_skipped=True)
    except HomeAiError as e:
        yield {
            "type": "error",
            "status": e.result_status,
            "message": str(e),
        }
        return

    used_web_search = False
    web_deferred_no_web = False
    if route == "web_deferred":
        gate = await try_tavily_fallback(
            query=query,
            route=route,
            sources_meta=sources_meta,
            context_blocks=context_blocks,
            feature="home_ai_stream",
        )
        if gate.used:
            used_web_search = True
            context_blocks = gate.context_blocks
            sources_meta = gate.sources_meta
            answer_source = WEB
            confidence = MEDIUM
            amount = home_ai_cost_for_study_chip(
                study_chip, mode, used_web_search=True
            )
        else:
            web_deferred_no_web = True
            answer_source = derive_home_ai_source(sources_meta, context_blocks)
            if answer_source != "RAG":
                answer_source = NO_MATCH
            confidence = derive_home_ai_confidence(sources_meta, answer_source)
            amount = home_ai_cost_for_study_chip(
                study_chip, mode, used_web_search=False
            )
    else:
        answer_source = derive_home_ai_source(sources_meta, context_blocks)
        confidence = derive_home_ai_confidence(sources_meta, answer_source)
        amount = home_ai_cost_for_study_chip(
            study_chip, mode, used_web_search=False
        )

        yield {
        "type": "meta",
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "mode": mode,
        "used_web_search": used_web_search,
    }

    history = get_recent_messages(sid, user_id, limit=50) if sid else []

    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.45 if mode == "deep" else 0.65
    messages = [{"role": "system", "content": _HOME_SYSTEM}]
    messages.extend(history)
    messages.append(
        {
            "role": "user",
            "content": _build_user_message(
                query,
                context_blocks,
                conversation_language=conversation_language,
                mode=mode,
                pyq_matches=pyq_matches,
                used_web_search=used_web_search,
                web_deferred_no_web=web_deferred_no_web and not used_web_search,
            ),
        }
    )

    parser = VisualStreamParser()
    try:
        timer.start("llm")
        if text_model == "qwen3":
            model_stream = stream_chat_completions(
                messages,
                temperature=temperature,
                max_tokens=max_tokens,
                model=AIConfig.AI_CHAT_MODEL,
            )
        else:
            from app.services.english_practice_service import _call_chat_model

            async def model_stream():
                yield await _call_chat_model(messages, text_model)

            model_stream = model_stream()

        async for delta in model_stream:
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

    # SAHI:
    answer = parser.answer
    suggested_questions = parser.suggested_questions
    practice_question = parser.practice_question
    visual_payload = parser.visual_payload
    if not wants_visual(query):
        visual_payload = None
    elif visual_payload is None:
        visual_payload = fallback_visual_payload(query, answer)
    if not answer:
        yield {
            "type": "error",
            "status": API_ERROR,
            "message": "Home AI returned an empty answer.",
        }
        return

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            desc = (
                f"Home AI web search ({mode}) — stream"
                if used_web_search
                else f"Home AI ({mode}) — stream"
            )
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=desc,
                lecture_id=lid,
                action="ask_ai_web" if used_web_search else "ask_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            yield {
                "type": "error",
                "status": "VALIDATION_ERROR",
                "message": str(e),
            }
            return

    cache_body = {
        "answer": answer,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "sources": sources_meta,
        "mode": mode,
        "status": SUCCESS,
        "used_web_search": used_web_search,
    }
    if suggested_questions:
        cache_body["suggested_questions"] = suggested_questions
    if practice_question:
        cache_body["practice_question"] = practice_question
    if used_web_search:
        cache_body["web_search_note"] = (
            "This answer used a live web search (current events). "
            f"It costs {amount} credits — more than a normal Ask from your notes."
        )
    if visual_payload is not None:
        cache_body["visual_payload"] = visual_payload
    cache_body = _finalize_home_result(
        user_id=user_id,
        query=query,
        answer=answer,
        result=cache_body,
        lecture_id=lid,
        parent_response_id=parent,
        session_id=sid,
    )
    set_cached_answer(
        cache_key,
        {
            **cache_body,
            "_user_id": user_id,
            "_query": query,
            "_feature": "home_ai",
        },
    )
    timer.set(cache_hit=False)
    timer.log()

    done_evt = {
        "type": "done",
        "status": SUCCESS,
        "answer": answer,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "credits_charged": credits_charged,
        "new_balance": new_balance,
        "mode": mode,
        "used_web_search": used_web_search,
        "response_id": cache_body.get("response_id"),
        "session_id": cache_body.get("session_id"),
        "knowledge": cache_body.get("knowledge"),
        "knowledge_version": cache_body.get("knowledge_version"),
       "parent_response_id": cache_body.get("parent_response_id"),
    }
    if cache_body.get("suggested_questions"):
        done_evt["suggested_questions"] = cache_body.get("suggested_questions")
    if cache_body.get("practice_question"):
        done_evt["practice_question"] = cache_body.get("practice_question")
    if used_web_search:
        done_evt["web_search_note"] = cache_body.get("web_search_note")
    if visual_payload is not None:
        done_evt["visual_payload"] = visual_payload
    yield done_evt
