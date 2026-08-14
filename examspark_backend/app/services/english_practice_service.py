"""English Learning — AI conversation practice.

Reuses existing Qwen3 (OpenRouter) integration — no new model/API.
Credit cost: 1 per user message exchange (first AI greeting is free).
Context sent to model: last 6-8 messages only (cost + quality balance).
After 50 messages in a session, the session is archived and a new one
starts automatically (old one stays visible in Recent history).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

import httpx

from app.config import AIConfig
from app.services.credits_service import InsufficientCreditsError, deduct_credits
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
_CONTEXT_MESSAGES = 8          # last N messages sent to the model
_MAX_SESSION_MESSAGES = 50     # after this, auto-start a new session
_CREDIT_COST = 1


class EnglishPracticeError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        self.status_code = status_code
        super().__init__(message)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _system_prompt(native_language: str, target_focus: str | None) -> str:
    base = f"""You are "Sonaxia Speak" — a warm, encouraging AI language tutor who can teach ANY language the student wants (English, Hindi, Spanish, French, or any other) — not only English.

The student's native/local language is: {native_language}.

HOW TO SOUND IN {native_language}:
- Write {native_language} the way a real native speaker actually talks in everyday conversation — natural rhythm, common local expressions, the words a friend would really use.
- NEVER sound like a stiff, word-for-word translation from English. If a sentence reads like machine-translated text, rewrite it the way a local person would naturally say it.
- Use the native script (not transliteration) unless the student writes to you in transliteration first.

STRICT ONBOARDING RULES (only for a brand-new conversation, before you know what the student wants):
1. Greet warmly in {native_language}, like a friendly local teacher — not a robot.
2. Ask, in {native_language}: which language do you want to learn? (Any language they name — English, Hindi, Spanish, French, etc.)
3. Once they name a language, ask ONE simple question in {native_language}: do they want to focus on Grammar, Spoken/Conversation, or Vocabulary?
4. Do NOT repeat either question once it's been answered.

LEVEL-CHECK RULES (once you know the target language + focus, BEFORE teaching properly):
5. Ask 2-3 short, simple questions IN THE TARGET LANGUAGE (not {native_language}) to see what the student already knows — e.g. a simple self-introduction, completing a basic sentence, or "how do you say ___?".
6. Based on their answers (vocabulary, grammar accuracy, confidence), silently judge their level: Beginner / Elementary / Intermediate / Advanced. Never announce this label out loud — just use it to guide how you teach from here on.
7. If they struggle, give a very basic answer, or reply in {native_language} instead of the target language, treat them as Beginner and start from the absolute basics.

TEACHING RULES (once the level is known):
- Beginner: explain mostly in {native_language}, give tiny bite-size target-language phrases, repeat often, be very encouraging.
- Intermediate: mix both languages roughly 50/50, introduce short grammar rules, expect full sentences back from the student.
- Advanced: mostly the target language, natural pace, correct mistakes subtly without long explanations.
- Keep every reply SHORT (2-5 sentences) — this is a live chat, not a lecture.
- Always end with a small follow-up question or a tiny practice task, so the conversation keeps flowing.
- Correct mistakes gently: show the correct form, briefly explain why (in {native_language} if the student is a beginner), then continue — never just say "wrong".
- As the student improves, gradually use more of the target language and less {native_language}.
- Be encouraging, never robotic, never repeat the same phrasing twice in a row.
- Never break character or mention that you are an AI model or a prompt.
"""
    if target_focus:
        base += f"\nThe student already chose to focus on: {target_focus}. Do not ask this again — teach it directly.\n"
    return base


async def _call_model(messages: list[dict]) -> str:
    if not AIConfig.openrouter_configured():
        raise EnglishPracticeError("OPENROUTER_API_KEY not configured on the server.", 500)
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
                    "messages": messages,
                    "temperature": 0.5,
                    "max_tokens": 400,
                },
                timeout=60.0,
            )
    except httpx.RequestError as e:
        raise EnglishPracticeError(f"Network error: {e}", 502) from e

    if response.status_code != 200:
        raise EnglishPracticeError(
            f"Model call failed: {response.status_code} {response.text[:200]}", 502
        )
    data = response.json()
    choices = data.get("choices") or []
    if not choices:
        raise EnglishPracticeError("Model returned no response.", 502)
    content = (choices[0].get("message") or {}).get("content") or ""
    if not content.strip():
        raise EnglishPracticeError("Model returned an empty response.", 502)
    return content.strip()


def set_native_language(user_id: str, language: str) -> None:
    lang = (language or "").strip()
    if not lang:
        raise EnglishPracticeError("Language is required.", 400)
    db = get_supabase_admin()
    db.table("users").update({"preferred_native_language": lang}).eq("id", user_id).execute()


def get_native_language(user_id: str) -> str | None:
    db = get_supabase_admin()
    res = (
        db.table("users")
        .select("preferred_native_language")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    rows = res.data or []
    if not rows:
        return None
    return rows[0].get("preferred_native_language")


def _create_session(user_id: str, native_language: str) -> dict:
    db = get_supabase_admin()
    row = {
        "user_id": user_id,
        "native_language": native_language,
        "status": "active",
        "title": "English Practice",
        "created_at": _now(),
        "updated_at": _now(),
    }
    res = db.table("english_practice_sessions").insert(row).execute()
    return (res.data or [{}])[0]


def _get_session(session_id: str, user_id: str) -> dict | None:
    db = get_supabase_admin()
    res = (
        db.table("english_practice_sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    rows = res.data or []
    return rows[0] if rows else None


def _save_message(session_id: str, user_id: str, role: str, text: str, credits: int = 0) -> None:
    db = get_supabase_admin()
    db.table("english_practice_messages").insert(
        {
            "session_id": session_id,
            "user_id": user_id,
            "role": role,
            "message": text,
            "credits_used": credits,
            "created_at": _now(),
        }
    ).execute()


def _recent_messages(session_id: str, limit: int = _CONTEXT_MESSAGES) -> list[dict]:
    db = get_supabase_admin()
    res = (
        db.table("english_practice_messages")
        .select("role,message,created_at")
        .eq("session_id", session_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    rows = list(res.data or [])
    rows.reverse()  # chronological order for the model
    return rows


async def start_session(user_id: str) -> dict:
    """Called when the user opens the English Practice page (after native
    language is already set). Creates a session and generates the free
    opening greeting + first question — no credit charge."""
    native_language = get_native_language(user_id)
    if not native_language:
        raise EnglishPracticeError("Native language not set yet.", 400)

    session = _create_session(user_id, native_language)
    sid = session["id"]

    system = _system_prompt(native_language, None)
    greeting = await _call_model(
        [
            {"role": "system", "content": system},
            {
                "role": "user",
                "content": "(system: start the conversation now with the greeting + first question, per the ONBOARDING RULES)",
            },
        ]
    )
    _save_message(sid, user_id, "assistant", greeting, credits=0)

    return {
        "session_id": sid,
        "native_language": native_language,
        "greeting": greeting,
        "credits_charged": 0,
    }


async def send_message(user_id: str, session_id: str, text: str) -> dict:
    msg = (text or "").strip()
    if not msg:
        raise EnglishPracticeError("Message is empty.", 400)

    session = _get_session(session_id, user_id)
    if not session:
        raise EnglishPracticeError("Session not found.", 404)
    if session.get("status") != "active":
        raise EnglishPracticeError("This session has ended — start a new chat.", 409)

    # Credit check (server-enforced)
    try:
        new_balance = deduct_credits(
            user_id=user_id,
            amount=_CREDIT_COST,
            description="English Practice message",
            action="english_practice",
        )
    except InsufficientCreditsError as e:
        raise EnglishPracticeError(str(e), 402) from e

    native_language = session["native_language"]
    target_focus = session.get("target_focus")

    _save_message(session_id, user_id, "user", msg, credits=_CREDIT_COST)

    history = _recent_messages(session_id, _CONTEXT_MESSAGES)
    model_messages = [{"role": "system", "content": _system_prompt(native_language, target_focus)}]
    for h in history:
        role = "assistant" if h["role"] == "assistant" else "user"
        model_messages.append({"role": role, "content": h["message"]})

    reply = await _call_model(model_messages)
    _save_message(session_id, user_id, "assistant", reply, credits=0)

    db = get_supabase_admin()
    new_count = int(session.get("message_count") or 0) + 1
    updates = {"message_count": new_count, "updated_at": _now()}

    # First time student names the target focus, try to capture it lightly.
    if not target_focus and any(
        k in msg.lower() for k in ("grammar", "spoken", "speak", "vocabulary", "vocab")
    ):
        if "grammar" in msg.lower():
            updates["target_focus"] = "grammar"
        elif "vocab" in msg.lower():
            updates["target_focus"] = "vocabulary"
        elif "spoken" in msg.lower() or "speak" in msg.lower():
            updates["target_focus"] = "spoken"

    session_ended = False
    if new_count >= _MAX_SESSION_MESSAGES:
        updates["status"] = "archived"
        session_ended = True

    db.table("english_practice_sessions").update(updates).eq("id", session_id).execute()

    return {
        "reply": reply,
        "credits_charged": _CREDIT_COST,
        "new_balance": new_balance,
        "session_ended": session_ended,
    }


def list_sessions(user_id: str, limit: int = 30) -> list[dict]:
    db = get_supabase_admin()
    res = (
        db.table("english_practice_sessions")
        .select("id,title,native_language,target_focus,status,message_count,created_at,updated_at")
        .eq("user_id", user_id)
        .order("updated_at", desc=True)
        .limit(limit)
        .execute()
    )
    return list(res.data or [])


def restore_session(session_id: str, user_id: str) -> dict | None:
    session = _get_session(session_id, user_id)
    if not session:
        return None
    db = get_supabase_admin()
    res = (
        db.table("english_practice_messages")
        .select("id,role,message,created_at")
        .eq("session_id", session_id)
        .order("created_at", desc=False)
        .execute()
    )
    return {
        "id": session["id"],
        "native_language": session["native_language"],
        "target_focus": session.get("target_focus"),
        "status": session.get("status"),
        "messages": list(res.data or []),
    }