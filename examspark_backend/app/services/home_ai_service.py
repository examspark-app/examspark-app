"""Home AI — education Study Coach for Home chat.

Retrieval order (product rules): User RAG → PYQ → Knowledge Base → Web.
This build: optional open-lecture RAG (Priority 1) + Internal Education Knowledge.
PYQ / Subject KB / Tavily are NOT connected — honesty block enforces that.

Credits: Ask AI Normal 5 / Deep 12.
Phase 1 perf: smart route, caches, timing (SSE already live).
"""
from __future__ import annotations

import asyncio

import httpx

from app.config import AIConfig
from app.constants.ai_response_status import (
    API_ERROR,
    NETWORK_ERROR,
    SUCCESS,
    TIMEOUT,
    http_status_to_ai_status,
)
from app.constants.ai_speed import brevity_user_line, max_tokens_for_mode
from app.constants.answer_source import (
    derive_home_ai_confidence,
    derive_home_ai_source,
)
from app.constants.credit_costs import ASK_AI_DEEP, ASK_AI_NORMAL
from app.constants.language_hint import (
    language_hint_user_line,
    resolve_answer_language,
    typo_intent_rule_block,
)
from app.services.ai_performance_cache import (
    answer_cache_key,
    get_cached_answer,
    set_cached_answer,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
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
    _credits_balance,
    _replay_cached_tokens,
    _retrieve_lecture_rag,
)
from app.services.rag_index_service import RagIndexError

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


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
    """# ExamSpark Home AI - Retrieval & Generation Rules

You are ExamSpark Home AI.

You are an AI Study Coach.

Your job is NOT just answering questions.

Your job is helping students learn, revise, practice and score better.

You are NOT a general-purpose chatbot.

==================================================
ALLOWED TOPICS (education only)
==================================================

School/college subjects, competitive & entrance exams (UPSC, NEET, JEE, etc.),
maths, science, history, geography, economics, CS, English, aptitude, reasoning,
study techniques, career guidance, exam prep, practice questions, education-related
current affairs.

==================================================
NOT ALLOWED
==================================================

Love advice, dating, politics debates, religion debates, entertainment gossip,
celebrity news, crypto/stocks, gambling, lottery, adult content, casual non-study chat.

If unrelated, reply exactly:
"I'm ExamSpark AI. I can only help with education, study materials, exam preparation, and academic questions."

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

If the topic exists in the PYQ database,

include:

• Similar Previous Year Questions

• Exam Year

• Marks

• Difficulty

• Frequently Asked

If multiple PYQs exist,

rank them by relevance.

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

• RAG returns nothing

AND

• PYQ returns nothing

AND

• Knowledge Base returns nothing

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

After every answer,

suggest useful study actions as NAMES only (do not generate the materials).

Examples

📘 Learn More

🧠 Flashcards

❓ Quiz

📝 PYQs

📄 Revision Sheet

🗺 Mind Map

📌 Cheat Sheet

⚡ 5 Minute Revision

🎯 Important Questions

Generate the actual flashcards/quiz/etc ONLY when the student clicks them later — not in this reply.

==================================================
RESPONSE STYLE
==================================================

Always provide

1. Direct Answer

2. Easy Explanation

3. Key Points

4. Exam Tip

5. Related Topics

6. Source

7. Suggested Study Actions (names only)

==================================================
LANGUAGE RULE (multilingual Q&A) — HARD CONSTRAINTS
==================================================

Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

• If conversation is LOCKED to Hindi or Bengali (see user-message hint), keep that
  language for later turns even when a later question is typed in English letters —
  until the student explicitly switches.
• Explicit switch wins: "I want Hinglish" → natural Hinglish; "answer in English" /
  "Hindi mein batao" / "answer in Bengali" → switch and stay.
• Mostly Latin-script English (no lock) → ENTIRE answer in English ONLY.
• Devanagari Hindi → Hindi ONLY. Bengali script → Bengali ONLY.
• HINGLISH lock → natural Hinglish (Hindi + English mix) as students chat.

ANTI-LEAK (mandatory):
• NEVER switch to Hindi/Bengali because Priority 1 RAG / notes are in those languages.
• If answer language is English, explain Hindi/Bengali source material IN ENGLISH.
• NEVER invent a preference for Hindi for Indian students when the lock/question is English.

Same credits — NOT the separate Translate (8 cr) product.

"""
    + typo_intent_rule_block()
    + """
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

• Exam Name
• Exam Year
• Subject
• Chapter
• Difficulty
• Marks
• Similarity Score

Example

Related PYQs

• NEET 2024

• NEET 2022

• JEE Main 2023

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

• Priority 1 RAG — ONLY the "Priority 1 RAG context" block in the user message (open lecture). If that block is missing or empty, do not invent RAG findings.

• PYQ Database — NOT connected. NEVER invent Exam Year, Marks, Difficulty as official past papers (copyright + honesty). If asked for verified PYQs: say "The PYQ bank is not available in ExamSpark yet." You may still generate NEW original practice questions (clearly labeled practice — not official past papers). Never paste copyrighted exam paper text from memory.

• Subject Knowledge Base — NOT connected as a separate DB. Use Internal Education Knowledge and label Source accordingly (not 📖 Knowledge Base).

• Trusted Web Search (Tavily) — NOT connected. NEVER claim you searched the web. For latest official notifications / admissions / scholarships that need live data: say "Live web search is not connected yet in ExamSpark."

==================================================
MISSION
==================================================

Your objective is to give the best educational answer with the lowest possible cost while helping students learn effectively.
"""
)


async def _retrieve_open_lecture_context(
    user_id: str,
    lecture_id: str,
    query: str,
    timer: PerformanceTimer | None = None,
) -> tuple[list[str], list[dict]]:
    """Priority 1 — same Notes → transcript path as lecture Ask AI."""
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
) -> str:
    lang_line = language_hint_user_line(
        query, conversation_language=conversation_language
    )
    speed_line = brevity_user_line(mode)
    speed_suffix = f"\n{speed_line}" if speed_line else ""
    if context_blocks:
        context = "\n\n---\n\n".join(context_blocks)
        return (
            "Priority 1 RAG context from the student's open lecture "
            "(use FIRST if relevant):\n\n"
            f"{context}\n\n"
            "---\n"
            f"Student question: {query}\n\n"
            f"{lang_line}\n"
            "Answer language MUST match the resolved answer language "
            "(conversation lock / question — not the language of notes/RAG).\n"
            "If this RAG context answers the question, prefer it and set "
            "Source to 📄 RAG Notes.\n"
            "If it is empty or irrelevant, answer from Internal Education "
            "Knowledge and label Source honestly.\n"
            "Never claim PYQ / Knowledge Base / Web Search ran.\n"
            f"Suggested Study Actions = names only.{speed_suffix}"
        )
    return (
        f"Student question: {query}\n\n"
        f"{lang_line}\n"
        "(No open-lecture RAG context was attached. Priority 1 RAG is empty "
        "for this turn. Answer from Internal Education Knowledge. "
        "Never claim PYQ / Knowledge Base / Web Search ran. "
        f"Suggested Study Actions = names only.){speed_suffix}"
    )


async def _generate_home_answer(
    query: str,
    mode: str,
    *,
    context_blocks: list[str] | None = None,
    conversation_language: str | None = None,
) -> str:
    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.3 if mode == "deep" else 0.4

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
                        {"role": "system", "content": _HOME_SYSTEM},
                        {
                            "role": "user",
                            "content": _build_user_message(
                                query,
                                context_blocks,
                                conversation_language=conversation_language,
                                mode=mode,
                            ),
                        },
                    ],
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
    charge_credits: bool = True,
) -> dict:
    timer = PerformanceTimer("home_ai")
    timer.start("validation")
    query = (query or "").strip()
    if not query:
        raise HomeAiError("Question is empty.", status_code=400)
    if mode not in ("normal", "deep"):
        raise HomeAiError("mode must be 'normal' or 'deep'.", status_code=400)

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
    route = route_home_question(query, lid)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lid,
        conversation_language=conversation_language,
        feature="home_ai",
    )
    cached = get_cached_answer(cache_key)
    timer.end("validation")
    if cached:
        timer.set(cache_hit=True)
        balance = _credits_balance(user_id)
        timer.log()
        return {
            **cached,
            "status": SUCCESS,
            "credits_charged": 0,
            "new_balance": balance,
            "cache_hit": True,
        }

    amount = ASK_AI_DEEP if mode == "deep" else ASK_AI_NORMAL

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

    answer_source = derive_home_ai_source(sources_meta, context_blocks)
    confidence = derive_home_ai_confidence(sources_meta, answer_source)

    timer.start("llm")
    answer = await _generate_home_answer(
        query,
        mode,
        context_blocks=context_blocks,
        conversation_language=conversation_language,
    )
    timer.end("llm")

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Home AI ({mode})",
                lecture_id=lid,
                action="ask_ai",
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
    }
    set_cached_answer(cache_key, result)
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
    charge_credits: bool = True,
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
    route = route_home_question(query, lid)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lid,
        conversation_language=conversation_language,
        feature="home_ai",
    )
    cached = get_cached_answer(cache_key)
    timer.end("validation")
    if cached:
        answer = (cached.get("answer") or "").strip()
        timer.set(cache_hit=True)
        balance = _credits_balance(user_id)
        yield {
            "type": "meta",
            "answer_source": cached.get("answer_source"),
            "confidence": cached.get("confidence"),
            "conversation_language": cached.get("conversation_language"),
            "mode": mode,
            "cache_hit": True,
        }
        for piece in _replay_cached_tokens(answer):
            yield {"type": "token", "text": piece}
        timer.log()
        yield {
            "type": "done",
            "status": SUCCESS,
            "answer": answer,
            "answer_source": cached.get("answer_source"),
            "confidence": cached.get("confidence"),
            "conversation_language": cached.get("conversation_language"),
            "credits_charged": 0,
            "new_balance": balance,
            "mode": mode,
            "cache_hit": True,
        }
        return

    amount = ASK_AI_DEEP if mode == "deep" else ASK_AI_NORMAL

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

    answer_source = derive_home_ai_source(sources_meta, context_blocks)
    confidence = derive_home_ai_confidence(sources_meta, answer_source)

    yield {
        "type": "meta",
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "mode": mode,
    }

    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.3 if mode == "deep" else 0.4
    messages = [
        {"role": "system", "content": _HOME_SYSTEM},
        {
            "role": "user",
            "content": _build_user_message(
                query,
                context_blocks,
                conversation_language=conversation_language,
                mode=mode,
            ),
        },
    ]

    parts: list[str] = []
    try:
        timer.start("llm")
        async for delta in stream_chat_completions(
            messages,
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            parts.append(delta)
            yield {"type": "token", "text": delta}
        timer.end("llm")
    except OpenRouterStreamError as e:
        yield {
            "type": "error",
            "status": e.result_status,
            "message": str(e),
        }
        return

    answer = "".join(parts).strip()
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
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=f"Home AI ({mode}) — stream",
                lecture_id=lid,
                action="ask_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            yield {
                "type": "error",
                "status": "VALIDATION_ERROR",
                "message": str(e),
            }
            return

    set_cached_answer(
        cache_key,
        {
            "answer": answer,
            "answer_source": answer_source,
            "confidence": confidence,
            "conversation_language": resolved_lang,
            "sources": sources_meta,
            "mode": mode,
            "status": SUCCESS,
        },
    )
    timer.set(cache_hit=False)
    timer.log()

    yield {
        "type": "done",
        "status": SUCCESS,
        "answer": answer,
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "credits_charged": credits_charged,
        "new_balance": new_balance,
        "mode": mode,
    }
