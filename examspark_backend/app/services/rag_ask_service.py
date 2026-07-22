"""Ask AI — retrieve Notes then Clean Transcript, then grounded Qwen answer.

RAG priority: Notes → Clean Transcript. Tavily only on web_deferred after
empty RAG/PYQ + current-affairs classifier (see tavily_gate.py).
Phase 1 perf: top-3 + expand, chunk cap, caches, timing, parallel precheck.
"""
from __future__ import annotations

import asyncio
import logging

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
    derive_ask_ai_source,
    derive_confidence,
)
from app.constants.credit_costs import ask_ai_cost
from app.constants.language_hint import (
    language_hint_user_line,
    resolve_answer_language,
    typo_intent_rule_block,
)
from app.constants.visual_notes_prompt import ASK_AI_VISUAL_EXTENSION
from app.constants.rag_perf import (
    CHUNK_MAX_CHARS,
    EXPAND_SIMILARITY_BELOW,
    MATCH_COUNT_DEFAULT,
    MATCH_COUNT_EXPAND,
)
from app.services.ai_performance_cache import (
    answer_cache_key,
    get_cached_answer,
    set_cached_answer,
)
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.embedding_service import EmbeddingError, embed_query
from app.services.openrouter_stream import OpenRouterStreamError, stream_chat_completions
from app.services.performance_timer import PerformanceTimer
from app.services.pyq_retrieve import format_verified_pyq_block
from app.services.plan_tier_service import (
    FeatureLockedError,
    GatedFeature,
    feature_locked_payload,
    require_feature_unlocked,
)
from app.services.question_router import route_ask_question
from app.services.rag_index_service import RagIndexError, ensure_lecture_indexed
from app.services.r2_storage_service import R2StorageError, R2StorageService
from app.services.supabase_admin import get_supabase_admin
from app.services.visual_fallback import fallback_visual_payload
from app.services.visual_stream_parser import VisualStreamParser, split_answer_and_visual

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
_MIN_NOTES_HITS = 2
_MATCH_COUNT = MATCH_COUNT_DEFAULT
# Soft floor — short factual questions often score lower than 0.5 cosine.
_MATCH_THRESHOLD = 0.20
# If nothing passes the soft floor, still take nearest neighbors (threshold 0).
_FALLBACK_THRESHOLD = 0.0
_FALLBACK_NOTES_CHARS = 6000
# Cross-lecture supplement — stricter so unrelated lectures do not dilute.
_OTHER_LECTURE_THRESHOLD = 0.62
_OTHER_MATCH_COUNT = 3
_MAX_OTHER_BLOCKS = 3


class AskAiError(Exception):
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


_ASK_SYSTEM = (
    """You are ExamSpark AI — an exam preparation assistant ONLY.

You are NOT a general-purpose chatbot. Never behave like ChatGPT.
Your purpose is ONLY to answer education-related questions based on the student's uploaded study materials for this lecture.

====================================================
STRICT RULES
====================================================
- Answer ONLY from the provided lecture context (retrieved notes / summary / key points / terms / clean transcript).
- Never hallucinate. Never invent definitions, PYQ years, exam names, marks, or facts.
- Do NOT guess when context is missing.
- Keep responses concise unless the student asks for detailed / long answers.
- Never repeat the same information. Generate only what the student asks.
- Use retrieved context only.

====================================================
KNOWLEDGE / SEARCH ORDER (this session)
====================================================
Use context in this order when present:
1. Uploaded Notes / Clean Notes
2. Summary
3. Key Points
4. Important Terms
5. Clean Transcript

PYQ Database, Subject Knowledge Base, and Web Search are NOT available in this reply.
- NEVER claim you searched the web.
- NEVER invent or display PYQ year / marks / difficulty unless that exact info is in the lecture context.
- NEVER use web-style knowledge for simple definitions that should come from notes.

Future product order (for awareness only — do not simulate): Notes → Clean Notes → Summary → Key Points → Terms → PYQ DB → Knowledge Base → Web (only if enabled AND all above fail AND user asks for external info).

====================================================
ALLOWED TOPICS
====================================================
Only help with: uploaded notes, subject concepts, exam prep, revision, definitions, formulae, numericals, diagrams, case studies, assignments, school/college subjects, and study intents (explain, short/long answer, difference, examples).
If the student asks for one sample MCQ/flashcard from THIS lecture context only, you may give one grounded sample. For full MCQ/Flashcards/Important Questions decks, redirect to Generate More (not live as full FastAPI yet).

====================================================
REFUSE THESE (non-education)
====================================================
Politely refuse: love letters, jokes, lottery, crypto/stocks, politics, religion debates, relationship advice, coding unrelated to uploaded study material, adult content, entertainment gossip, or any non-study request.

Exact refusal style:
"I'm ExamSpark AI. I can only help with study materials, exam preparation, and education-related questions."

====================================================
LANGUAGE RULE — CHATGPT-STYLE (Qwen3 multilingual)
====================================================
Primary signal = STUDENT QUESTION / conversation lock — NEVER notes/RAG language.

• Always answer in the SAME language / chat style as the student (India or world).
  Example: English notes + Hinglish question → Hinglish answer.
  Example: English notes + Marathi question → Marathi answer.
• If conversation is LOCKED (Hindi, Bengali, Hinglish, ENGLISH, or MATCH_QUESTION),
  keep that across turns until an explicit switch (workspace memory).
• Explicit switch: "I want Hinglish" / "answer in English" / "Hindi mein batao" /
  "Marathi mein" / "answer in Bengali|Tamil|Spanish|French|Arabic|…" → switch.
• Devanagari → Hindi (or Marathi if the question is Marathi). Bengali script → Bengali.
• Latin Hinglish chat → HINGLISH. Other scripts / Latin world languages → match.

ANTI-LEAK (mandatory):
• NEVER switch language only because lecture notes / RAG are in another language.
• If notes are Khmer/Thai/wrong language, still answer in the student's language.
• If the student asked in English (or locked ENGLISH), explain source IN ENGLISH.

Same Ask AI credits — NOT the separate Translate (8 cr) product.
Always keep answers grounded only in the lecture context above.

"""
    + typo_intent_rule_block()
    + """
====================================================
ANSWER FORMAT (adaptive shapes — OMIT irrelevant sections)
====================================================
Stay brief. Students deepen via Study Workspace tools — do not essay-dump.

OMIT RULE (HARD): If a section is not genuinely relevant, OMIT it entirely.
Do NOT keep the header with "not applicable", "N/A", "none", "no formula
applies", "No PYQ found", or similar filler. A missing section is correct.

Adaptive shapes (pick by question type):
• Shape 1 — simple factual doubt from lecture: Direct Answer only — no forced
  extra headers (no Key Points / Related PYQ / Exam Tip). Still complete:
  2–4 sentences (fact + brief why/how or one concrete detail). Never a single
  bare fact line. Example length: "The human heart has four chambers: two
  atria (upper) and two ventricles (lower). The atria receive blood, while
  the ventricles pump it out — this separation keeps oxygenated and
  deoxygenated blood from mixing."
• Shape 2 — concept question AND user message has VERIFIED PYQ MATCHES:
  Direct Answer + short Related PYQ using ONLY those metadata tags
  (e.g. Related: NEET 2024). Never invent years or hedge
  ("similar to a typical NEET question").
• Shape 3 — deep / exam-prep (student asks exam-style help, or clearly
  exam-prep): Direct Answer + Key Points only if multi-part + Related PYQ
  only if verified matches present + Exam Tip only if non-generic.

When useful (and only then), headers you MAY use:
1. Direct Answer
2. Detailed Explanation
3. Key Points
4. Important Terms
5. Example (only if in context)
6. Related PYQ (ONLY from verified user-message tags — metadata only)
7. Exam Tip (study tip only — no fake PYQs)
8. Source — Uploaded Notes | Clean Transcript | (optional) another of your lectures

Context may include high-similarity chunks from your OTHER saved lectures —
prefer the open lecture; only use other-lecture context when it clearly helps.
Never invent content from lectures that are not in the context block.

If user message says VERIFIED PYQ: none — never mention PYQs or official
exam years; do not write that no PYQ was found.

Intents:
- Explain / Easy → beginner language, concise.
- Short Answer → 3–5 lines.
- Long Answer → exam-suitable detail from context.
- Difference → markdown comparison table from context.
- Revision → concise revision from context.
- Examples → only from context.

====================================================
PYQ COPYRIGHT POLICY
====================================================
Never reproduce original examination question text, options, answer keys,
or official explanations.

Cite a Related PYQ section ONLY when the user message includes
VERIFIED PYQ MATCHES — and use ONLY those exam/year/subject/chapter tags
(e.g. Related: NEET 2024). Never invent citations from memory.

If the student asks for an exact past paper question: do not reproduce it.
You may generate a NEW original practice question on the same concept —
clearly labeled as practice, not an official paper — only when helpful.

Never copy textbook paragraphs verbatim. Explain in original words; summarize;
generate original examples / practice MCQs / revision notes when asked.

====================================================
IF ANSWER NOT FOUND
====================================================
Reply:
"I couldn't find this topic in your uploaded notes or exam database."

Do NOT guess. Do NOT hallucinate. Do NOT create fake information.
If LIVE WEB SEARCH context is present (Tavily last-resort current events),
you may use it and label Source as Trusted Web Search — never pretend it
came from notes. If web context is missing, do NOT invent a web search.
For current-events questions without usable web/notes: say you don't have
reliable current information and suggest an official source.
Never use web search for ordinary syllabus / conceptual doubts."""
    + ASK_AI_VISUAL_EXTENSION
)

def _fetch_matches(
    user_id: str,
    lecture_id: str,
    embedding: list[float],
    source_type: str,
    *,
    threshold: float = _MATCH_THRESHOLD,
    match_count: int = _MATCH_COUNT,
) -> list[dict]:
    db = get_supabase_admin()
    try:
        response = db.rpc(
            "match_rag_documents",
            {
                "p_user_id": user_id,
                "p_lecture_id": lecture_id,
                "p_query_embedding": embedding,
                "p_source_type": source_type,
                "p_match_count": match_count,
                "p_match_threshold": threshold,
            },
        ).execute()
    except Exception as e:  # noqa: BLE001
        raise AskAiError(
            f"RAG match failed — run session3_rag_match.sql in Supabase? ({e})",
            status_code=502,
        ) from e
    return list(response.data or [])


def _fetch_matches_with_fallback(
    user_id: str,
    lecture_id: str,
    embedding: list[float],
    source_type: str,
    *,
    match_count: int = _MATCH_COUNT,
) -> list[dict]:
    hits = _fetch_matches(
        user_id,
        lecture_id,
        embedding,
        source_type,
        match_count=match_count,
    )
    if hits:
        return hits
    # Nearest neighbors even if similarity is low — better than empty answer
    # when notes clearly contain the fact (e.g. Application ID in summary).
    return _fetch_matches(
        user_id,
        lecture_id,
        embedding,
        source_type,
        threshold=_FALLBACK_THRESHOLD,
        match_count=match_count,
    )


def _best_hit_similarity(hits: list[dict]) -> float | None:
    best: float | None = None
    for h in hits:
        try:
            sim = float(h.get("similarity"))
        except (TypeError, ValueError):
            continue
        if best is None or sim > best:
            best = sim
    return best


def _needs_expand(hits: list[dict]) -> bool:
    if not hits:
        return True
    best = _best_hit_similarity(hits)
    if best is None:
        return True
    return best < EXPAND_SIMILARITY_BELOW


def _load_chunk_texts(matches: list[dict], r2: R2StorageService) -> list[dict]:
    sources: list[dict] = []
    for m in matches:
        path = m.get("r2_chunk_path")
        if not path:
            continue
        try:
            text = r2.download_text(path)
        except R2StorageError:
            continue
        if len(text) > CHUNK_MAX_CHARS:
            text = text[:CHUNK_MAX_CHARS]
        sources.append(
            {
                "source_type": m.get("source_type"),
                "similarity": m.get("similarity"),
                "excerpt": text[:400],
                "text": text,
                "lecture_id": m.get("lecture_id"),
            }
        )
    return sources


def _fetch_user_matches(
    user_id: str,
    embedding: list[float],
    source_type: str,
    *,
    only_lecture_id: str | None = None,
    exclude_lecture_id: str | None = None,
    threshold: float = _MATCH_THRESHOLD,
    match_count: int = _MATCH_COUNT,
) -> list[dict]:
    """User-wide or filtered match via match_rag_documents_user (soft-fail empty)."""
    db = get_supabase_admin()
    try:
        response = db.rpc(
            "match_rag_documents_user",
            {
                "p_user_id": user_id,
                "p_query_embedding": embedding,
                "p_source_type": source_type,
                "p_only_lecture_id": only_lecture_id,
                "p_exclude_lecture_id": exclude_lecture_id,
                "p_match_count": match_count,
                "p_match_threshold": threshold,
            },
        ).execute()
    except Exception as e:  # noqa: BLE001
        logger.warning(
            "match_rag_documents_user failed (run rag_match_user_wide_migration.sql?): %s",
            e,
        )
        return []
    return list(response.data or [])


def _near_duplicate(a: str, b: str) -> bool:
    aa = (a or "").strip().lower()[:200]
    bb = (b or "").strip().lower()[:200]
    if not aa or not bb:
        return False
    if aa == bb:
        return True
    return aa in bb or bb in aa


def _merge_open_and_other(
    open_loaded: list[dict], other_loaded: list[dict]
) -> list[dict]:
    """Open lecture first; add other-lecture chunks only if they add new context."""
    merged = list(open_loaded)
    added = 0
    for o in other_loaded:
        if added >= _MAX_OTHER_BLOCKS:
            break
        try:
            sim = float(o.get("similarity") or 0)
        except (TypeError, ValueError):
            sim = 0.0
        if sim < _OTHER_LECTURE_THRESHOLD:
            continue
        otext = o.get("text") or ""
        if any(_near_duplicate(otext, m.get("text") or "") for m in merged):
            continue
        chunk = dict(o)
        chunk["source_type"] = f"other_lecture:{o.get('source_type') or 'notes'}"
        merged.append(chunk)
        added += 1
    return merged


def _supplement_other_lectures(
    user_id: str,
    open_lecture_id: str,
    embedding: list[float],
    r2: R2StorageService,
) -> list[dict]:
    """Strict matches from the student's other lectures (notes then transcript)."""
    notes = _fetch_user_matches(
        user_id,
        embedding,
        "notes",
        exclude_lecture_id=open_lecture_id,
        threshold=_OTHER_LECTURE_THRESHOLD,
        match_count=_OTHER_MATCH_COUNT,
    )
    loaded = _load_chunk_texts(notes, r2)
    if len(loaded) >= _MAX_OTHER_BLOCKS:
        return loaded[:_MAX_OTHER_BLOCKS]
    tr = _fetch_user_matches(
        user_id,
        embedding,
        "clean_transcript",
        exclude_lecture_id=open_lecture_id,
        threshold=_OTHER_LECTURE_THRESHOLD,
        match_count=_OTHER_MATCH_COUNT,
    )
    loaded = loaded + _load_chunk_texts(tr, r2)
    return loaded[:_MAX_OTHER_BLOCKS]


def _credits_balance(user_id: str) -> int:
    db = get_supabase_admin()
    profile = (
        db.table("users")
        .select("credits_balance")
        .eq("id", user_id)
        .single()
        .execute()
    )
    return int((profile.data or {}).get("credits_balance", 0) or 0)


async def _retrieve_lecture_rag(
    user_id: str,
    lecture_id: str,
    query: str,
    timer: PerformanceTimer | None = None,
) -> tuple[list[str], list[dict]]:
    """Open lecture Notes→transcript first; then high-similarity other lectures.

    PDF/photo lectures are never written to rag_documents — context comes from
    direct notes fallback for that lecture only.
    """
    if timer:
        timer.start("index")
    index_meta = await ensure_lecture_indexed(user_id, lecture_id)
    if timer:
        timer.end("index")

    r2 = R2StorageService()
    skipped = bool(index_meta.get("skipped"))

    # PDF / photo: answer from this lecture's notes only (no vector write).
    if skipped:
        loaded = _fallback_full_notes_context(user_id, lecture_id, r2)
        for s in loaded:
            s.setdefault("lecture_id", lecture_id)
        # Still allow audio/YouTube library to reinforce (those are RAG-indexed).
        if timer:
            timer.start("embed")
        embedding = await embed_query(query)
        if timer:
            timer.end("embed")
        if timer:
            timer.start("vector")
        other = _supplement_other_lectures(user_id, lecture_id, embedding, r2)
        if other:
            loaded = _merge_open_and_other(loaded, other)
        if timer:
            timer.end("vector")
            timer.set(chunks=len(loaded), rag_expand=False, rag_skipped_pdf_photo=True)
        context_blocks = [s["text"] for s in loaded]
        sources_meta = [
            {
                "source_type": s["source_type"],
                "similarity": s["similarity"],
                "excerpt": s["excerpt"],
                **({"lecture_id": s["lecture_id"]} if s.get("lecture_id") else {}),
            }
            for s in loaded
        ]
        return context_blocks, sources_meta

    if timer:
        timer.start("embed")
    embedding = await embed_query(query)
    if timer:
        timer.end("embed")

    if timer:
        timer.start("vector")
    notes_hits = _fetch_matches_with_fallback(
        user_id,
        lecture_id,
        embedding,
        "notes",
        match_count=MATCH_COUNT_DEFAULT,
    )
    expanded = False
    if _needs_expand(notes_hits):
        notes_hits = _fetch_matches_with_fallback(
            user_id,
            lecture_id,
            embedding,
            "notes",
            match_count=MATCH_COUNT_EXPAND,
        )
        expanded = True

    if len(notes_hits) >= _MIN_NOTES_HITS and not _needs_expand(notes_hits):
        loaded = _load_chunk_texts(notes_hits, r2)
    else:
        loaded_notes = _load_chunk_texts(notes_hits, r2)
        tr_hits = _fetch_matches_with_fallback(
            user_id,
            lecture_id,
            embedding,
            "clean_transcript",
            match_count=MATCH_COUNT_DEFAULT,
        )
        if _needs_expand(tr_hits):
            tr_hits = _fetch_matches_with_fallback(
                user_id,
                lecture_id,
                embedding,
                "clean_transcript",
                match_count=MATCH_COUNT_EXPAND,
            )
        loaded = loaded_notes + _load_chunk_texts(tr_hits, r2)

    if not loaded:
        loaded = _fallback_full_notes_context(user_id, lecture_id, r2)

    for s in loaded:
        s.setdefault("lecture_id", lecture_id)

    # Supplement with other lectures (weighted) — never dilutes open-lecture priority.
    other = _supplement_other_lectures(user_id, lecture_id, embedding, r2)
    if other:
        loaded = _merge_open_and_other(loaded, other)

    if timer:
        timer.end("vector")
        timer.set(chunks=len(loaded), rag_expand=expanded)

    context_blocks = [s["text"] for s in loaded]
    sources_meta = [
        {
            "source_type": s["source_type"],
            "similarity": s["similarity"],
            "excerpt": s["excerpt"],
            **({"lecture_id": s["lecture_id"]} if s.get("lecture_id") else {}),
        }
        for s in loaded
    ]
    return context_blocks, sources_meta


def _replay_cached_tokens(answer: str, chunk_size: int = 32):
    for i in range(0, len(answer), chunk_size):
        yield answer[i : i + chunk_size]


def _fallback_full_notes_context(user_id: str, lecture_id: str, r2: R2StorageService) -> list[dict]:
    """Last resort: use notes/summary JSON so Ask AI can still answer when
    vector match returns nothing (common on short factual queries)."""
    from app.services.rag_index_service import _load_notes_text, _load_transcript_text

    blocks: list[dict] = []
    notes = _load_notes_text(user_id, lecture_id, r2)
    if notes.strip():
        text = notes[:_FALLBACK_NOTES_CHARS]
        blocks.append(
            {
                "source_type": "notes",
                "similarity": None,
                "excerpt": text[:400],
                "text": text,
            }
        )
    transcript = _load_transcript_text(lecture_id, r2)
    if transcript.strip() and not blocks:
        text = transcript[:_FALLBACK_NOTES_CHARS]
        blocks.append(
            {
                "source_type": "clean_transcript",
                "similarity": None,
                "excerpt": text[:400],
                "text": text,
            }
        )
    return blocks


async def _generate_answer(
    query: str,
    context_blocks: list[str],
    mode: str,
    *,
    conversation_language: str | None = None,
    pyq_matches: list | None = None,
    used_web_search: bool = False,
) -> str:
    if not AIConfig.openrouter_configured():
        raise AskAiError("OPENROUTER_API_KEY not configured on the server.", status_code=500)

    context = "\n\n---\n\n".join(context_blocks) if context_blocks else "(no context retrieved)"
    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.2 if mode == "deep" else 0.3

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
                        {"role": "system", "content": _ASK_SYSTEM},
                        {
                            "role": "user",
                            "content": _ask_user_content(
                                query,
                                context,
                                conversation_language=conversation_language,
                                mode=mode,
                                pyq_matches=pyq_matches,
                                used_web_search=used_web_search,
                            ),
                        },
                    ],
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                },
                timeout=90.0,
            )
    except httpx.TimeoutException as e:
        raise AskAiError(
            "Ask AI timed out.",
            status_code=504,
            result_status=TIMEOUT,
        ) from e
    except httpx.RequestError as e:
        raise AskAiError(
            f"Ask AI network error: {e}",
            status_code=502,
            result_status=NETWORK_ERROR,
        ) from e

    if response.status_code != 200:
        raise AskAiError(
            f"Ask AI (OpenRouter) failed: {response.status_code} {response.text[:300]}",
            status_code=502,
            result_status=API_ERROR,
        )

    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        raise AskAiError(
            "Ask AI returned no choices.",
            status_code=502,
            result_status=API_ERROR,
        )
    content = (choices[0].get("message") or {}).get("content") or ""
    if not content.strip():
        raise AskAiError(
            "Ask AI returned an empty answer.",
            status_code=502,
            result_status=API_ERROR,
        )
    return content.strip()


async def ask_ai(
    user_id: str,
    lecture_id: str,
    query: str,
    mode: str = "normal",
    *,
    conversation_language: str | None = None,
    charge_credits: bool = True,
) -> dict:
    timer = PerformanceTimer("ask_ai")
    timer.start("validation")
    query = (query or "").strip()
    if not query:
        raise AskAiError("Question is empty.", status_code=400)
    if mode not in ("normal", "deep"):
        raise AskAiError("mode must be 'normal' or 'deep'.", status_code=400)

    try:
        require_feature_unlocked(user_id, GatedFeature.ASK_AI)
    except FeatureLockedError as e:
        raise AskAiError(
            str(e),
            status_code=403,
            result_status="FEATURE_LOCKED",
            detail=feature_locked_payload(e),
        ) from e

    route = route_ask_question(query)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lecture_id,
        conversation_language=conversation_language,
        feature="ask_ai",
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

    amount = ask_ai_cost(mode, used_web_search=(route == "web_deferred"))

    def _precheck_sync() -> None:
        if not charge_credits:
            return
        balance = _credits_balance(user_id)
        if balance < amount:
            raise AskAiError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    try:
        timer.start("pre_llm")
        if charge_credits:
            await asyncio.gather(
                ensure_lecture_indexed(user_id, lecture_id),
                asyncio.to_thread(_precheck_sync),
            )
        else:
            await ensure_lecture_indexed(user_id, lecture_id)
        timer.end("pre_llm")
    except RagIndexError as e:
        raise AskAiError(str(e), status_code=e.status_code) from e
    except AskAiError:
        raise

    try:
        # Index already warm — helper's ensure_lecture_indexed is a cheap no-op.
        context_blocks, sources_meta = await _retrieve_lecture_rag(
            user_id, lecture_id, query, timer=timer
        )
    except RagIndexError as e:
        raise AskAiError(str(e), status_code=e.status_code) from e
    except EmbeddingError as e:
        raise AskAiError(str(e), status_code=502) from e

    used_web_search = False
    if route == "web_deferred":
        from app.services.tavily_gate import try_tavily_fallback

        gate = await try_tavily_fallback(
            query=query,
            route=route,
            sources_meta=sources_meta,
            context_blocks=context_blocks,
            feature="ask_ai",
        )
        if gate.used:
            used_web_search = True
            context_blocks = gate.context_blocks
            sources_meta = gate.sources_meta
            answer_source = WEB
            confidence = MEDIUM
            amount = ask_ai_cost(mode, used_web_search=True)
        else:
            answer_source = derive_ask_ai_source(sources_meta, context_blocks)
            if answer_source == NO_MATCH:
                confidence = derive_confidence(sources_meta)
            else:
                confidence = derive_confidence(sources_meta)
            amount = ask_ai_cost(mode, used_web_search=False)
    else:
        answer_source = derive_ask_ai_source(sources_meta, context_blocks)
        confidence = derive_confidence(sources_meta)
        amount = ask_ai_cost(mode, used_web_search=False)

    resolved_lang = resolve_answer_language(query, conversation_language)

    # PYQ match only inside Tavily gate — not on every Ask.
    pyq_matches: list = []
    timer.start("llm")
    raw_answer = await _generate_answer(
        query,
        context_blocks,
        mode,
        conversation_language=conversation_language,
        pyq_matches=pyq_matches,
        used_web_search=used_web_search,
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
                f"Ask AI web search ({mode})"
                if used_web_search
                else f"Ask AI ({mode}) — RAG"
            )
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=desc,
                lecture_id=lecture_id,
                action="ask_ai_web" if used_web_search else "ask_ai",
            )
            credits_charged = amount
        except InsufficientCreditsError as e:
            raise AskAiError(str(e), status_code=402) from e

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
    set_cached_answer(cache_key, result)
    timer.set(cache_hit=False)
    timer.log()
    return result


def _ask_user_content(
    query: str,
    context: str,
    *,
    conversation_language: str | None,
    mode: str = "normal",
    pyq_matches: list | None = None,
    used_web_search: bool = False,
) -> str:
    lang_line = language_hint_user_line(
        query, conversation_language=conversation_language
    )
    speed_line = brevity_user_line(mode)
    speed_suffix = f"\n{speed_line}" if speed_line else ""
    pyq_block = format_verified_pyq_block(pyq_matches)
    if used_web_search:
        return (
            "LIVE WEB SEARCH context (Tavily — current events last resort). "
            "Not from lecture notes. Label Source as Trusted Web Search.\n\n"
            f"{context}\n\n"
            f"{pyq_block}\n\n"
            f"Student question: {query}\n\n"
            f"{lang_line}\n"
            "If snippets are unclear, say you lack reliable current information."
            f"{speed_suffix}"
        )
    return (
        "Use adaptive answer shapes (Shape 1 / 2 / 3). OMIT irrelevant "
        "sections entirely — never N/A filler. "
        "Source must be Uploaded Notes or Clean Transcript from "
        "the context below only.\n\n"
        f"Lecture context:\n{context}\n\n"
        f"{pyq_block}\n\n"
        f"Student question: {query}\n\n"
        f"{lang_line}\n"
        "Answer language MUST match the resolved answer language "
        "(conversation lock / question — not the language of the notes)."
        f"{speed_suffix}"
    )


async def ask_ai_stream(
    user_id: str,
    lecture_id: str,
    query: str,
    mode: str = "normal",
    *,
    conversation_language: str | None = None,
    charge_credits: bool = True,
):
    """Async generator of SSE event dicts. Does not alter ask_ai() JSON path."""
    timer = PerformanceTimer("ask_ai_stream")
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

    route = route_ask_question(query)
    timer.set(route=route)
    cache_key = answer_cache_key(
        user_id=user_id,
        mode=mode,
        query=query,
        lecture_id=lecture_id,
        conversation_language=conversation_language,
        feature="ask_ai",
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
        done_evt = {
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
        if cached.get("visual_payload"):
            done_evt["visual_payload"] = cached.get("visual_payload")
        yield done_evt
        return

    amount = ask_ai_cost(mode, used_web_search=(route == "web_deferred"))

    def _precheck_sync() -> None:
        if not charge_credits:
            return
        balance = _credits_balance(user_id)
        if balance < amount:
            raise AskAiError(
                f"Insufficient credits: balance {balance} < required {amount}",
                status_code=402,
            )

    try:
        timer.start("pre_llm")
        if charge_credits:
            await asyncio.gather(
                ensure_lecture_indexed(user_id, lecture_id),
                asyncio.to_thread(_precheck_sync),
            )
        else:
            await ensure_lecture_indexed(user_id, lecture_id)
        timer.end("pre_llm")
        context_blocks, sources_meta = await _retrieve_lecture_rag(
            user_id, lecture_id, query, timer=timer
        )
    except RagIndexError as e:
        yield {"type": "error", "status": API_ERROR, "message": str(e)}
        return
    except EmbeddingError as e:
        yield {"type": "error", "status": API_ERROR, "message": str(e)}
        return
    except AskAiError as e:
        yield {
            "type": "error",
            "status": e.result_status,
            "message": str(e),
        }
        return

    used_web_search = False
    if route == "web_deferred":
        from app.services.tavily_gate import try_tavily_fallback

        gate = await try_tavily_fallback(
            query=query,
            route=route,
            sources_meta=sources_meta,
            context_blocks=context_blocks,
            feature="ask_ai_stream",
        )
        if gate.used:
            used_web_search = True
            context_blocks = gate.context_blocks
            sources_meta = gate.sources_meta
            answer_source = WEB
            confidence = MEDIUM
            amount = ask_ai_cost(mode, used_web_search=True)
        else:
            answer_source = derive_ask_ai_source(sources_meta, context_blocks)
            confidence = derive_confidence(sources_meta)
            amount = ask_ai_cost(mode, used_web_search=False)
    else:
        answer_source = derive_ask_ai_source(sources_meta, context_blocks)
        confidence = derive_confidence(sources_meta)
        amount = ask_ai_cost(mode, used_web_search=False)

    resolved_lang = resolve_answer_language(query, conversation_language)

    yield {
        "type": "meta",
        "answer_source": answer_source,
        "confidence": confidence,
        "conversation_language": resolved_lang,
        "mode": mode,
        "used_web_search": used_web_search,
    }

    context = (
        "\n\n---\n\n".join(context_blocks)
        if context_blocks
        else "(no context retrieved)"
    )
    pyq_matches: list = []
    max_tokens = max_tokens_for_mode(mode)
    temperature = 0.2 if mode == "deep" else 0.3
    messages = [
        {"role": "system", "content": _ASK_SYSTEM},
        {
            "role": "user",
            "content": _ask_user_content(
                query,
                context,
                conversation_language=conversation_language,
                mode=mode,
                pyq_matches=pyq_matches,
                used_web_search=used_web_search,
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
            "message": "Ask AI returned an empty answer.",
        }
        return

    credits_charged = None
    new_balance = None
    if charge_credits:
        try:
            desc = (
                f"Ask AI web search ({mode}) — stream"
                if used_web_search
                else f"Ask AI ({mode}) — stream"
            )
            new_balance = deduct_credits(
                user_id=user_id,
                amount=amount,
                description=desc,
                lecture_id=lecture_id,
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

    result_core = {
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
        result_core["web_search_note"] = (
            "This answer used a live web search (current events). "
            f"It costs {amount} credits — more than a normal Ask from your notes."
        )
    if visual_payload is not None:
        result_core["visual_payload"] = visual_payload
    set_cached_answer(cache_key, result_core)
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
    }
    if used_web_search:
        done_evt["web_search_note"] = result_core["web_search_note"]
    if visual_payload is not None:
        done_evt["visual_payload"] = visual_payload
    yield done_evt
