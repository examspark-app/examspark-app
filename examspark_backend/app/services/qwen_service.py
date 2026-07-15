"""Qwen3 32B via OpenRouter — notes/summary generation from a transcript.

Groq does not host Qwen3, so this goes through OpenRouter (AI_CHAT_MODEL,
default `qwen/qwen3` — see .env.example / TECH_STACK.md AI Pipeline table).
"""
import json

import httpx

from app.config import AIConfig

_OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

_NOTES_SYSTEM_PROMPT = (
    "You are an expert educational content processor. Process the following "
    "lecture transcript and return ONLY a JSON object with these exact keys:\n"
    '- "cleanNotes": well-formatted, organized notes in markdown\n'
    '- "keyPoints": array of short bullet-point strings for the main concepts\n'
    '- "shortSummary": a 2-3 sentence summary\n'
    '- "importantTerms": array of objects, each with "term" and "definition"\n'
    "Return raw JSON only, no markdown code fences, no commentary."
)


class QwenGenerationError(Exception):
    pass


def _extract_json_object(raw: str) -> dict:
    """Best-effort JSON extraction — some OpenRouter providers ignore
    response_format and wrap JSON in prose or code fences."""
    raw = raw.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:]
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        start = raw.find("{")
        end = raw.rfind("}")
        if start != -1 and end != -1 and end > start:
            return json.loads(raw[start : end + 1])
        raise


async def generate_notes(transcript_text: str) -> dict:
    """Returns {cleanNotes, keyPoints, shortSummary, importantTerms}."""
    if not AIConfig.openrouter_configured():
        raise QwenGenerationError("OPENROUTER_API_KEY not configured on the server.")

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
                    {"role": "system", "content": _NOTES_SYSTEM_PROMPT},
                    {"role": "user", "content": transcript_text},
                ],
                "temperature": 0.3,
                "max_tokens": 4096,
                "response_format": {"type": "json_object"},
            },
            timeout=90.0,
        )

    if response.status_code != 200:
        raise QwenGenerationError(f"Qwen3 (OpenRouter) failed: {response.status_code} {response.text[:300]}")

    data = response.json()
    content = data["choices"][0]["message"]["content"]
    parsed = _extract_json_object(content)

    return {
        "cleanNotes": parsed.get("cleanNotes", ""),
        "keyPoints": parsed.get("keyPoints", []),
        "shortSummary": parsed.get("shortSummary", ""),
        "importantTerms": parsed.get("importantTerms", []),
    }
