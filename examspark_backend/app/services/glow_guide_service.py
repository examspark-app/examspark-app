"""GlowGuide isolated multimodal conversation service."""
from __future__ import annotations

import base64
import asyncio
import json
import logging
import uuid
from collections.abc import Awaitable, Callable
from datetime import datetime, timezone
from typing import Any

import httpx

from app.config import AIConfig
from app.constants.glow_guide_prompt import system_prompt
from app.constants.language_hint import resolve_answer_language
from app.services.credits_service import InsufficientCreditsError, deduct_credits, get_credits_balance
from app.services.supabase_admin import get_supabase_admin
from app.services.r2_storage_service import R2StorageService
from app.services.glow_guide_research_service import (
    save_tavily_research,
    search_cached_research,
    tavily_research,
    is_targeted_research_query,
)

logger = logging.getLogger(__name__)
GLOW_GUIDE_TEXT_COST = 2
GLOW_GUIDE_PHOTO_COST = 5
GLOW_GUIDE_RESEARCH_COST = 10
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MAX_GLOW_GUIDE_EXCHANGES = 100

REQUIRED_FIELDS = ["concern", "skin_type", "season", "product_info"]  # product_info = OCR'd/manual ingredients


def _log_research_save_result(task: asyncio.Task[None]) -> None:
    try:
        task.result()
    except Exception as error:  # noqa: BLE001
        logger.warning("GlowGuide research cache save failed: %s", error)


def glow_guide_credit_cost(has_photo: bool) -> int:
    """GlowGuide charges 2 for text-only, 5 when a photo is attached."""
    return GLOW_GUIDE_PHOTO_COST if has_photo else GLOW_GUIDE_TEXT_COST


class GlowGuideError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        self.status_code = status_code
        super().__init__(message)


def _json(raw: str) -> dict[str, Any]:
    text = (raw or "").strip().strip('`')
    if text.lower().startswith("json"):
        text = text[4:].strip()
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start < 0 or end <= start:
            raise GlowGuideError("GlowGuide returned invalid JSON.", 502)
        try:
            value = json.loads(text[start:end + 1])
        except json.JSONDecodeError as error:
            raise GlowGuideError("GlowGuide returned invalid JSON.", 502) from error
    if not isinstance(value, dict):
        raise GlowGuideError("GlowGuide returned invalid JSON.", 502)
    return value


def _mime(filename: str | None) -> str:
    name = (filename or "").lower()
    return "image/png" if name.endswith(".png") else "image/jpeg"


def _multimodal_messages(rows: list[dict[str, Any]], text: str, image: bytes | None, filename: str | None) -> list[dict[str, Any]]:
    messages: list[dict[str, Any]] = [{"role": r.get("role", "user"), "content": r.get("message", "")} for r in rows]
    content: Any = text or "Analyze this GlowGuide photo and ask the next necessary question."
    if image:
        content = [
            {"type": "text", "text": content},
            {"type": "image_url", "image_url": {"url": f"data:{_mime(filename)};base64,{base64.b64encode(image).decode('ascii')}"}},
        ]
    messages.append({"role": "user", "content": content})
    return messages


def glow_guide_language_for_turn(text: str, preferred_language: str | None = None) -> str:
    """Follow the same answer-language detection contract used across the app."""
    resolved = resolve_answer_language(text, conversation_language=preferred_language)
    return resolved or "MATCH_QUESTION"


def _next_missing_field(ctx: dict, active_category: str | None, has_image_this_turn: bool, image: bytes | None) -> str | None:
    if not ctx.get("concern"):
        return "concern"
    if not ctx.get("age") and active_category == "baby":
        return "age"
    if active_category == "hair":
        if not ctx.get("hair_type"):
            return "hair_type"
    elif not ctx.get("skin_type") and active_category != "baby":
        return "skin_type"
    if not ctx.get("season") and not ctx.get("weather"):
        return "season"
    if not ctx.get("concern_details") and not has_image_this_turn and not image:
        return "product_info"
    return None

def _title_for_session(active_category: str | None, context: dict, user_text: str) -> str:
    concern = (context.get("concern") or "").strip()
    if concern:
        concern = (concern[:40] + "…") if len(concern) > 40 else concern
        if active_category:
            category = active_category.replace("_", " ").replace("-", " ").title()
            return f"{category} · {concern}"
        return concern
    if active_category:
        return active_category.replace("_", " ").replace("-", " ").title()
    text = (user_text or "").strip()
    if text:
        return (text[:40] + "…") if len(text) > 40 else text
    return "GlowGuide Chat"


def rename_session(session_id: str, user_id: str, title: str) -> dict | None:
    cleaned = (title or "").strip()[:120]
    if not cleaned:
        raise GlowGuideError("Title cannot be empty.", 400)
    rows = (
        get_supabase_admin()
        .table("glow_guide_sessions")
        .update({
            "title": cleaned,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })
        .eq("id", session_id)
        .eq("user_id", user_id)
        .select("id,title,updated_at")
        .execute()
        .data or []
    )
    return rows[0] if rows else None
async def _call_gemini(messages: list[dict[str, Any]]) -> str:
    if not AIConfig.gemini_tts_configured():
        raise GlowGuideError("Gemini is not configured.", 500)
    system_text = messages[0]["content"]
    contents: list[dict[str, Any]] = []
    for message in messages[1:]:
        content = message["content"]
        parts: list[dict[str, Any]] = []
        if isinstance(content, list):
            for item in content:
                if item["type"] == "text":
                    parts.append({"text": item["text"]})
                else:
                    header, data = item["image_url"]["url"].split(",", 1)
                    parts.append({"inlineData": {"mimeType": header.split(";", 1)[0][5:], "data": data}})
        else:
            parts.append({"text": content})
        contents.append({
            "role": "model" if message["role"] == "assistant" else "user",
            "parts": parts,
        })
    payload = {"systemInstruction": {"parts": [{"text": system_text}]}, "contents": contents, "generationConfig": {"temperature": 0.45, "maxOutputTokens": 1200, "responseMimeType": "application/json"}}
    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post(f"https://generativelanguage.googleapis.com/v1beta/models/{AIConfig.GLOWGUIDE_GEMINI_MODEL}:generateContent", headers={"x-goog-api-key": AIConfig.GEMINI_API_KEY}, json=payload)
    if response.status_code != 200:
        raise GlowGuideError(f"Gemini failed: {response.status_code}", 502)
    try:
        return response.json()["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError) as error:
        raise GlowGuideError("Gemini returned no answer.", 502) from error


async def _call_claude(messages: list[dict[str, Any]]) -> str:
    if not AIConfig.CLAUDE_API_KEY:
        raise GlowGuideError("Claude is not configured.", 500)
    system_text = messages[0]["content"]
    turns: list[dict[str, Any]] = []
    for message in messages[1:]:
        content = message["content"]
        if isinstance(content, list):
            blocks = []
            for item in content:
                if item["type"] == "text":
                    blocks.append({"type": "text", "text": item["text"]})
                else:
                    header, data = item["image_url"]["url"].split(",", 1)
                    blocks.append({"type": "image", "source": {"type": "base64", "media_type": header.split(";", 1)[0][5:], "data": data}})
            content = blocks
        turns.append({"role": message["role"], "content": content})
    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post("https://api.anthropic.com/v1/messages", headers={"x-api-key": AIConfig.CLAUDE_API_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"}, json={"model": AIConfig.CLAUDE_CHAT_MODEL, "system": system_text, "messages": turns, "max_tokens": 1200, "temperature": 0.45})
    if response.status_code != 200:
        raise GlowGuideError(f"Claude failed: {response.status_code}", 502)
    return "".join(block.get("text", "") for block in response.json().get("content", []) if block.get("type") == "text")


async def _call_qwen(messages: list[dict[str, Any]]) -> str:
    if not AIConfig.openrouter_configured():
        raise GlowGuideError("Qwen is not configured.", 500)
    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post(OPENROUTER_URL, headers={"Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}", "Content-Type": "application/json"}, json={"model": AIConfig.AI_VISION_FLASH_MODEL, "messages": messages, "temperature": 0.45, "max_tokens": 1200, "response_format": {"type": "json_object"}})
    if response.status_code != 200:
        raise GlowGuideError(f"Qwen failed: {response.status_code}", 502)
    return response.json()["choices"][0]["message"]["content"]


async def turn(
    user_id: str,
    session_id: str | None,
    category: str | None,
    text: str,
    image: bytes | None,
    filename: str | None,
    preferred_language: str | None = None,
    age: str | None = None,
    weather: str | None = None,
    on_event: Callable[[dict[str, Any]], Awaitable[None]] | None = None,
) -> dict[str, Any]:
    if not text.strip() and not image:
        raise GlowGuideError("Add a question or photo.", 400)
    db = get_supabase_admin()
    if session_id:
        found = db.table("glow_guide_sessions").select("*").eq("id", session_id).eq("user_id", user_id).limit(1).execute().data or []
        if not found:
            raise GlowGuideError("GlowGuide session not found.", 404)
        current = found[0]
        if current.get("status") == "archived":
            raise GlowGuideError(
                "This GlowGuide chat has reached 100 exchanges. Start a new chat.",
                409,
            )
    else:
        current = db.table("glow_guide_sessions").insert({"user_id": user_id, "category_type": category, "status": "active"}).execute().data[0]
        session_id = current["id"]
    active_category = category or current.get("category_type")
    if category and category != current.get("category_type"):
        db.table("glow_guide_sessions").update({"category_type": category}).eq("id", session_id).eq("user_id", user_id).execute()
    rows = db.table("glow_guide_messages").select("role,message").eq("session_id", session_id).eq("user_id", user_id).order("created_at", desc=False).execute().data or []
    exchange_count = sum(1 for row in rows if row.get("role") == "user")
    if exchange_count >= MAX_GLOW_GUIDE_EXCHANGES:
        db.table("glow_guide_sessions").update({"status": "archived"}).eq("id", session_id).eq("user_id", user_id).execute()
        raise GlowGuideError(
            "This GlowGuide chat has reached 100 exchanges. Start a new chat.",
            409,
        )
    context = dict(current.get("context_json") or {})
    if age and age.strip():
        context["age"] = age.strip()
    if weather and weather.strip():
        context["weather"] = weather.strip()
    base_cost = glow_guide_credit_cost(bool(image))
    if get_credits_balance(user_id) < base_cost:
        raise GlowGuideError(f"Need at least {base_cost} credits for GlowGuide.", 402)

    context_line = ""
    if isinstance(context, dict) and context:
        context_line = "\nPERSISTED CONVERSATION CONTEXT (do not ask for these again): " + json.dumps(context, ensure_ascii=True)

    missing_field = _next_missing_field(context, active_category, bool(image), image)
    questions_asked_so_far = len(context.get("asked_questions") or [])
    if missing_field and questions_asked_so_far < 4:
        context_line += (
            f"\n\nNEXT REQUIRED QUESTION: Ask specifically about '{missing_field}' only. "
            f"This is question #{questions_asked_so_far + 1} of max 4. "
            f"The user's LAST message is their answer to your PREVIOUS question — extract it correctly into the matching JSON field before asking this new one."
        )
    elif missing_field and questions_asked_so_far >= 4:
        context_line += "\n\nYou have asked 4 questions already. Give a PARTIAL verdict now (ready=true) with a disclaimer about missing info — do NOT ask another question."
    else:
        context_line += "\n\nAll required info is known. Give the final verdict now (ready=true)."

    prior_questions = context.get("asked_questions") or []
    if prior_questions:
        context_line += (
            "\n\nQUESTIONS ALREADY ASKED THIS SESSION (never repeat these or ask something semantically equivalent):\n- "
            + "\n- ".join(prior_questions)
        )

    prompt = system_prompt(active_category, text, preferred_language) + context_line
    research = await search_cached_research(text)
    if research is None:
        if is_targeted_research_query(text) and on_event is not None:
            await on_event({"type": "web_search_started"})
        research = await tavily_research(text)
        if is_targeted_research_query(text) and on_event is not None:
            await on_event({
                "type": "web_search_complete" if research else "web_search_failed",
            })
        if research is not None:
            save_task = asyncio.create_task(
                save_tavily_research(text, research["tavily_result"])
            )
            save_task.add_done_callback(_log_research_save_result)
    if research:
        prompt += (
            "\n\nRESEARCH EVIDENCE (supplemental; cite uncertainty and do not diagnose):\n"
            + "\n\n---\n\n".join(research["blocks"])
        )
    messages = [{"role": "system", "content": prompt}, *_multimodal_messages(rows, text, image, filename)]
    parsed: dict[str, Any] | None = None
    errors: list[str] = []
    for tier, caller in (("gemini", _call_gemini), ("claude", _call_claude), ("qwen", _call_qwen)):
        try:
            parsed = _json(await caller(messages))
            logger.info("glow_guide_model_served tier=%s user=%s", tier, user_id)
            break
        except GlowGuideError as error:
            errors.append(f"{tier}: {error}")
    if parsed is None:
        raise GlowGuideError("GlowGuide unavailable. " + " | ".join(errors), 502)
    required_credits = glow_guide_credit_cost(bool(image)) + (
        GLOW_GUIDE_RESEARCH_COST if research and research.get("used_web_search") else 0
    )
    if get_credits_balance(user_id) < required_credits:
        raise GlowGuideError(f"Need {required_credits} credits for GlowGuide research.", 402)
    try:
        balance = deduct_credits(user_id, required_credits, "GlowGuide turn", action="glow_guide")
    except InsufficientCreditsError as error:
        raise GlowGuideError(str(error), 402) from error
    reply = str(parsed.get("reply") or "I need a little more detail before I can help.").strip()
    image_path = None
    if image:
        image_path = R2StorageService().chat_image_path(
            "glowguide", user_id, str(uuid.uuid4()), filename=filename, category=active_category
        )
        R2StorageService().upload_bytes(image_path, image, _mime(filename))
    db.table("glow_guide_messages").insert([
    {"session_id": session_id, "user_id": user_id, "role": "user", "message": text or "", "image_path": image_path},
    {"session_id": session_id, "user_id": user_id, "role": "assistant", "message": reply}]).execute()
    new_exchange_count = exchange_count + 1
    next_context = dict(context) if isinstance(context, dict) else {}
    for key in (
        "category",
        "category_label",
        "age",
        "season",
        "weather",
        "skin_type",
        "hair_type",
        "concern",
        "concern_details",
    ):
        value = parsed.get(key)
        if value is not None and str(value).strip():
            next_context[key] = value
    next_context["category_type"] = parsed.get("category") or active_category
    asked_questions = list(context.get("asked_questions") or [])
    if reply:
        asked_questions.append(reply)
    next_context["asked_questions"] = asked_questions[-10:]  # last 10 rakho, list bloat na ho
    session_update: dict[str, Any] = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "exchange_count": new_exchange_count,
        "context_json": next_context,
    }
    if not current.get("title"):
        session_update["title"] = _title_for_session(active_category, next_context, text)
    if new_exchange_count >= MAX_GLOW_GUIDE_EXCHANGES:
        session_update["status"] = "archived"
    db.table("glow_guide_sessions").update(session_update).eq("id", session_id).eq("user_id", user_id).execute()
    return {"session_id": session_id, "reply": reply, "detailed_breakdown": parsed.get("detailed_breakdown"), "category": parsed.get("category") or active_category, "question_options": parsed.get("question_options") or [], "ready": bool(parsed.get("ready")), "verdict": parsed.get("verdict"), "category_label": parsed.get("category_label"), "confidence_note": parsed.get("confidence_note") or "", "credits_charged": required_credits, "new_balance": balance, "exchange_count": new_exchange_count, "session_complete": new_exchange_count >= MAX_GLOW_GUIDE_EXCHANGES, "answer_source": research.get("answer_source") if research else "MODEL", "used_web_search": bool(research and research.get("used_web_search")), "web_search_status": "complete" if research and research.get("used_web_search") else "not_used", "sources": research.get("sources", []) if research else []}