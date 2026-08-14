"""Daily motivational quote — generated once per day, cached, shared by
all users. AI generates an ORIGINAL line (no real-person attribution, to
avoid misquoting), not from a fixed hardcoded list.
"""
import difflib
import logging
from datetime import date, timezone, datetime

import httpx
from fastapi import APIRouter, Query

from app.config import AIConfig
from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["daily-quote"])

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Chhoti list — well-known lines jinka AI accidental reproduction hota hai.
# Agar generated quote in se bahut milta jula ho, to reject karke retry hoga.
_KNOWN_QUOTES_SAMPLE = [
    "the future belongs to those who believe in the beauty of their dreams",
    "success is not final failure is not fatal it is the courage to continue that counts",
    "believe you can and you are halfway there",
    "the only way to do great work is to love what you do",
    "in the middle of difficulty lies opportunity",
    "it does not matter how slowly you go as long as you do not stop",
    "hard work beats talent when talent does not work hard",
    "dream big and dare to fail",
    "the harder you work for something the greater you will feel when you achieve it",
]


def _is_too_similar_to_known(quote: str) -> bool:
    normalized = quote.lower().strip()
    for known in _KNOWN_QUOTES_SAMPLE:
        ratio = difflib.SequenceMatcher(None, normalized, known).ratio()
        if ratio > 0.72:
            return True
    return False


async def _call_ai_once(language: str) -> str:
    prompt = (
        f"Write ONE completely original, punchy motivational sentence in "
        f"{language}, for a student studying for competitive exams. "
        f"Make it feel bold and energetic, something that grabs attention "
        f"and gets a student to sit up and study — not a soft or generic "
        f"line. Aim for around 20-30 words, with a natural rhythm (a "
        f"contrast or turning point works well, e.g. luck vs effort, "
        f"failure vs persistence, doubt vs discipline). "
        f"CRITICAL RULES: "
        f"1) This must be entirely new wording you compose right now — "
        f"do NOT reproduce, quote, or closely paraphrase any existing "
        f"famous quote, saying, proverb, or line from any book, poem, "
        f"speech, or song, in any language. "
        f"2) NEVER mention or imply attribution to any real person "
        f"(writer, poet, freedom fighter, leader, celebrity, historical "
        f"or living figure) — no names, no '— someone', no hints of who "
        f"might have said it. "
        f"3) Avoid well-known phrasings entirely — invent fresh wording "
        f"and fresh imagery, not a variation of a common saying. "
        f"Output ONLY the plain sentence, nothing else — no quotation "
        f"marks, no name, no extra text."
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
                "temperature": 0.9,
                "max_tokens": 100,
            },
            timeout=30.0,
        )
    data = resp.json()
    text = (data.get("choices") or [{}])[0].get("message", {}).get("content", "")
    return text.strip().strip('"')


async def _generate_quote(language: str) -> str:
    last_quote = ""
    for _attempt in range(3):
        try:
            quote = await _call_ai_once(language)
        except Exception as e:  # noqa: BLE001
            logger.warning("daily quote AI call failed: %s", e)
            break
        if not quote:
            continue
        last_quote = quote
        if not _is_too_similar_to_known(quote):
            return quote
        logger.warning("daily quote too similar to known quote, retrying: %s", quote)

    # Agar 3 tries ke baad bhi safe original nahi mila, safe fallback do.
    return last_quote if last_quote and not _is_too_similar_to_known(last_quote) else (
        "Luck may open a door, but only 100% effort walks you through it — "
        "show up today like your result already depends on it."
    )


@router.get("/daily-quote")
async def get_daily_quote(language: str = Query(default="English")):
    today = datetime.now(timezone.utc).date().isoformat()

    try:
        db = get_supabase_admin()
        existing = (
            db.table("daily_quotes")
            .select("quote_text")
            .eq("quote_date", today)
            .eq("language", language)
            .execute()
        )
        if existing.data:
            return {"quote": existing.data[0]["quote_text"], "date": today}
    except Exception as e:  # noqa: BLE001
        logger.warning("daily quote lookup failed: %s", e)

    try:
        quote = await _generate_quote(language)
    except Exception as e:  # noqa: BLE001
        logger.warning("daily quote generation failed: %s", e)
        quote = (
            "Luck may open a door, but only 100% effort walks you through it — "
            "show up today like your result already depends on it."
        )

    try:
        db.table("daily_quotes").insert(
            {"quote_date": today, "language": language, "quote_text": quote}
        ).execute()
    except Exception:  # noqa: BLE001
        pass  # race with another request — fine, both got a quote

    return {"quote": quote, "date": today}