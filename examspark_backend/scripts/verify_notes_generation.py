"""One-off: verify generate_notes() works with the corrected AI_CHAT_MODEL.

Calls the real OpenRouter API with a short real transcript to confirm a 200
response and correctly parsed JSON notes back — proof the "qwen/qwen3 is not
a valid model ID" bug (examspark_backend/.env) is actually fixed, before
asking the founder to redo the full in-app upload flow.

Usage (from examspark_backend/, backend .env already loaded via app.config):
  python scripts/verify_notes_generation.py

Safe to delete after use.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.config import AIConfig  # noqa: E402
from app.services.qwen_service import generate_notes, QwenGenerationError  # noqa: E402

_SAMPLE_TRANSCRIPT = (
    "Today we are going to learn about Newton's three laws of motion. "
    "The first law states that an object at rest stays at rest, and an "
    "object in motion stays in motion, unless acted upon by an external "
    "force. This is also called the law of inertia. The second law states "
    "that force equals mass times acceleration, written as F = m times a. "
    "The third law states that for every action there is an equal and "
    "opposite reaction. These three laws form the foundation of classical "
    "mechanics and explain how objects move under the influence of forces."
)


async def main() -> None:
    print(f"AI_CHAT_MODEL = {AIConfig.AI_CHAT_MODEL}")
    print(f"AI_FALLBACK_MODEL = {AIConfig.AI_FALLBACK_MODEL}")
    print("Calling generate_notes() with a real transcript via OpenRouter...")

    try:
        notes = await generate_notes(_SAMPLE_TRANSCRIPT)
    except QwenGenerationError as e:
        print(f"FAIL: {e}")
        sys.exit(1)

    assert notes.get("cleanNotes"), "cleanNotes missing/empty"
    assert isinstance(notes.get("keyPoints"), list) and notes["keyPoints"], "keyPoints missing/empty"
    assert notes.get("shortSummary"), "shortSummary missing/empty"

    print("OK: generate_notes() succeeded — real OpenRouter 200 + parsed JSON")
    print(f"  shortSummary: {notes['shortSummary']}")
    print(f"  keyPoints ({len(notes['keyPoints'])}): {notes['keyPoints'][:3]}")
    print(f"  importantTerms: {len(notes.get('importantTerms', []))} found")


if __name__ == "__main__":
    asyncio.run(main())
