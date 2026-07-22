"""Home AI — education Study Coach for Home chat.

Retrieval order: User RAG → PYQ → Internal Knowledge → Web (Tavily last resort).
Tavily only on web_deferred after empty RAG/PYQ + current-affairs classifier.

Credits: Ask AI Normal 5 / Deep 12; Web search 10 / 20.
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
    MEDIUM,
    NO_MATCH,
    WEB,
    derive_home_ai_confidence,
    derive_home_ai_source,
)
from app.constants.credit_costs import home_ai_cost_for_study_chip
from app.constants.language_hint import (
    language_hint_user_line,
    resolve_answer_language,
    typo_intent_rule_block,
)
from app.constants.visual_notes_prompt import ASK_AI_VISUAL_EXTENSION
from app.services.ai_performance_cache import (
    answer_cache_key,
    find_semantic_cached_answer,
    get_cached_answer,
    set_cached_answer,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
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
    _credits_balance,
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
from app.services.home_ai_session_service import ensure_session_for_turn
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

Do NOT list "Suggested Study Actions" inside the answer body.
The ExamSpark app already shows study-action chips under the reply.
Save tokens for the answer + required <<VISUAL_JSON>> block.

==================================================
COMPACT FIRST RESPONSE (Phase 4C — HARD)
==================================================

Students expand via chips (Flashcards, Quiz, Mind Map, etc.).
Your FIRST reply must stay compact — roughly 20–30% of a typical long essay.

OMIT RULE (HARD): If a section is not genuinely relevant, OMIT it entirely.
Do NOT include headers with filler ("not applicable", "N/A", "no formula
applies", "No PYQ found", etc.). A missing section is correct.

Adaptive shapes:
• Shape 1 — simple factual: one short Direct Answer block only — NO forced
  section headers, NO Key Points / Related PYQ / Exam Tip / Source.
  Still write a COMPLETE mini-answer: 2–4 sentences (fact + brief why/how
  or one concrete detail). Never a single bare fact-dump line.
  Example length: "The human heart has four chambers: two atria (upper) and
  two ventricles (lower). The atria receive blood, while the ventricles pump
  it out — this separation keeps oxygenated and deoxygenated blood from mixing."
• Shape 2 — concept AND user message has VERIFIED PYQ MATCHES: Direct Answer
  + short Related PYQ using ONLY those metadata tags (e.g. Related: NEET 2024).
  Never invent years or hedge ("similar to a typical NEET question").
• Shape 3 — deep / exam-prep: Direct Answer + Key Points only if multi-part
  + Related PYQ only if verified matches present + Exam Tip only if non-generic.

When useful (keep header names when included — chips may parse them):
1. Direct Answer (2–4 sentences)
2. Easy Explanation (short paragraph)
3. Key Points (only if non-redundant)
4. Important Formula (only if a real formula is required)
5. Related PYQ (ONLY from verified user-message tags — metadata only)
6. Source (honest line; OMIT on trivial facts if useless)
7. Exam Tip (only if genuinely useful)

If user message says VERIFIED PYQ: none — never mention PYQs or official
exam years; do not write that no PYQ was found.

Do NOT dump every detail or multi-page notes.
Do NOT add Suggested Study Actions.
Prefer clarity over length. Chips will deepen later.

==================================================
RESPONSE STYLE
==================================================

Stay compact. Prefer natural structure over a fixed checklist.
Omit irrelevant sections entirely. Never write "not applicable" under a header.
Do not force the same shape on every reply.

Do NOT add a "Suggested Study Actions" section in the answer text.

==================================================
LANGUAGE RULE — CHATGPT-STYLE (Qwen3 multilingual)
==================================================

Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

• Always answer in the SAME language / chat style as the student (India or world).
  Example: English notes + Hinglish question → Hinglish answer.
  Example: English notes + Marathi question → Marathi answer.
• If conversation is LOCKED (Hindi, Bengali, Hinglish, ENGLISH, or MATCH_QUESTION),
  keep that across turns until the student explicitly switches (workspace memory).
• Explicit switch wins: "I want Hinglish" / "answer in English" /
  "Hindi mein batao" / "Marathi mein" /
  "answer in Bengali|Tamil|Spanish|French|Arabic|…" → switch.
• Devanagari → Hindi (or Marathi if the question is Marathi). Bengali script → Bengali.
• Latin Hinglish chat → HINGLISH. Other scripts / Latin world languages → MATCH_QUESTION.

ANTI-LEAK (mandatory):
• NEVER switch language only because Priority 1 RAG / notes are in another language.
• If notes are Khmer/Thai/wrong language, still answer in the student's language.
• If the student asked in English (or locked ENGLISH), explain source material IN ENGLISH.

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

• PYQ — cite ONLY when user message has VERIFIED PYQ MATCHES (metadata tags). Otherwise omit Related PYQ entirely; do not say bank unavailable or no match found in the answer body. You may still generate NEW original practice questions (clearly labeled practice). Never paste copyrighted exam paper text.

• Subject Knowledge Base — NOT connected as a separate DB. Use Internal Education Knowledge and label Source accordingly (not 📖 Knowledge Base).

• Trusted Web Search (Tavily) — LIVE only via web_deferred route after RAG+PYQ
  empty AND current-affairs classifier YES. Never for syllabus/conceptual doubts.
  Only claim web search when user message includes LIVE WEB SEARCH context.
  If that block is missing, never invent a web search. Prefer honesty:
  "I don't have reliable current information — please check an official source."
  Web answers cost more credits; label Source as Trusted Web Search.

==================================================
MISSION
==================================================

Your objective is to give the best educational answer with the lowest possible cost while helping students learn effectively.
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
) -> str:
    lang_line = language_hint_user_line(
        query, conversation_language=conversation_language
    )
    speed_line = brevity_user_line(mode)
    speed_suffix = f"\n{speed_line}" if speed_line else ""
    visual_line = visual_reminder_user_line(query)
    pyq_block = format_verified_pyq_block(pyq_matches)
    if used_web_search and context_blocks:
        context = "\n\n---\n\n".join(context_blocks)
        return (
            "LIVE WEB SEARCH context (Tavily — current events last resort). "
            "This is NOT from the student's lecture notes or PYQ bank.\n\n"
            f"{context}\n\n"
            "---\n"
            f"{pyq_block}\n\n"
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
                                pyq_matches=pyq_matches,
                                used_web_search=used_web_search,
                                web_deferred_no_web=web_deferred_no_web,
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
    study_chip: str | None = None,
    parent_response_id: str | None = None,
    session_id: str | None = None,
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
    if cached is None and not force_new:
        cached = find_semantic_cached_answer(
            user_id=user_id, query=query, feature="home_ai"
        )
        if cached:
            timer.set(semantic_cache_hit=True)
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
    pyq_matches: list = []

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

    timer.start("llm")
    raw_answer = await _generate_home_answer(
        query,
        mode,
        context_blocks=context_blocks,
        pyq_matches=pyq_matches,
        conversation_language=conversation_language,
        used_web_search=used_web_search,
        web_deferred_no_web=web_deferred_no_web and not used_web_search,
    )
    answer, visual_payload = split_answer_and_visual(raw_answer)
    if visual_payload is None:
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
    if cached is None and not force_new:
        cached = find_semantic_cached_answer(
            user_id=user_id, query=query, feature="home_ai"
        )
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

    pyq_matches: list = []

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
                pyq_matches=pyq_matches,
                used_web_search=used_web_search,
                web_deferred_no_web=web_deferred_no_web and not used_web_search,
            ),
        },
    ]

    parser = VisualStreamParser()
    try:
        timer.start("llm")
        async for delta in stream_chat_completions(
            messages,
            temperature=temperature,
            max_tokens=max_tokens,
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
    visual_payload = parser.visual_payload
    if visual_payload is None:
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
    if used_web_search:
        done_evt["web_search_note"] = cache_body.get("web_search_note")
    if visual_payload is not None:
        done_evt["visual_payload"] = visual_payload
    yield done_evt
