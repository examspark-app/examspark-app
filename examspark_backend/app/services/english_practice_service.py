"""English Learning — AI conversation practice.

Reuses existing Qwen3 (OpenRouter) integration — no new model/API.
Credit cost: 1 per user message exchange (first AI greeting is free).
Context sent to model: last 6-8 messages only (cost + quality balance).
After 50 messages in a session, the session is archived and a new one
starts automatically (old one stays visible in Recent history).
"""
from __future__ import annotations

import asyncio
import logging
import re
import uuid
from collections.abc import AsyncIterator
from datetime import datetime, timezone

import httpx

from app.config import AIConfig
from app.constants.english_chat_prompt import build_chat_prompt
from app.constants.english_teacher_prompt import build_teacher_prompt
from app.constants.english_suggestion_prompt import SUGGESTION_INSTRUCTION
from app.constants.english_conversation_flow import build_conversation_flow_instruction
from app.services import english_learning_memory_service as learning_memory
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.supabase_admin import get_supabase_admin
from app.services.openrouter_stream import OpenRouterStreamError, stream_chat_completions
from app.services.plan_tier_service import GatedFeature, require_feature_unlocked
from app.services.whisper_service import WhisperTranscriptionError, transcribe_audio

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
_CONTEXT_MESSAGES = 8          # last N messages sent to the model
_MAX_SESSION_MESSAGES = 500
_NEW_CHAT_SUGGESTION_THRESHOLD = 100
_CREDIT_COST = 3
_CHAT_MODELS = {"qwen3", "gemini", "claude"}
_MCQ_MAX_GAP_MESSAGES = 20


class EnglishPracticeError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        self.status_code = status_code
        super().__init__(message)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _schedule_reply_tts(user_id: str, text: str) -> None:
    """Warm the TTS cache without delaying the text chat response."""
    async def synthesize() -> None:
        try:
            from app.services.gemini_tts_service import synthesize_for_user

            await synthesize_for_user(user_id, text)
        except Exception:
            logger.debug("English Practice background TTS failed", exc_info=True)

    asyncio.create_task(synthesize())


def _extract_suggestions(text: str) -> tuple[str, list[str]]:
    """Pull <<SUGGESTIONS>>...<<END_SUGGESTIONS>> out of an AI reply."""
    import re
    match = re.search(r'<<SUGGESTIONS>>(.*?)<<END_SUGGESTIONS>>', text, re.DOTALL)
    if not match:
        return text.strip(), []
    suggestions = [s.strip() for s in match.group(1).split('|') if s.strip()]
    clean = re.sub(r'<<SUGGESTIONS>>.*?<<END_SUGGESTIONS>>', '', text, flags=re.DOTALL).strip()
    return clean, suggestions


def _extract_mcq(text: str) -> tuple[str, dict | None]:
    """Pull <<PRACTICE_MCQ>>...<<END_PRACTICE_MCQ>> JSON out of an AI reply.

    Returns (cleaned_text_without_block, mcq_dict_or_None).
    mcq_dict keys: question (str), options (list[str] of 3), correct_option (int 0-2).
    """
    import json
    import re
    match = re.search(
        r'<<PRACTICE_MCQ>>\s*(.*?)\s*<<END_PRACTICE_MCQ>>',
        text,
        re.DOTALL,
    )
    if not match:
        return text.strip(), None
    raw = match.group(1).strip()
    clean = re.sub(
        r'<<PRACTICE_MCQ>>.*?<<END_PRACTICE_MCQ>>',
        '',
        text,
        flags=re.DOTALL,
    ).strip()
    parsed: object = None
    try:
        parsed = json.loads(raw)
    except Exception:
        start = raw.find('{')
        end = raw.rfind('}')
        if start != -1 and end != -1 and end > start:
            try:
                parsed = json.loads(raw[start:end + 1])
            except Exception:
                parsed = None
    if not isinstance(parsed, dict):
        return clean, None
    question = parsed.get("question")
    options = parsed.get("options")
    correct = parsed.get("correct_option")
    if (
        not isinstance(question, str)
        or not question.strip()
        or not isinstance(options, list)
        or len(options) != 3
        or not all(_is_full_sentence_option(o) for o in options)
        or not isinstance(correct, int)
        or correct < 0
        or correct > 2
    ):
        return clean, None
    return clean, {
        "question": question.strip(),
        "options": [str(o).strip() for o in options],
        "correct_option": int(correct),
    }


def _is_full_sentence_option(option: object) -> bool:
    if not isinstance(option, str):
        return False
    words = re.findall(r"[\w']+", option.strip(), flags=re.UNICODE)
    return len(words) >= 3 and bool(re.search(r"[.!?]$", option.strip()))


def _build_mcq_instruction(native_language: str, target_language: str) -> str:
    tgt = target_language or "English"
    nat = native_language
    return f"""
OPTIONAL PRACTICE MCQ BLOCK — this is SEPARATE from the <<SUGGESTIONS>>
short-phrase chips feature. DO NOT replace <<SUGGESTIONS>> with this block.
Both features are independent and both may appear across different turns.

WHEN TO INCLUDE IT:
- When a short gradeable practice moment naturally fits, e.g. you have
  just taught a grammar point, just introduced a new {tgt} vocabulary word,
  or just finished correcting a clear mistake the student made in their last turn.
- In that situation, you MUST append exactly one valid MCQ block. Do not omit
    it merely because the turn is conversational; keep it short and relevant.
- Never on the very first greeting / onboarding turn of a brand-new conversation.
- Never more than ONE MCQ block per AI reply.
- NOT on every single turn — only every 2-4 teaching turns when it actually helps.
- NEVER include this block on any turn that already uses <<PRACTICE_QUESTION>>
  (the existing open-ended practice marker). Use one or the other per turn.
- Skip it entirely if the same question structure (grammar vs vocab vs
  translation) was already used in either of the last 2 AI replies — vary it.
- Every option MUST be a complete, natural sentence relevant to the situation
    or grammar point. Never use an isolated word, phrase fragment, or single
    vocabulary item as an option.

OUTPUT FORMAT — if you include it, APPEND AFTER the normal reply EXACTLY:
<<PRACTICE_MCQ>>
{{
  "question": "target-language question text",
  "options": ["option 1", "option 2", "option 3"],
  "correct_option": 0
}}
<<END_PRACTICE_MCQ>>

VALIDATE before emitting:
- correct_option MUST be an integer index of the correct choice (0, 1, or 2).
- options MUST be exactly 3 non-empty strings.
- question MUST be a single non-empty string.

MCQ LANGUAGE RULES — READ EVERY TIME:
(1) The QUESTION text is written ONLY in the TARGET LANGUAGE you are teaching
    ({tgt}). Never write the MCQ question in {nat} (the student's native language).
(2) Every {tgt} word or phrase whose WRITING SCRIPT differs from the native
    {nat} script MUST have a natural pronunciation guide in round brackets
    IMMEDIATELY after it. Transliterate the pronunciation using the student's
    OWN native {nat} script and reading conventions — NOT Roman-only IPA.
    Example (native = Bengali script, target = Tamil):
      Correct:   வணக்கம் (বনক্কম)
      Only use raw Roman transliteration (e.g. Vanakkam) in brackets if the
      native {nat} language itself is normally typed using Roman letters.
    Make the bracketed text how a real casual {nat} reader would naturally
    sound it out — not a stiff dictionary phonetic entry.
(3) The 3 OPTIONS follow EXACTLY the same rule as the question:
    write them in {tgt}, and add a ({nat}-script pronunciation) in round
    brackets right after every {tgt} token whose writing script differs from {nat}.
(4) The student's answer INPUT is FREE-FORM and NEVER a forced quiz:
      - they may tap one of the 3 MCQ options, OR
      - they may ignore the options and type/speak their own free-form answer,
        which can be in either {nat} or {tgt}, whichever they prefer.
(5) REMEMBER AGAIN: this MCQ block is in ADDITION TO, not instead of, the
    existing <<SUGGESTIONS>> chips. Both features coexist independently.
"""


def _system_prompt(
    native_language: str,
    target_focus: str | None,
    memory_context: str = '',
    target_language: str = "English",
) -> str:
    tgt = target_language or "English"
    base = f"""{build_chat_prompt(native_language, tgt)}
{build_teacher_prompt(native_language, target_focus, tgt)}

The student's native/local language is: {native_language}.
The language the student is learning (target language) is: {tgt}.

HOW TO SOUND IN {native_language} — FOLLOW THESE RULES EVERY SINGLE TIME:
- Write {native_language} the way an actual native speaker casually talks in real everyday conversation. Use natural word choice, natural sentence rhythm, and the common everyday idioms / phrases a local person would actually use when chatting with a friend. Do NOT sound like a teacher reading from a textbook.
- ABSOLUTELY NEVER produce {native_language} that reads like a stiff, word-for-word, literal translation from {tgt} or English. If you write a sentence and it feels formal / wooden / translated / robotic — STOP — do not output it. Rewrite it the way a real person from that {native_language}-speaking community would naturally say it in their own casual, day-to-day speech.
- Use the everyday native script people normally use for typing / texting / chatting in {native_language}. Do not use overly formal, literary, poetic, archaic, or textbook-heavy register. Sound like a helpful local friend, not a grammar book, not a dictionary, not Google Translate.
- What to AVOID in {native_language}: awkward calques (loan-translations), word order that only works in {tgt} or English, stiff dictionary synonyms when a simpler everyday word is what everyone actually uses, rare literary / archaic words no one uses day-to-day, sentences that read naturally in English but would sound strange or pretentious to a real {native_language} speaker.

STRICT ONBOARDING RULES (only for a brand-new conversation):
1. Greet warmly in {native_language}, like a friendly local teacher — not a robot. As part of this natural greeting, if you do NOT already know the learner's name, casually ask for it ONCE in {native_language}, in the same conversational tone (NOT a robotic form-field style). For example: "नमस्ते! मैं आपकी {tgt} सीखने में मदद करूँगी/करूँगा। बताइए, आपका नाम क्या है?" or whatever fits naturally in {native_language}. If the learner skips the name or doesn't give it, NEVER ask again.
2. Make it clear that {tgt} can start from zero; the learner does not need to know where to begin.
3. After the greeting (+ optional casual name ask above), ask ONE simple question in {native_language}: do they want to start with basic speaking, grammar, or vocabulary? Also accept a free-form answer such as "I cannot speak {tgt}".
4. Do NOT repeat the focus question once it has been answered.

LEVEL-CHECK RULES (once you know the focus, BEFORE teaching properly):
5. Ask 1-2 short, pressure-free questions IN {tgt} to see what the student already knows — e.g. a simple self-introduction or completing a basic sentence. If they say they are new, begin immediately instead of testing them further.
6. Based on their answers (vocabulary, grammar accuracy, confidence), silently judge their level: Beginner / Elementary / Intermediate / Advanced. Never announce this label out loud — just use it to guide how you teach from here on.
7. If they struggle, give a very basic answer, or reply in {native_language} instead of the target language, treat them as Beginner and start from the absolute basics.

TEACHING RULES (once the level is known):
- Beginner: explain mostly in {native_language}, give tiny bite-size {tgt} phrases, repeat often, be very encouraging.
- Intermediate: mix both languages roughly 50/50, introduce short grammar rules, expect full sentences back from the student.
- Advanced: mostly {tgt}, natural pace, correct mistakes subtly without long explanations.
- Keep every reply SHORT (2-5 sentences) — this is a live chat, not a lecture.
- Always end with a small follow-up question or a tiny practice task, so the conversation keeps flowing.
- Correct mistakes gently: show the correct form, briefly explain why (in {native_language} if the student is a beginner), then continue — never just say "wrong".
- As the student improves, gradually use more {tgt} and less {native_language}.
- Be encouraging, never robotic, never repeat the same phrasing twice in a row.
- Never break character or mention that you are an AI model or a prompt.

THREE-STAGE LEARNING PROGRESSION — CHAT MODE:
- Stage 1 is the existing foundation: language setup, level discovery,
    beginner teaching, and learning-memory building. Do not skip or replace it.
- Once the learner has a foundation and seems ready, move naturally into
    Stage 2 practical situational learning. Teach one real-world situation at a
    time, such as speaking with a taxi driver, asking a shop price, or asking
    for directions. Give concrete, usable {tgt} phrases, not only an abstract
    explanation. If {tgt} and {native_language} use different scripts, add the
    natural {native_language}-script pronunciation guide in brackets immediately
    after target-language phrases, using the same rule as the MCQ content.
- Judge readiness from the learner's engagement and answers, not from a fixed
    turn count. Keep the situation short and useful, then invite one small try.
- At any point, if the learner says they have a doubt, asks a different
    question, or requests another situation, pause the current example and
    address the new request in the same chat. Never force completion of a lesson
    topic and never require a New Chat for an in-language topic change.
- After sufficient practical practice, explicitly ask whether the learner
    wants to move into Roleplay Mode to practise the situation hands-on. This is
    a real optional choice: never switch silently or force the handoff. If they
    decline, continue Chat Mode help naturally.

CORRECTION AND RETRY — USE WHENEVER THE LEARNER MAKES A GRAMMAR OR SPEAKING
ERROR:
- Stay warm and encouraging: briefly react first, then say the correction is
    a small fix, never say only "wrong" and never shame the learner.
- Show the correct {tgt} word or sentence. If the learner is a beginner,
    explain the reason briefly in natural {native_language}.
- Invite an actual retry in the next beat: ask the learner to say or type the
    corrected phrase themselves. Do not correct and immediately move on without
    giving them that chance.
- Add a practical speaking tip when useful, such as speaking slowly, breaking
    the phrase into two parts, or stressing one key word. Keep it short.
- For a pronunciation mistake where audio is available, model the target
    phrase, give the brief tip, and ask them to record it again. For text-only
    input, treat likely spelling/grammar problems gently and still invite a
    spoken or typed retry.

{SUGGESTION_INSTRUCTION}
{_build_mcq_instruction(native_language, tgt)}
{build_conversation_flow_instruction(focus_selected=bool(target_focus))}
"""
    if target_focus:
        base += f"\nThe student already chose to focus on: {target_focus}. Do not ask this again — teach it directly.\n"
    return base + (f"\n\n{memory_context}" if memory_context else '')


def _mcq_cadence_instruction(force_mcq: bool) -> str:
    if not force_mcq:
        return ""
    return """
MCQ CADENCE GUARD — IMPORTANT:
The conversation has reached the maximum allowed gap since the last MCQ.
This reply MUST append exactly one <<PRACTICE_MCQ>> block after the normal
reply. Make it a short grammar/context question based on this turn, with
exactly three complete sentence options and one correct_option index. Do not
skip it merely because the moment is conversational; keep the sentences easy
and relevant. Do not use <<PRACTICE_QUESTION>> on this reply.
"""


def _temperature_for_messages(message_count: int) -> float:
    if message_count <= 4:
        return 0.5
    if message_count <= 10:
        return 0.6
    return 0.75


def _max_tokens_for_messages(message_count: int) -> int:
    if message_count <= 4:
        return 400
    if message_count <= 10:
        return 700
    return 900


async def _call_model(messages: list[dict], model: str | None = None) -> str:
    """Non-streaming OpenRouter call — used for turns that return JSON extras."""
    import httpx
    from app.config import AIConfig
    from app.constants.ai_response_status import API_ERROR, NETWORK_ERROR, TIMEOUT

    if not AIConfig.openrouter_configured():
        raise EnglishPracticeError(
            "OPENROUTER_API_KEY not configured on the server.",
            500,
        )
    temperature = _temperature_for_messages(len(messages))
    max_tokens = _max_tokens_for_messages(len(messages))
    headers = {
        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }
    body = {
        "model": model or AIConfig.AI_CHAT_MODEL,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            response = await client.post(
                _OPENROUTER_URL,
                headers=headers,
                json=body,
            )
            if response.status_code != 200:
                err = (response.text or "")[:400]
                raise EnglishPracticeError(
                    f"Tutor call failed ({response.status_code}): {err}",
                    502,
                )
            payload = response.json()
            choices = payload.get("choices") or []
            if not choices:
                return ""
            message = choices[0].get("message") or {}
            content = message.get("content")
            if isinstance(content, str):
                logger.info(
                    "english_practice_raw_mcq_marker=%s",
                    "<<PRACTICE_MCQ>>" in content,
                )
                return content
            return ""
    except httpx.TimeoutException as e:
        raise EnglishPracticeError("Tutor call timed out.", 504) from e
    except httpx.RequestError as e:
        raise EnglishPracticeError(f"Tutor network error: {e}", 502) from e
    except EnglishPracticeError:
        raise
    except Exception as e:
        raise EnglishPracticeError(f"Tutor error: {e}", 500) from e


async def _call_gemini_model(messages: list[dict]) -> str:
    if not AIConfig.gemini_tts_configured():
        raise EnglishPracticeError(
            "GEMINI_API_KEY not configured on the server.", 500
        )
    system_parts = [
        {"text": message["content"]}
        for message in messages
        if message.get("role") == "system"
    ]
    contents = [
        {
            "role": "model" if message.get("role") == "assistant" else "user",
            "parts": [{"text": message.get("content", "")}],
        }
        for message in messages
        if message.get("role") != "system"
    ]
    payload = {
        "systemInstruction": {"parts": system_parts},
        "contents": contents,
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 900,
        },
    }
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{AIConfig.GEMINI_CHAT_MODEL}:generateContent"
    )
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                url,
                headers={"x-goog-api-key": AIConfig.GEMINI_API_KEY},
                json=payload,
            )
            if response.status_code != 200:
                raise EnglishPracticeError(
                    f"Gemini tutor call failed ({response.status_code}): "
                    f"{response.text[:400]}",
                    502,
                )
            try:
                candidates = response.json().get("candidates") or []
                parts = (candidates[0].get("content") or {}).get("parts") or []
                text = "".join(
                    part.get("text", "")
                    for part in parts
                    if isinstance(part, dict)
                ).strip()
            except (IndexError, KeyError, TypeError, ValueError) as error:
                raise EnglishPracticeError(
                    "Gemini returned an invalid response.", 502
                ) from error
            if not text:
                raise EnglishPracticeError("Gemini returned an empty response.", 502)
            return text
    except httpx.TimeoutException as e:
        raise EnglishPracticeError("Gemini tutor call timed out.", 504) from e
    except httpx.RequestError as e:
        raise EnglishPracticeError(f"Gemini tutor network error: {e}", 502) from e


async def _call_claude_model(messages: list[dict]) -> str:
    if not AIConfig.CLAUDE_API_KEY:
        raise EnglishPracticeError("CLAUDE_API_KEY not configured on the server.", 500)
    system = "\n\n".join(
        message.get("content", "")
        for message in messages
        if message.get("role") == "system"
    )
    turns = [
        {
            "role": message.get("role"),
            "content": message.get("content", ""),
        }
        for message in messages
        if message.get("role") != "system"
    ]
    payload = {
        "model": AIConfig.CLAUDE_CHAT_MODEL,
        "system": system,
        "messages": turns,
        "max_tokens": 900,
        "temperature": 0.7,
    }
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": AIConfig.CLAUDE_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json=payload,
            )
            if response.status_code != 200:
                raise EnglishPracticeError(
                    f"Claude tutor call failed ({response.status_code}): "
                    f"{response.text[:400]}",
                    502,
                )
            content = response.json().get("content") or []
            text = "".join(
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and block.get("type") == "text"
            ).strip()
            if not text:
                raise EnglishPracticeError("Claude returned an empty response.", 502)
            return text
    except httpx.TimeoutException as e:
        raise EnglishPracticeError("Claude tutor call timed out.", 504) from e
    except httpx.RequestError as e:
        raise EnglishPracticeError(f"Claude tutor network error: {e}", 502) from e


async def _call_chat_model(messages: list[dict], selected_model: str) -> str:
    model = selected_model if selected_model in _CHAT_MODELS else "qwen3"
    if model == "claude":
        reply = await _call_claude_model(messages)
        logger.info("english_practice_chat_model_selected=claude served=claude")
        return reply
    fallback = "gemini" if model == "qwen3" else "qwen3"
    try:
        if model == "gemini":
            reply = await _call_gemini_model(messages)
        else:
            reply = await _call_model(messages)
        logger.info("english_practice_chat_model_selected=%s served=%s", model, model)
        return reply
    except EnglishPracticeError as primary_error:
        logger.warning(
            "english_practice_chat_model_failed selected=%s fallback=%s error=%s",
            model,
            fallback,
            type(primary_error).__name__,
        )
        try:
            if fallback == "gemini":
                reply = await _call_gemini_model(messages)
            else:
                reply = await _call_model(messages)
            logger.info(
                "english_practice_chat_model_selected=%s served=%s",
                model,
                fallback,
            )
            return reply
        except EnglishPracticeError:
            logger.exception(
                "english_practice_chat_models_failed selected=%s fallback=%s",
                model,
                fallback,
            )
            raise primary_error


async def _stream_model(
    messages: list[dict], selected_model: str = "qwen3"
) -> AsyncIterator[str]:
    model = selected_model if selected_model in _CHAT_MODELS else "qwen3"
    if model in {"gemini", "claude"}:
        yield await _call_chat_model(messages, model)
        return
    temperature = _temperature_for_messages(len(messages))
    max_tokens = _max_tokens_for_messages(len(messages))
    try:
        async for delta in stream_chat_completions(
            messages,
            temperature=temperature,
            max_tokens=max_tokens,
            model=AIConfig.AI_CHAT_MODEL,
            timeout=90.0,
        ):
            yield delta
    except OpenRouterStreamError as e:
        raise EnglishPracticeError(str(e), e.status_code) from e


def get_native_language(user_id: str) -> str:
    try:
        row = (
            get_supabase_admin()
            .table("users")
            .select("preferred_native_language")
            .eq("id", user_id)
            .limit(1)
            .execute()
            .data
            or []
        )
    except Exception:
        return ""

    if not row:
        return ""

    value = row[0].get("preferred_native_language") or ""
    return value if isinstance(value, str) else ""


def get_target_language(user_id: str) -> str:
    try:
        row = (
            get_supabase_admin()
            .table("users")
            .select("preferred_target_language")
            .eq("id", user_id)
            .limit(1)
            .execute()
            .data
            or []
        )
    except Exception:
        return "English"

    if not row:
        return "English"

    value = row[0].get("preferred_target_language") or "English"
    return value if isinstance(value, str) else "English"


def set_native_language(user_id: str, language: str) -> None:
    lang = (language or "").strip()

    if not lang:
        raise EnglishPracticeError("Language cannot be empty.", 400)

    if len(lang) > 60:
        raise EnglishPracticeError("Language name is too long.", 400)

    try:
        get_supabase_admin().table("users").update(
            {"preferred_native_language": lang}
        ).eq("id", user_id).execute()
    except Exception as e:
        raise EnglishPracticeError(
            f"Could not save preference: {e}", 500
        ) from e


def set_target_language(user_id: str, language: str) -> None:
    lang = (language or "").strip()

    if not lang:
        raise EnglishPracticeError("Language cannot be empty.", 400)

    if len(lang) > 60:
        raise EnglishPracticeError("Language name is too long.", 400)

    try:
        get_supabase_admin().table("users").update(
            {"preferred_target_language": lang}
        ).eq("id", user_id).execute()
    except Exception as e:
        raise EnglishPracticeError(
            f"Could not save preference: {e}", 500
        ) from e


def _session_row(session_id: str, user_id: str) -> dict | None:
    rows = (
        get_supabase_admin()
        .table("english_practice_sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
        .data or []
    )
    return rows[0] if rows else None


def list_sessions(user_id: str, limit: int = 30) -> list[dict]:
    limit = max(1, min(limit, 100))
    rows = (
        get_supabase_admin()
        .table("english_practice_sessions")
        .select("id, title, pinned, created_at, updated_at, message_count")
        .eq("user_id", user_id)
        .order("pinned", desc=True)
        .order("updated_at", desc=True)
        .limit(limit)
        .execute()
        .data or []
    )
    return list(rows)


def latest_active_session(user_id: str) -> dict | None:
    rows = (
        get_supabase_admin().table("english_practice_sessions")
        .select("id")
        .eq("user_id", user_id)
        .eq("status", "active")
        .order("updated_at", desc=True)
        .limit(1)
        .execute()
        .data or []
    )
    return rows[0] if rows else None


def restore_session(session_id: str, user_id: str) -> dict | None:
    session = _session_row(session_id, user_id)
    if not session:
        return None
    get_supabase_admin().table("english_practice_sessions").update(
        {"updated_at": _now()}
    ).eq("id", session_id).eq("user_id", user_id).execute()
    messages = (
        get_supabase_admin()
        .table("english_practice_messages")
        .select("role, message, created_at")
        .eq("session_id", session_id)
        .eq("user_id", user_id)
        .order("created_at", desc=False)
        .execute()
        .data or []
    )
    return {
        "id": session["id"],
        "title": session.get("title"),
        "pinned": bool(session.get("pinned")),
        "native_language": session.get("native_language") or "English",
        "target_language": session.get("target_language") or "English",
        "text_model": session.get("text_model") or "qwen3",
        "created_at": session.get("created_at"),
        "updated_at": session.get("updated_at"),
        "messages": list(messages),
    }


def rename_session(session_id: str, user_id: str, title: str) -> dict | None:
    cleaned = (title or "").strip()[:120]
    if not cleaned:
        raise EnglishPracticeError("Title cannot be empty.", 400)
    result = (
        get_supabase_admin()
        .table("english_practice_sessions")
        .update({"title": cleaned})
        .eq("id", session_id)
        .eq("user_id", user_id)
        .select("id, title")
        .execute()
        .data or []
    )
    return result[0] if result else None


def delete_session(session_id: str, user_id: str) -> bool:
    if not _session_row(session_id, user_id):
        return False
    get_supabase_admin().table("english_practice_messages").delete().eq(
        "session_id", session_id
    ).eq("user_id", user_id).execute()
    result = (
        get_supabase_admin()
        .table("english_practice_sessions")
        .delete()
        .eq("id", session_id)
        .eq("user_id", user_id)
        .execute()
    )
    return True


def set_session_pinned(session_id: str, user_id: str, pinned: bool) -> bool:
    if not _session_row(session_id, user_id):
        return False
    get_supabase_admin().table("english_practice_sessions").update(
        {"pinned": bool(pinned), "updated_at": _now()}
    ).eq("id", session_id).eq("user_id", user_id).execute()
    return True


def _focus_from_message(text: str) -> str | None:
    t = text.lower()
    if any(w in t for w in ["grammar", "grammar", "vyakaran", "व्याकरण"]):
        return "grammar"
    if any(w in t for w in ["vocab", "word", "shabd", "शब्द", "word meaning", "vocabulary"]):
        return "vocabulary"
    if any(w in t for w in ["speak", "bol", "बोल", "speaking", "conversation", "baat", "बात"]):
        return "speaking"
    if "i cannot speak" in t or "i don't speak" in t or "i can't speak" in t:
        return "beginner"
    return None


def _build_context_messages(
    session_id: str,
    user_id: str,
    native_language: str,
    target_language: str,
    focus: str | None,
    force_mcq: bool = False,
) -> tuple[list[dict], int]:
    db = get_supabase_admin()
    rows = (
        db.table("english_practice_messages")
        .select("role, message")
        .eq("session_id", session_id)
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(_CONTEXT_MESSAGES)
        .execute()
        .data or []
    )
    message_count = len(rows)
    memory_context = learning_memory.format_memory_context(
        learning_memory.load_memory(user_id, target_language), mode="chat"
    )
    system_text = _system_prompt(
        native_language=native_language,
        target_focus=focus,
        memory_context=memory_context,
        target_language=target_language,
    )
    system_text += _mcq_cadence_instruction(force_mcq)
    messages: list[dict] = [{"role": "system", "content": system_text}]
    messages += [{"role": r["role"], "content": r["message"]} for r in reversed(rows)]
    return messages, message_count


def _persist_message(
    session_id: str, user_id: str, role: str, message: str
) -> None:
    get_supabase_admin().table("english_practice_messages").insert(
        {
            "session_id": session_id,
            "user_id": user_id,
            "role": role,
            "message": message,
        }
    ).execute()
    get_supabase_admin().table("english_practice_sessions").update(
        {"updated_at": _now(), "message_count": _message_count_incremental(session_id, user_id)}
    ).eq("id", session_id).eq("user_id", user_id).execute()


def _message_count_incremental(session_id: str, user_id: str) -> int:
    rows = (
        get_supabase_admin()
        .table("english_practice_messages")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("user_id", user_id)
        .execute()
        .data or []
    )
    return len(rows)


def _mark_mcq_shown(session_id: str, user_id: str, message_count: int) -> None:
    get_supabase_admin().table("english_practice_sessions").update(
        {"last_mcq_message_count": message_count}
    ).eq("id", session_id).eq("user_id", user_id).execute()


def _split_and_extract(raw_reply: str) -> tuple[str, list[str], dict | None]:
    """Run extractors in order and return (clean_text, suggestions, mcq)."""
    clean, suggestions = _extract_suggestions(raw_reply)
    clean, mcq = _extract_mcq(clean)
    return clean.strip(), suggestions, mcq


async def start_session(user_id: str, model: str = "qwen3") -> dict:
    db = get_supabase_admin()
    native = get_native_language(user_id) or "English"
    target = get_target_language(user_id) or "English"
    if model == "claude":
        require_feature_unlocked(user_id, GatedFeature.PREMIUM_CHAT_MODEL)
    if not native or native.strip() == "":
        native = "English"
    session = (
        db.table("english_practice_sessions")
        .insert(
            {
                "user_id": user_id,
                "native_language": native,
                "target_language": target,
                "status": "active",
                "title": f"{target} Practice · {_now()[:10]}",
                "message_count": 0,
                "text_model": model if model in _CHAT_MODELS else "qwen3",
            }
        )
        .execute()
        .data[0]
    )
    sid = session["id"]
    memory_context = learning_memory.format_memory_context(
        learning_memory.load_memory(user_id, target), mode="chat"
    )
    system_text = _system_prompt(
        native_language=native,
        target_focus=None,
        memory_context=memory_context,
        target_language=target,
    )
    raw = await _call_chat_model(
        [
            {"role": "system", "content": system_text},
            {
                "role": "user",
                "content": "(system: This is the very first greeting turn of a brand new conversation. Welcome the learner warmly in their native language, keep it short and EXCITED — like running into a friend who wants to finally learn something together, not a reception desk. FRIEND-ENERGY CALIBRATION: Do NOT just flatly say 'Welcome! What would you like to learn today?' Instead, give ONE tiny specific vibe/opinion first (e.g. a playful 'Great day to start speaking — way better than scrolling, trust me lol' or whatever feels natural in their native language, fresh every time), then fold the rest into that reaction. If you do NOT already know the learner's name (check the learner-memory block above), casually ask for it ONCE as part of your greeting — do NOT make it sound like a form field. Then ask them whether they want to start with basic speaking, grammar, or vocabulary. If you already know their name from the memory block, you may use it naturally once. Do NOT emit a PRACTICE_MCQ block on this opening turn. BAD flat example to AVOID: 'Namaste! Aapka swagat hai. Aap kya seekhna chahenge?' GOOD alive example (feel only, do NOT copy words — invent a fresh vibe): 'Wah! Aaj finally {tgt} सीखने का perfect day hai — honestly main bhi excited hoon shuru karne ke liye! 😊 Pehle to bataiye, aapka naam kya hai? Phir decide karte hain — start with bolna chahenge, ya thoda grammar, ya naye vocabulary words?')",
            },
        ],
        model if model in _CHAT_MODELS else "qwen3",
    )
    clean, suggestions, mcq = _split_and_extract(raw)
    greeting = clean or f"Welcome! Let's start {target} practice — pick speaking, grammar, or vocabulary to begin."
    _persist_message(sid, user_id, "assistant", greeting)
    _schedule_reply_tts(user_id, greeting)
    result: dict = {
        "session_id": sid,
        "native_language": native,
        "target_language": target,
        "greeting": greeting,
        "suggestions": suggestions,
        "created_at": session.get("created_at"),
    }
    if mcq is not None:
        result["mcq"] = mcq
    return result


async def send_message(
    user_id: str, session_id: str, message: str
) -> dict:
    session = _session_row(session_id, user_id)
    text = (message or "").strip()
    if not session:
        raise EnglishPracticeError("Session not found.", 404)
    if not text:
        raise EnglishPracticeError("Message cannot be empty.", 400)
    native = session.get("native_language") or get_native_language(user_id) or "English"
    target = session.get("target_language") or "English"
    model = session.get("text_model") or "qwen3"
    if model == "claude":
        try:
            require_feature_unlocked(user_id, GatedFeature.PREMIUM_CHAT_MODEL)
        except Exception as error:
            raise EnglishPracticeError(str(error), 403) from error
    existing_count = _message_count_incremental(session_id, user_id)
    last_mcq_count = int(session.get("last_mcq_message_count") or 0)
    force_mcq = existing_count >= last_mcq_count + _MCQ_MAX_GAP_MESSAGES - 2
    if existing_count >= _MAX_SESSION_MESSAGES:
        raise EnglishPracticeError(
            "This session has reached 100 messages. Please start a new chat.",
            409,
        )
    focus: str | None = None
    if existing_count <= 1:
        focus = _focus_from_message(text)
    _persist_message(session_id, user_id, "user", text)
    try:
        deduct_credits(
            user_id,
            _CREDIT_COST,
            description="English Practice chat turn",
            action="english_practice_turn",
        )
    except InsufficientCreditsError as e:
        raise EnglishPracticeError(str(e), 402) from e
    messages, total = _build_context_messages(
        session_id=session_id,
        user_id=user_id,
        native_language=native,
        target_language=target,
        focus=focus,
        force_mcq=force_mcq,
    )
    raw_reply = await _call_chat_model(messages, model)
    clean, suggestions, mcq = _split_and_extract(raw_reply)
    reply = clean or "Okay, let's continue."
    _persist_message(session_id, user_id, "assistant", reply)
    learning_memory.schedule_update(
        user_id=user_id,
        native_language=native,
        mode="chat",
        user_text=text,
        assistant_text=reply,
        target_language=target,
    )
    _schedule_reply_tts(user_id, reply)
    result: dict = {
        "reply": reply,
        "suggestions": suggestions,
        "message_count": existing_count + 2,
        "suggest_new_chat": existing_count + 2 >= _NEW_CHAT_SUGGESTION_THRESHOLD,
    }
    if mcq is not None:
        result["mcq"] = mcq
        _mark_mcq_shown(session_id, user_id, existing_count + 2)
    return result


async def send_audio_message(
    user_id: str, session_id: str, audio_bytes: bytes, filename: str
) -> dict:
    if not audio_bytes:
        raise EnglishPracticeError("Audio file is empty.", 400)
    session = _session_row(session_id, user_id)
    if not session:
        raise EnglishPracticeError("Session not found.", 404)
    try:
        transcription = await transcribe_audio(audio_bytes, filename)
    except WhisperTranscriptionError as e:
        raise EnglishPracticeError(f"Could not understand the audio: {e}", 502) from e
    transcript = transcription.text.strip()
    if not transcript:
        raise EnglishPracticeError("No speech detected. Please try again.", 400)
    result = await send_message(user_id, session_id, transcript)
    result["transcript"] = transcript
    return result
