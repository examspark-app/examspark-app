"""Daily motivational quote — generated once per day, cached, shared by
all users. AI generates an ORIGINAL line (no real-person attribution, to
avoid misquoting), not from a fixed hardcoded list.
"""
import logging
from datetime import date, timezone, datetime

import httpx
from fastapi import APIRouter, Query

from app.config import AIConfig
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["daily-quote"])

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


async def _generate_quote(language: str) -> str:
    prompt = (
        f"Write ONE original, short motivational line (under 20 words) for "
        f"a student studying for exams, in {language}. "
        f"HARD RULE: This must be a completely original line you write "
        f"yourself right now — NEVER attribute it to any real person "
        f"(no writers, poets, freedom fighters, spiritual leaders, or any "
        f"named historical/living figure — e.g. never write '— Tagore' or "
        f"'— Gandhi' or similar, even if it sounds like something they "
        f"might have said). Do not add any name, dash-attribution, or "
        f"quotation marks. Output ONLY the plain motivational line, "
        f"nothing else — no name, no source, no extra text."
    )
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            _OPENROUTER_URL,
            headers={
                "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": AIConfig.AI_CHAT_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.8,
                "max_tokens": 60,
            },
            timeout=30.0,
        )
    data = resp.json()
    text = (data.get("choices") or [{}])[0].get("message", {}).get("content", "")
    return text.strip().strip('"')


@router.get("/daily-quote")
async def get_daily_quote(language: str = Query(default="English")):
    today = datetime.now(timezone.utc).date().isoformat()
    db = get_supabase_admin()

    existing = (
        db.table("daily_quotes")
        .select("quote_text")
        .eq("quote_date", today)
        .eq("language", language)
        .maybe_single()
        .execute()
    )
    if existing.data:
        return {"quote": existing.data["quote_text"], "date": today}

    try:
        quote = await _generate_quote(language)
    except Exception as e:  # noqa: BLE001
        logger.warning("daily quote generation failed: %s", e)
        quote = "Every small effort today builds the result you want tomorrow."

    try:
        db.table("daily_quotes").insert(
            {"quote_date": today, "language": language, "quote_text": quote}
        ).execute()
    except Exception:  # noqa: BLE001
        pass  # race with another request — fine, both got a quote

    return {"quote": quote, "date": today}